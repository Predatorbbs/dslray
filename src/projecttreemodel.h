#pragma once

#include <QAbstractItemModel>
#include <QList>
#include <QString>

// Узел дерева проекта.
struct TreeNode {
    QString    name;
    QString    path;            // абсолютный, разделители "/"
    bool       isDir = false;
    bool       populated = false; // дети уже считаны с диска
    TreeNode  *parent = nullptr;
    QList<TreeNode *> children;

    ~TreeNode() { qDeleteAll(children); }
};

// Собственная модель файлового дерева проекта. В отличие от QFileSystemModel,
// полностью контролирует свою структуру: перемещение/переименование обновляют
// модель явными beginInsertRows/beginRemoveRows — без фантомных строк. Папки
// идут перед файлами, скрытые/точко-файлы не показываются. Дети директорий
// читаются лениво — при первом обращении вида к ним.
class ProjectTreeModel : public QAbstractItemModel
{
    Q_OBJECT
public:
    enum Roles {
        IsDirRole = Qt::UserRole + 100,
        FilePathRole = Qt::UserRole + 101,
    };

    explicit ProjectTreeModel(QObject *parent = nullptr);
    ~ProjectTreeModel() override;

    // Корневая папка проекта (её содержимое — верхний уровень дерева).
    void setRootDir(const QString &path);
    QString rootDir() const { return m_root ? m_root->path : QString(); }

    // ── QAbstractItemModel ───────────────────────────────────────────
    QModelIndex index(int row, int column, const QModelIndex &parent = {}) const override;
    QModelIndex parent(const QModelIndex &child) const override;
    int rowCount(const QModelIndex &parent = {}) const override;
    int columnCount(const QModelIndex &parent = {}) const override { return 1; }
    QVariant data(const QModelIndex &index, int role) const override;
    bool hasChildren(const QModelIndex &parent = {}) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Индекс узла по пути (попутно заполняет ветки-предки). Невалидный, если
    // путь вне проекта или не найден.
    Q_INVOKABLE QModelIndex indexForPath(const QString &path) const;

    // ── Операции (меняют ФС и саму модель) ───────────────────────────
    bool createFolder(const QString &parentPath, const QString &name);
    bool createFile(const QString &parentPath, const QString &name);
    QString renameItem(const QString &path, const QString &newName);
    QString moveItem(const QString &sourcePath, const QString &targetDir);

signals:
    void errorOccurred(const QString &message);

private:
    TreeNode *nodeForIndex(const QModelIndex &idx) const;  // невалидный → m_root
    QModelIndex indexForNode(TreeNode *node) const;
    static int rowOf(TreeNode *node);                       // позиция в родителе

    void populate(TreeNode *node) const;                    // лениво заполнить детей
    static bool dirHasVisibleEntries(const QString &path);
    static bool isHiddenName(const QString &name);
    TreeNode *findNode(const QString &path) const;          // среди заполненных
    static int sortedInsertPos(TreeNode *parent, const QString &name, bool isDir);
    static void rebasePaths(TreeNode *node, const QString &newPath); // обновить путь поддерева

    TreeNode *m_root = nullptr;
};
