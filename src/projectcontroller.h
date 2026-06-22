#pragma once

#include <QAbstractItemModel>
#include <QFileSystemModel>
#include <QModelIndex>
#include <QObject>
#include <QString>
#include <QUrl>

// QFileSystemModel с одной колонкой и ролью isDir — чтобы QML TreeView
// показывал только имя, а делегат мог быстро отличить папку от файла
// без обращения к Q_INVOKABLE.
class ProjectFileSystemModel : public QFileSystemModel
{
    Q_OBJECT
public:
    enum CustomRoles {
        IsDirRole = Qt::UserRole + 100,
    };

    using QFileSystemModel::QFileSystemModel;

    int columnCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
};


class ProjectController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *model READ model CONSTANT)
    Q_PROPERTY(QString rootPath READ rootPath NOTIFY rootPathChanged)
    Q_PROPERTY(bool hasProject READ hasProject NOTIFY rootPathChanged)
    Q_PROPERTY(QModelIndex projectRootIndex READ projectRootIndex NOTIFY rootPathChanged)

public:
    explicit ProjectController(QObject *parent = nullptr);

    QAbstractItemModel *model() const;
    QString rootPath() const { return m_rootPath; }
    bool hasProject() const { return !m_rootPath.isEmpty(); }
    QModelIndex projectRootIndex() const;

    Q_INVOKABLE void openProject(const QUrl &folderUrl);
    Q_INVOKABLE QString parentDir(const QString &path) const;

    Q_INVOKABLE bool createFolder(const QString &parentPath, const QString &name);
    Q_INVOKABLE bool createFile(const QString &parentPath, const QString &name);
    Q_INVOKABLE bool moveItem(const QString &sourcePath, const QString &targetDir);

    // Переименовывает файл/папку. Возвращает новый абсолютный путь (разделители
    // "/") при успехе или пустую строку при ошибке/без изменений.
    Q_INVOKABLE QString renameItem(const QString &path, const QString &newName);

signals:
    void rootPathChanged();
    void errorOccurred(const QString &message);

private:
    ProjectFileSystemModel *m_model;
    QString m_rootPath;
};
