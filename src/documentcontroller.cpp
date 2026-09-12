#include "documentcontroller.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStringList>
#include <QTextStream>


DocumentController::DocumentController(QObject *parent)
    : QAbstractListModel(parent)
    , m_safeMode(QSettings().value(QStringLiteral("editor/safeMode"), false).toBool())
{
}

void DocumentController::closePath(const QString &path)
{
    const QString norm = normalize(path);
    const QString prefix = norm + QLatin1Char('/');
    // Закрываем сам файл и (если удалили папку) все вкладки внутри неё.
    for (int i = m_docs.size() - 1; i >= 0; --i) {
        const QString p = m_docs.at(i).path;
        if (p == norm || p.startsWith(prefix))
            closeAt(i);
    }
}

int DocumentController::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_docs.size();
}

QVariant DocumentController::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_docs.size())
        return {};
    const OpenDocument &doc = m_docs.at(index.row());
    switch (role) {
    case PathRole:     return doc.path;
    case NameRole:     return doc.name;
    case ModifiedRole: return doc.modified;
    default:           return {};
    }
}

QHash<int, QByteArray> DocumentController::roleNames() const
{
    return {
        { PathRole,     "path" },
        { NameRole,     "name" },
        { ModifiedRole, "modified" },
    };
}

QString DocumentController::activePath() const
{
    if (m_active < 0 || m_active >= m_docs.size())
        return {};
    return m_docs.at(m_active).path;
}

QString DocumentController::activeName() const
{
    if (m_active < 0 || m_active >= m_docs.size())
        return {};
    return m_docs.at(m_active).name;
}

QString DocumentController::activeContent() const
{
    if (m_active < 0 || m_active >= m_docs.size())
        return {};
    return m_docs.at(m_active).content;
}

void DocumentController::setActiveIndex(int index)
{
    if (index == m_active)
        return;
    if (index < -1 || index >= m_docs.size())
        return;
    emit flushRequested();
    m_active = index;
    emit activeIndexChanged();
    emit activeChanged();
    persist();
}

void DocumentController::activate(int index)
{
    setActiveIndex(index);
}

void DocumentController::openFile(const QString &path)
{
    const QString norm = normalize(path);
    if (norm.isEmpty())
        return;

    QFileInfo info(norm);
    if (!info.exists() || info.isDir())
        return;

    // Уже открыт — просто активируем.
    const int existing = indexOfPath(norm);
    if (existing >= 0) {
        setActiveIndex(existing);
        return;
    }

    OpenDocument doc;
    doc.path = norm;
    doc.name = info.fileName();
    if (!readFile(norm, doc.content))
        return;

    // В «Безопасном режиме» при наличии черновика показываем его, а вкладку
    // помечаем изменённой.
    if (m_safeMode) {
        const QString draft = draftPathFor(norm);
        if (QFile::exists(draft)) {
            if (!readFile(draft, doc.content))
                return;
            doc.modified = true;
        }
    }

    const int row = m_docs.size();
    beginInsertRows({}, row, row);
    m_docs.append(doc);
    endInsertRows();
    emit countChanged();

    // Новая вкладка всегда в фокусе.
    m_active = row;
    emit activeIndexChanged();
    emit activeChanged();
    persist();
}

void DocumentController::closeAt(int index)
{
    if (index < 0 || index >= m_docs.size())
        return;

    emit flushRequested();
    beginRemoveRows({}, index, index);
    m_docs.removeAt(index);
    endRemoveRows();
    emit countChanged();

    // Пересчитываем активную вкладку.
    int newActive = m_active;
    if (m_docs.isEmpty()) {
        newActive = -1;
    } else if (index < m_active) {
        newActive = m_active - 1;
    } else if (index == m_active) {
        newActive = qMin(index, m_docs.size() - 1);
    }
    m_active = -2; // форсируем уведомление ниже
    setActiveIndex(newActive);
}

void DocumentController::handlePathRenamed(const QString &oldPath, const QString &newPath)
{
    const QString from = normalize(oldPath);
    const QString to = normalize(newPath);
    if (from.isEmpty() || to.isEmpty() || from == to)
        return;
    const QString prefix = from + QLatin1Char('/');
    bool changed = false;
    for (int i = 0; i < m_docs.size(); ++i) {
        OpenDocument &doc = m_docs[i];
        if (doc.path != from && !doc.path.startsWith(prefix))
            continue;
        const QString previousPath = doc.path;
        doc.path = to + doc.path.mid(from.size());
        doc.name = baseName(doc.path);
        if (doc.modified && writeTextToFile(draftPathFor(doc.path), doc.content))
            deleteDraft(previousPath);
        const QModelIndex mi = index(i, 0);
        emit dataChanged(mi, mi, { PathRole, NameRole });
        changed = true;
    }
    if (changed) {
        emit activeChanged();
        persist();
    }
}

void DocumentController::applyEdit(const QString &text)
{
    editAt(m_active, text);
}

void DocumentController::flushEdit(const QString &path, const QString &text)
{
    editAt(indexOfPath(normalize(path)), text);
}

void DocumentController::editAt(int index, const QString &text)
{
    if (index < 0 || index >= m_docs.size() || m_docs.at(index).content == text)
        return;
    m_docs[index].content = text;
    commitContent(index);
    if (index == m_active)
        emit activeChanged();
}

// Запись содержимого по текущему режиму: в «Безопасном» — в черновик (и пометка
// «изменён»), в «Прозрачном» — сразу в оригинал.
void DocumentController::commitContent(int index)
{
    const OpenDocument &doc = m_docs.at(index);
    const bool written = writeTextToFile(m_safeMode ? draftPathFor(doc.path) : doc.path,
                                        doc.content);
    // Failed writes must remain visible as unsaved changes and can be retried.
    setModified(index, m_safeMode || !written);
}

void DocumentController::setModified(int index, bool value)
{
    if (index < 0 || index >= m_docs.size())
        return;
    if (m_docs.at(index).modified == value)
        return;
    m_docs[index].modified = value;
    const QModelIndex mi = this->index(index, 0);
    emit dataChanged(mi, mi, { ModifiedRole });
}

bool DocumentController::writeTextToFile(const QString &path, const QString &text)
{
    QSaveFile file(path);
    const auto reportError = [&]() {
        emit errorOccurred(tr("Не удалось записать файл '%1': %2")
                               .arg(QFileInfo(path).fileName(), file.errorString()));
        return false;
    };
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return reportError();
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << text;
    out.flush();
    if (out.status() != QTextStream::Ok) {
        file.cancelWriting();
        return reportError();
    }
    if (!file.commit())
        return reportError();
    return true;
}

QString DocumentController::draftPathFor(const QString &path) const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)
                        + QStringLiteral("/drafts");
    QDir().mkpath(dir);
    const QByteArray hash =
        QCryptographicHash::hash(normalize(path).toUtf8(), QCryptographicHash::Sha1).toHex();
    return dir + QLatin1Char('/') + QString::fromLatin1(hash) + QStringLiteral(".draft");
}

void DocumentController::deleteDraft(const QString &path) const
{
    QFile::remove(draftPathFor(path));
}

void DocumentController::setSafeMode(bool on)
{
    if (m_safeMode == on)
        return;
    emit flushRequested();
    if (!on && hasUnsavedChanges())
        return;
    m_safeMode = on;
    QSettings().setValue(QStringLiteral("editor/safeMode"), on);
    emit safeModeChanged();
}

bool DocumentController::saveActive()
{
    emit flushRequested();
    return m_active >= 0 && m_active < m_docs.size() && saveDocument(m_active);
}

bool DocumentController::saveDocument(int index)
{
    const OpenDocument &doc = m_docs.at(index);
    if (!writeTextToFile(doc.path, doc.content)) {
        setModified(index, true);
        return false;
    }
    deleteDraft(doc.path);
    setModified(index, false);
    return true;
}

bool DocumentController::hasUnsavedChanges() const
{
    for (const OpenDocument &d : m_docs)
        if (d.modified)
            return true;
    return false;
}

bool DocumentController::applyAllDrafts()
{
    emit flushRequested();
    bool saved = true;
    for (int i = 0; i < m_docs.size(); ++i) {
        if (m_docs.at(i).modified && !saveDocument(i))
            saved = false;
    }
    return saved;
}

bool DocumentController::discardAllDrafts()
{
    emit flushRequested();
    bool discarded = true;
    for (int i = 0; i < m_docs.size(); ++i) {
        if (!m_docs.at(i).modified)
            continue;
        QString original;
        if (!readFile(m_docs.at(i).path, original)) {
            discarded = false;
            continue;
        }
        deleteDraft(m_docs.at(i).path);
        m_docs[i].content = original;
        setModified(i, false);
        if (i == m_active) {
            emit activeChanged();
            emit activeContentReset();
        }
    }
    return discarded;
}

void DocumentController::persist() const
{
    QStringList paths;
    paths.reserve(m_docs.size());
    for (const OpenDocument &d : m_docs)
        paths << d.path;
    QSettings s;
    s.setValue(QStringLiteral("session/openFiles"), paths);
    s.setValue(QStringLiteral("session/activePath"), activePath());
}

int DocumentController::indexOfPath(const QString &path) const
{
    for (int i = 0; i < m_docs.size(); ++i) {
        if (m_docs.at(i).path == path)
            return i;
    }
    return -1;
}

QString DocumentController::normalize(const QString &path)
{
    if (path.isEmpty())
        return {};
    return QDir::cleanPath(path);
}

QString DocumentController::baseName(const QString &path)
{
    return QFileInfo(path).fileName();
}

bool DocumentController::readFile(const QString &path, QString &text)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit errorOccurred(tr("Не удалось прочитать файл '%1': %2")
                               .arg(QFileInfo(path).fileName(), file.errorString()));
        return false;
    }
    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);
    text = in.readAll();
    if (file.error() != QFileDevice::NoError || in.status() != QTextStream::Ok) {
        emit errorOccurred(tr("Не удалось прочитать файл '%1': %2")
                               .arg(QFileInfo(path).fileName(), file.errorString()));
        return false;
    }
    return true;
}
