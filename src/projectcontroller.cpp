#include "projectcontroller.h"

#include <QDir>
#include <QFileInfo>
#include <QSettings>


ProjectController::ProjectController(QObject *parent)
    : QObject(parent)
    , m_model(new ProjectTreeModel(this))
{
    connect(m_model, &ProjectTreeModel::errorOccurred,
            this, &ProjectController::errorOccurred);
}

QAbstractItemModel *ProjectController::model() const
{
    return m_model;
}

QString ProjectController::parentDir(const QString &path) const
{
    return QFileInfo(path).absolutePath();
}

void ProjectController::openProject(const QUrl &folderUrl)
{
    const QString path = folderUrl.toLocalFile();
    if (path.isEmpty() || !QDir(path).exists()) {
        emit errorOccurred(tr("Папка не найдена: %1").arg(path));
        return;
    }
    const QString clean = QDir::cleanPath(path);
    m_model->setRootDir(clean);
    m_rootPath = clean;
    QSettings().setValue(QStringLiteral("session/projectPath"), clean);
    emit rootPathChanged();
}

bool ProjectController::createFolder(const QString &parentPath, const QString &name)
{
    return m_model->createFolder(parentPath, name);
}

bool ProjectController::createFile(const QString &parentPath, const QString &name)
{
    return m_model->createFile(parentPath, name);
}

QString ProjectController::renameItem(const QString &path, const QString &newName)
{
    return m_model->renameItem(path, newName);
}

QString ProjectController::moveItem(const QString &sourcePath, const QString &targetDir)
{
    return m_model->moveItem(sourcePath, targetDir);
}
