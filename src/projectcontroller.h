#pragma once

#include <QAbstractItemModel>
#include <QModelIndex>
#include <QObject>
#include <QString>
#include <QUrl>

#include "projecttreemodel.h"

// Контроллер панели «ПРОЕКТ»: владеет моделью дерева, открывает проект и
// проксирует файловые операции в модель (она обновляет себя без фантомов).
class ProjectController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *model READ model CONSTANT)
    Q_PROPERTY(QString rootPath READ rootPath NOTIFY rootPathChanged)
    Q_PROPERTY(bool hasProject READ hasProject NOTIFY rootPathChanged)
    Q_PROPERTY(QModelIndex projectRootIndex READ projectRootIndex NOTIFY rootPathChanged)
    // Спрашивать подтверждение перед удалением. Хранится в QSettings.
    Q_PROPERTY(bool confirmDelete READ confirmDelete WRITE setConfirmDelete NOTIFY confirmDeleteChanged)

public:
    explicit ProjectController(QObject *parent = nullptr);

    QAbstractItemModel *model() const;
    QString rootPath() const { return m_rootPath; }
    bool hasProject() const { return !m_rootPath.isEmpty(); }
    // Корень модели = содержимое проекта, поэтому верхний уровень — невалидный
    // индекс.
    QModelIndex projectRootIndex() const { return {}; }

    Q_INVOKABLE void openProject(const QUrl &folderUrl);
    Q_INVOKABLE QString parentDir(const QString &path) const;
    Q_INVOKABLE QModelIndex indexForPath(const QString &path) const
    {
        return m_model->indexForPath(path);
    }

    Q_INVOKABLE bool createFolder(const QString &parentPath, const QString &name);
    Q_INVOKABLE bool createFile(const QString &parentPath, const QString &name);
    // Перемещает файл/папку в targetDir. Возвращает новый абсолютный путь
    // (разделители "/") при успехе или пустую строку при ошибке/без изменений.
    Q_INVOKABLE QString moveItem(const QString &sourcePath, const QString &targetDir);

    // Переименовывает файл/папку. Возвращает новый абсолютный путь (разделители
    // "/") при успехе или пустую строку при ошибке/без изменений.
    Q_INVOKABLE QString renameItem(const QString &path, const QString &newName);

    // Удаляет файл/папку (папку — со всем содержимым).
    Q_INVOKABLE bool deleteItem(const QString &path);

    bool confirmDelete() const { return m_confirmDelete; }
    void setConfirmDelete(bool on);

signals:
    void rootPathChanged();
    void errorOccurred(const QString &message);
    void confirmDeleteChanged();

private:
    ProjectTreeModel *m_model;
    QString m_rootPath;
    bool m_confirmDelete = true;
};
