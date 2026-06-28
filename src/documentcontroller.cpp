#include "documentcontroller.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#include <QTextStream>


DocumentController::DocumentController(QObject *parent)
    : QAbstractListModel(parent)
{
    QSettings s;
    m_safeMode = s.value(QStringLiteral("editor/safeMode"), false).toBool();
    m_wordWrap = s.value(QStringLiteral("editor/wordWrap"), false).toBool();
    m_codeFontSize = qBound(14, s.value(QStringLiteral("editor/codeFontSize"), 14).toInt(), 32);
    m_indentWidth = qBound(1, s.value(QStringLiteral("editor/indentWidth"), 2).toInt(), 8);
    m_indentUseTabs = s.value(QStringLiteral("editor/indentUseTabs"), false).toBool();

    m_themeId = s.value(QStringLiteral("appearance/theme"), QStringLiteral("light")).toString();
    if (m_themeId != QLatin1String("dark") && m_themeId != QLatin1String("light"))
        m_themeId = QStringLiteral("light");
    m_userName = s.value(QStringLiteral("user/name"), QStringLiteral("designer")).toString();
    m_userEmail = s.value(QStringLiteral("user/email")).toString();
    m_avatarPath = s.value(QStringLiteral("user/avatar")).toString();

    const auto readColor = [&s](const QString &key, const QColor &def) {
        const QColor c(s.value(key, def.name()).toString());
        return c.isValid() ? c : def;
    };
    m_colorKey     = readColor(QStringLiteral("editor/colorKey"),     m_colorKey);
    m_colorString  = readColor(QStringLiteral("editor/colorString"),  m_colorString);
    m_colorNumber  = readColor(QStringLiteral("editor/colorNumber"),  m_colorNumber);
    m_colorKeyword = readColor(QStringLiteral("editor/colorKeyword"), m_colorKeyword);
    m_colorPunct   = readColor(QStringLiteral("editor/colorPunct"),   m_colorPunct);
}

void DocumentController::setThemeId(const QString &id)
{
    const QString v = (id == QLatin1String("dark")) ? QStringLiteral("dark") : QStringLiteral("light");
    if (m_themeId == v)
        return;
    m_themeId = v;
    QSettings().setValue(QStringLiteral("appearance/theme"), v);
    emit themeIdChanged();
}

void DocumentController::setUserName(const QString &name)
{
    if (m_userName == name)
        return;
    m_userName = name;
    QSettings().setValue(QStringLiteral("user/name"), name);
    emit userChanged();
}

void DocumentController::setUserEmail(const QString &email)
{
    if (m_userEmail == email)
        return;
    m_userEmail = email;
    QSettings().setValue(QStringLiteral("user/email"), email);
    emit userChanged();
}

void DocumentController::setAvatarPath(const QString &path)
{
    if (m_avatarPath == path)
        return;
    m_avatarPath = path;
    QSettings().setValue(QStringLiteral("user/avatar"), path);
    emit userChanged();
}

void DocumentController::setColorKey(const QColor &c)
{
    if (!c.isValid() || m_colorKey == c) return;
    m_colorKey = c;
    QSettings().setValue(QStringLiteral("editor/colorKey"), c.name());
    emit colorsChanged();
}

void DocumentController::setColorString(const QColor &c)
{
    if (!c.isValid() || m_colorString == c) return;
    m_colorString = c;
    QSettings().setValue(QStringLiteral("editor/colorString"), c.name());
    emit colorsChanged();
}

void DocumentController::setColorNumber(const QColor &c)
{
    if (!c.isValid() || m_colorNumber == c) return;
    m_colorNumber = c;
    QSettings().setValue(QStringLiteral("editor/colorNumber"), c.name());
    emit colorsChanged();
}

void DocumentController::setColorKeyword(const QColor &c)
{
    if (!c.isValid() || m_colorKeyword == c) return;
    m_colorKeyword = c;
    QSettings().setValue(QStringLiteral("editor/colorKeyword"), c.name());
    emit colorsChanged();
}

void DocumentController::setColorPunct(const QColor &c)
{
    if (!c.isValid() || m_colorPunct == c) return;
    m_colorPunct = c;
    QSettings().setValue(QStringLiteral("editor/colorPunct"), c.name());
    emit colorsChanged();
}

void DocumentController::resetColors()
{
    m_colorKey     = QColor(QStringLiteral("#2563eb"));
    m_colorString  = QColor(QStringLiteral("#2a9d5c"));
    m_colorNumber  = QColor(QStringLiteral("#b5651d"));
    m_colorKeyword = QColor(QStringLiteral("#8b5cf6"));
    m_colorPunct   = QColor(QStringLiteral("#7a818f"));
    QSettings s;
    s.setValue(QStringLiteral("editor/colorKey"),     m_colorKey.name());
    s.setValue(QStringLiteral("editor/colorString"),  m_colorString.name());
    s.setValue(QStringLiteral("editor/colorNumber"),  m_colorNumber.name());
    s.setValue(QStringLiteral("editor/colorKeyword"), m_colorKeyword.name());
    s.setValue(QStringLiteral("editor/colorPunct"),   m_colorPunct.name());
    emit colorsChanged();
}

void DocumentController::setIndentWidth(int width)
{
    const int clamped = qBound(1, width, 8);
    if (m_indentWidth == clamped)
        return;
    m_indentWidth = clamped;
    QSettings().setValue(QStringLiteral("editor/indentWidth"), clamped);
    emit indentWidthChanged();
}

void DocumentController::setIndentUseTabs(bool on)
{
    if (m_indentUseTabs == on)
        return;
    m_indentUseTabs = on;
    QSettings().setValue(QStringLiteral("editor/indentUseTabs"), on);
    emit indentUseTabsChanged();
}

void DocumentController::setWordWrap(bool on)
{
    if (m_wordWrap == on)
        return;
    m_wordWrap = on;
    QSettings().setValue(QStringLiteral("editor/wordWrap"), on);
    emit wordWrapChanged();
}

void DocumentController::setCodeFontSize(int size)
{
    const int clamped = qBound(14, size, 32);
    if (m_codeFontSize == clamped)
        return;
    m_codeFontSize = clamped;
    QSettings().setValue(QStringLiteral("editor/codeFontSize"), clamped);
    emit codeFontSizeChanged();
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
    doc.content = readFile(norm);

    // В «Безопасном режиме» при наличии черновика показываем его, а вкладку
    // помечаем изменённой.
    if (m_safeMode) {
        const QString draft = draftPathFor(norm);
        if (QFile::exists(draft)) {
            doc.content = readFile(draft);
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
    const int idx = indexOfPath(from);
    if (idx < 0)
        return;

    m_docs[idx].path = to;
    m_docs[idx].name = baseName(to);

    const QModelIndex mi = index(idx, 0);
    emit dataChanged(mi, mi, { PathRole, NameRole });
    if (idx == m_active)
        emit activeChanged();
    persist();
}

void DocumentController::applyEdit(const QString &text)
{
    if (m_active < 0 || m_active >= m_docs.size())
        return;
    if (m_docs.at(m_active).content == text)
        return;
    m_docs[m_active].content = text;
    commitContent(m_active);
    emit activeChanged(); // «Структура» перечитается
}

void DocumentController::flushEdit(const QString &path, const QString &text)
{
    const int i = indexOfPath(normalize(path));
    if (i < 0)
        return;
    if (m_docs.at(i).content == text)
        return;
    m_docs[i].content = text;
    commitContent(i);
    if (i == m_active)
        emit activeChanged();
}

// Запись содержимого по текущему режиму: в «Безопасном» — в черновик (и пометка
// «изменён»), в «Прозрачном» — сразу в оригинал.
void DocumentController::commitContent(int index)
{
    if (index < 0 || index >= m_docs.size())
        return;
    if (m_safeMode) {
        writeTextToFile(draftPathFor(m_docs.at(index).path), m_docs.at(index).content);
        setModified(index, true);
    } else {
        writeTextToFile(m_docs.at(index).path, m_docs.at(index).content);
        setModified(index, false);
    }
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
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        emit errorOccurred(tr("Не удалось записать файл '%1': %2")
                               .arg(QFileInfo(path).fileName(), f.errorString()));
        return false;
    }
    QTextStream out(&f);
    out.setEncoding(QStringConverter::Utf8);
    out << text;
    f.close();
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
    m_safeMode = on;
    QSettings().setValue(QStringLiteral("editor/safeMode"), on);
    emit safeModeChanged();
}

void DocumentController::saveActive()
{
    if (m_active < 0 || m_active >= m_docs.size())
        return;
    writeTextToFile(m_docs.at(m_active).path, m_docs.at(m_active).content);
    deleteDraft(m_docs.at(m_active).path);
    setModified(m_active, false);
}

bool DocumentController::hasUnsavedChanges() const
{
    for (const OpenDocument &d : m_docs)
        if (d.modified)
            return true;
    return false;
}

void DocumentController::applyAllDrafts()
{
    for (int i = 0; i < m_docs.size(); ++i) {
        if (!m_docs.at(i).modified)
            continue;
        writeTextToFile(m_docs.at(i).path, m_docs.at(i).content);
        deleteDraft(m_docs.at(i).path);
        setModified(i, false);
    }
}

void DocumentController::discardAllDrafts()
{
    for (int i = 0; i < m_docs.size(); ++i) {
        if (!m_docs.at(i).modified)
            continue;
        deleteDraft(m_docs.at(i).path);
        m_docs[i].content = readFile(m_docs.at(i).path);
        setModified(i, false);
        if (i == m_active) {
            emit activeChanged();
            emit activeContentReset();
        }
    }
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

QString DocumentController::readFile(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QTextStream in(&f);
    in.setEncoding(QStringConverter::Utf8);
    return in.readAll();
}
