#include "projecttreemodel.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>


ProjectTreeModel::ProjectTreeModel(QObject *parent)
    : QAbstractItemModel(parent)
{
}

ProjectTreeModel::~ProjectTreeModel()
{
    delete m_root;
}

void ProjectTreeModel::setRootDir(const QString &path)
{
    beginResetModel();
    delete m_root;
    m_root = nullptr;
    const QString clean = QDir::cleanPath(path);
    if (!clean.isEmpty() && QDir(clean).exists()) {
        m_root = new TreeNode;
        m_root->name = QFileInfo(clean).fileName();
        m_root->path = clean;
        m_root->isDir = true;
        m_root->populated = false;
    }
    endResetModel();
}

// ── Навигация по дереву ──────────────────────────────────────────────────

TreeNode *ProjectTreeModel::nodeForIndex(const QModelIndex &idx) const
{
    if (!idx.isValid())
        return m_root;
    return static_cast<TreeNode *>(idx.internalPointer());
}

int ProjectTreeModel::rowOf(TreeNode *node)
{
    if (!node || !node->parent)
        return 0;
    return node->parent->children.indexOf(node);
}

QModelIndex ProjectTreeModel::indexForNode(TreeNode *node) const
{
    if (!node || node == m_root)
        return {};
    return createIndex(rowOf(node), 0, node);
}

QModelIndex ProjectTreeModel::index(int row, int column, const QModelIndex &parent) const
{
    if (column != 0 || row < 0)
        return {};
    TreeNode *p = nodeForIndex(parent);
    if (!p)
        return {};
    if (!p->populated)
        populate(p);
    if (row >= p->children.size())
        return {};
    return createIndex(row, 0, p->children.at(row));
}

QModelIndex ProjectTreeModel::parent(const QModelIndex &child) const
{
    if (!child.isValid())
        return {};
    TreeNode *node = static_cast<TreeNode *>(child.internalPointer());
    if (!node || node->parent == nullptr || node->parent == m_root)
        return {};
    return createIndex(rowOf(node->parent), 0, node->parent);
}

int ProjectTreeModel::rowCount(const QModelIndex &parent) const
{
    TreeNode *p = nodeForIndex(parent);
    if (!p || !p->isDir)
        return 0;
    if (!p->populated)
        populate(p);
    return p->children.size();
}

bool ProjectTreeModel::hasChildren(const QModelIndex &parent) const
{
    TreeNode *p = nodeForIndex(parent);
    if (!p || !p->isDir)
        return false;
    if (p->populated)
        return !p->children.isEmpty();
    return dirHasVisibleEntries(p->path);
}

QVariant ProjectTreeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return {};
    TreeNode *node = static_cast<TreeNode *>(index.internalPointer());
    if (!node)
        return {};
    switch (role) {
    case Qt::DisplayRole: return node->name;
    case IsDirRole:       return node->isDir;
    case FilePathRole:    return node->path;
    default:              return {};
    }
}

QHash<int, QByteArray> ProjectTreeModel::roleNames() const
{
    return {
        { Qt::DisplayRole, "display" },
        { IsDirRole,       "isDir" },
        { FilePathRole,    "filePath" },
    };
}

// ── Заполнение / сканирование ────────────────────────────────────────────

bool ProjectTreeModel::isHiddenName(const QString &name)
{
    return name.startsWith(QLatin1Char('.'));
}

bool ProjectTreeModel::dirHasVisibleEntries(const QString &path)
{
    QDir dir(path);
    const QFileInfoList list =
        dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot, QDir::NoSort);
    for (const QFileInfo &fi : list) {
        if (!isHiddenName(fi.fileName()))
            return true;
    }
    return false;
}

void ProjectTreeModel::populate(TreeNode *node) const
{
    if (!node || node->populated)
        return;
    node->populated = true;
    if (!node->isDir)
        return;

    QDir dir(node->path);
    // Папки сверху, затем по имени без учёта регистра.
    const QFileInfoList list = dir.entryInfoList(
        QDir::AllEntries | QDir::NoDotAndDotDot,
        QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);

    for (const QFileInfo &fi : list) {
        if (isHiddenName(fi.fileName()))
            continue;
        auto *child = new TreeNode;
        child->name = fi.fileName();
        child->path = QDir::cleanPath(fi.absoluteFilePath());
        child->isDir = fi.isDir();
        child->populated = false;
        child->parent = node;
        node->children.append(child);
    }
}

TreeNode *ProjectTreeModel::findNode(const QString &path) const
{
    const QString target = QDir::cleanPath(path);
    if (!m_root || target.isEmpty())
        return nullptr;
    if (m_root->path == target)
        return m_root;

    // Обходим только заполненные ветки (незаполненные узлы и не видны).
    QList<TreeNode *> stack;
    stack.append(m_root);
    while (!stack.isEmpty()) {
        TreeNode *n = stack.takeLast();
        if (!n->populated)
            continue;
        for (TreeNode *c : n->children) {
            if (c->path == target)
                return c;
            if (c->isDir)
                stack.append(c);
        }
    }
    return nullptr;
}

int ProjectTreeModel::sortedInsertPos(TreeNode *parent, const QString &name, bool isDir)
{
    int i = 0;
    for (; i < parent->children.size(); ++i) {
        TreeNode *c = parent->children.at(i);
        if (isDir != c->isDir) {
            if (isDir) break;   // новая папка идёт перед файлами
            else       continue; // новый файл — после всех папок
        }
        if (name.compare(c->name, Qt::CaseInsensitive) < 0)
            break;
    }
    return i;
}

void ProjectTreeModel::rebasePaths(TreeNode *node, const QString &newPath)
{
    node->path = newPath;
    if (!node->populated)
        return;
    for (TreeNode *c : node->children)
        rebasePaths(c, newPath + QLatin1Char('/') + c->name);
}

QModelIndex ProjectTreeModel::indexForPath(const QString &path) const
{
    if (!m_root)
        return {};
    const QString target = QDir::cleanPath(path);
    if (target.isEmpty() || target == m_root->path)
        return {};
    if (!target.startsWith(m_root->path + QLatin1Char('/')))
        return {}; // вне проекта

    TreeNode *cur = m_root;
    QModelIndex curIdx; // невалидный == корень
    while (true) {
        if (!cur->populated)
            populate(cur);
        TreeNode *next = nullptr;
        int nextRow = -1;
        for (int i = 0; i < cur->children.size(); ++i) {
            TreeNode *c = cur->children.at(i);
            if (c->path == target)
                return index(i, 0, curIdx);
            if (c->isDir && target.startsWith(c->path + QLatin1Char('/'))) {
                next = c;
                nextRow = i;
                break;
            }
        }
        if (!next)
            return {};
        curIdx = index(nextRow, 0, curIdx);
        cur = next;
    }
}

// ── Операции ─────────────────────────────────────────────────────────────

bool ProjectTreeModel::createFolder(const QString &parentPath, const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty())
        return false;
    QDir parent(parentPath);
    if (!parent.exists()) {
        emit errorOccurred(tr("Родительская папка не существует"));
        return false;
    }
    if (parent.exists(trimmed)) {
        emit errorOccurred(tr("Элемент '%1' уже существует").arg(trimmed));
        return false;
    }
    if (!parent.mkdir(trimmed)) {
        emit errorOccurred(tr("Не удалось создать папку '%1'").arg(trimmed));
        return false;
    }

    TreeNode *pNode = findNode(parentPath);
    if (pNode && pNode->populated) {
        auto *child = new TreeNode;
        child->name = trimmed;
        child->path = QDir::cleanPath(parent.filePath(trimmed));
        child->isDir = true;
        child->populated = true; // только что создана — пустая
        child->parent = pNode;
        const int pos = sortedInsertPos(pNode, trimmed, true);
        beginInsertRows(indexForNode(pNode), pos, pos);
        pNode->children.insert(pos, child);
        endInsertRows();
    }
    return true;
}

bool ProjectTreeModel::createFile(const QString &parentPath, const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty())
        return false;
    QDir parent(parentPath);
    if (!parent.exists()) {
        emit errorOccurred(tr("Родительская папка не существует"));
        return false;
    }
    const QString full = parent.filePath(trimmed);
    if (QFile::exists(full)) {
        emit errorOccurred(tr("Файл '%1' уже существует").arg(trimmed));
        return false;
    }
    QFile f(full);
    if (!f.open(QIODevice::WriteOnly)) {
        emit errorOccurred(tr("Не удалось создать файл '%1': %2").arg(trimmed, f.errorString()));
        return false;
    }
    f.close();

    TreeNode *pNode = findNode(parentPath);
    if (pNode && pNode->populated) {
        auto *child = new TreeNode;
        child->name = trimmed;
        child->path = QDir::cleanPath(full);
        child->isDir = false;
        child->populated = true;
        child->parent = pNode;
        const int pos = sortedInsertPos(pNode, trimmed, false);
        beginInsertRows(indexForNode(pNode), pos, pos);
        pNode->children.insert(pos, child);
        endInsertRows();
    }
    return true;
}

QString ProjectTreeModel::renameItem(const QString &path, const QString &newName)
{
    QFileInfo info(path);
    if (!info.exists())
        return {};
    const QString trimmed = newName.trimmed();
    if (trimmed.isEmpty() || trimmed == info.fileName())
        return {};
    if (trimmed.contains(QLatin1Char('/')) || trimmed.contains(QLatin1Char('\\'))) {
        emit errorOccurred(tr("Имя не должно содержать разделителей пути"));
        return {};
    }
    const QString newPath = QDir::cleanPath(QDir(info.absolutePath()).filePath(trimmed));
    if (QFile::exists(newPath)) {
        emit errorOccurred(tr("Элемент '%1' уже существует").arg(trimmed));
        return {};
    }

    bool ok = info.isDir() ? QDir().rename(info.absoluteFilePath(), newPath)
                           : QFile(info.absoluteFilePath()).rename(newPath);
    if (!ok) {
        emit errorOccurred(tr("Не удалось переименовать '%1'").arg(info.fileName()));
        return {};
    }

    TreeNode *node = findNode(QDir::cleanPath(path));
    if (node && node->parent) {
        TreeNode *p = node->parent;
        const int oldPos = rowOf(node);
        // Снять с позиции, обновить, вернуть на верную (пересортированную).
        beginRemoveRows(indexForNode(p), oldPos, oldPos);
        p->children.removeAt(oldPos);
        endRemoveRows();

        node->name = trimmed;
        rebasePaths(node, newPath);

        const int newPos = sortedInsertPos(p, trimmed, node->isDir);
        beginInsertRows(indexForNode(p), newPos, newPos);
        p->children.insert(newPos, node);
        endInsertRows();
    }
    return newPath;
}

bool ProjectTreeModel::removeItem(const QString &path)
{
    QFileInfo info(QDir::cleanPath(path));
    if (!info.exists())
        return false;

    const bool ok = info.isDir()
        ? QDir(info.absoluteFilePath()).removeRecursively()
        : QFile::remove(info.absoluteFilePath());
    if (!ok) {
        emit errorOccurred(tr("Не удалось удалить '%1'").arg(info.fileName()));
        return false;
    }

    TreeNode *node = findNode(QDir::cleanPath(path));
    if (node && node->parent) {
        TreeNode *p = node->parent;
        const int pos = rowOf(node);
        beginRemoveRows(indexForNode(p), pos, pos);
        p->children.removeAt(pos);
        endRemoveRows();
        delete node;
    }
    return true;
}

QString ProjectTreeModel::moveItem(const QString &sourcePath, const QString &targetDir)
{
    if (sourcePath.isEmpty() || targetDir.isEmpty())
        return {};

    QFileInfo srcInfo(sourcePath);
    if (!srcInfo.exists())
        return {};
    QDir dst(targetDir);
    if (!dst.exists())
        return {};

    const QString srcClean = QDir::cleanPath(srcInfo.absoluteFilePath());
    const QString dstClean = QDir::cleanPath(QFileInfo(targetDir).absoluteFilePath());

    // Папку нельзя кинуть в саму себя/потомка.
    if (srcInfo.isDir()) {
        if (dstClean == srcClean || dstClean.startsWith(srcClean + QLatin1Char('/')))
            return {};
    }
    // Родитель не меняется — нечего двигать.
    if (QDir::cleanPath(srcInfo.absolutePath()) == dstClean)
        return {};

    const QString newPath = QDir::cleanPath(dst.filePath(srcInfo.fileName()));
    if (QFile::exists(newPath)) {
        emit errorOccurred(tr("В '%1' уже есть '%2'").arg(targetDir, srcInfo.fileName()));
        return {};
    }

    bool ok = srcInfo.isDir() ? QDir().rename(srcInfo.absoluteFilePath(), newPath)
                              : QFile(srcInfo.absoluteFilePath()).rename(newPath);
    if (!ok) {
        emit errorOccurred(tr("Не удалось переместить '%1'").arg(srcInfo.fileName()));
        return {};
    }

    // Обновляем модель: убираем узел из старого родителя…
    TreeNode *node = findNode(srcClean);
    if (node && node->parent) {
        TreeNode *oldParent = node->parent;
        const int oldPos = rowOf(node);
        beginRemoveRows(indexForNode(oldParent), oldPos, oldPos);
        oldParent->children.removeAt(oldPos);
        endRemoveRows();

        // …и вставляем в целевую папку, если она уже раскрыта; иначе узел
        // будет прочитан с диска при её раскрытии.
        TreeNode *targetNode = findNode(dstClean);
        if (targetNode && targetNode->populated) {
            node->parent = targetNode;
            rebasePaths(node, newPath);
            const int pos = sortedInsertPos(targetNode, node->name, node->isDir);
            beginInsertRows(indexForNode(targetNode), pos, pos);
            targetNode->children.insert(pos, node);
            endInsertRows();
        } else {
            delete node;
        }
    }
    return newPath;
}
