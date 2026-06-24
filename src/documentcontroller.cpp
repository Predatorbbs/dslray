#include "documentcontroller.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>


DocumentController::DocumentController(QObject *parent)
    : QAbstractListModel(parent)
{
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

    const int row = m_docs.size();
    beginInsertRows({}, row, row);
    m_docs.append(doc);
    endInsertRows();
    emit countChanged();

    // Новая вкладка всегда в фокусе.
    m_active = row;
    emit activeIndexChanged();
    emit activeChanged();
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
}

void DocumentController::applyEdit(const QString &text)
{
    if (m_active < 0 || m_active >= m_docs.size())
        return;
    if (m_docs.at(m_active).content == text)
        return;
    m_docs[m_active].content = text;
    writeToDisk(m_active);
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
    writeToDisk(i);
    if (i == m_active)
        emit activeChanged();
}

bool DocumentController::writeToDisk(int index)
{
    if (index < 0 || index >= m_docs.size())
        return false;
    QFile f(m_docs.at(index).path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        emit errorOccurred(tr("Не удалось записать файл '%1': %2")
                               .arg(m_docs.at(index).name, f.errorString()));
        return false;
    }
    QTextStream out(&f);
    out.setEncoding(QStringConverter::Utf8);
    out << m_docs.at(index).content;
    f.close();
    return true;
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
