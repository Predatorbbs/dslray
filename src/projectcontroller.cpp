#include "projectcontroller.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>


// ── ProjectFileSystemModel ──────────────────────────────────────────────

int ProjectFileSystemModel::columnCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return 1;
}

QVariant ProjectFileSystemModel::data(const QModelIndex &index, int role) const
{
    if (role == IsDirRole)
        return QFileSystemModel::isDir(index);
    return QFileSystemModel::data(index, role);
}

QHash<int, QByteArray> ProjectFileSystemModel::roleNames() const
{
    auto names = QFileSystemModel::roleNames();
    names.insert(IsDirRole, "isDir");
    return names;
}


// ── ProjectController ───────────────────────────────────────────────────

ProjectController::ProjectController(QObject *parent)
    : QObject(parent)
    , m_model(new ProjectFileSystemModel(this))
{
    m_model->setReadOnly(false);
    m_model->setFilter(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden);
    // До openProject() rootPath не задан — модель пустая для дерева.
}

QAbstractItemModel *ProjectController::model() const
{
    return m_model;
}

QModelIndex ProjectController::projectRootIndex() const
{
    if (m_rootPath.isEmpty())
        return {};
    return m_model->index(m_rootPath);
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
    m_model->setRootPath(clean);
    m_rootPath = clean;
    emit rootPathChanged();
}

bool ProjectController::createFolder(const QString &parentPath, const QString &name)
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
    return true;
}

bool ProjectController::createFile(const QString &parentPath, const QString &name)
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
    return true;
}

bool ProjectController::moveItem(const QString &sourcePath, const QString &targetDir)
{
    if (sourcePath.isEmpty() || targetDir.isEmpty())
        return false;

    QFileInfo srcInfo(sourcePath);
    if (!srcInfo.exists())
        return false;

    QDir dst(targetDir);
    if (!dst.exists())
        return false;

    const QString srcCanonical = srcInfo.canonicalFilePath();
    const QString dstCanonical = QFileInfo(targetDir).canonicalFilePath();

    // Папку нельзя кинуть в саму себя или внутрь своей же ветки.
    if (srcInfo.isDir()) {
        if (dstCanonical == srcCanonical)
            return false;
        if (dstCanonical.startsWith(srcCanonical + QLatin1Char('/')))
            return false;
    }
    // Если родитель не меняется — никакого перемещения.
    if (QFileInfo(srcInfo.absolutePath()).canonicalFilePath() == dstCanonical)
        return false;

    const QString newPath = dst.filePath(srcInfo.fileName());
    if (QFile::exists(newPath)) {
        emit errorOccurred(tr("В '%1' уже есть '%2'").arg(targetDir, srcInfo.fileName()));
        return false;
    }

    if (srcInfo.isDir()) {
        if (!QDir().rename(srcInfo.absoluteFilePath(), newPath)) {
            emit errorOccurred(tr("Не удалось переместить папку '%1'").arg(srcInfo.fileName()));
            return false;
        }
    } else {
        QFile f(srcInfo.absoluteFilePath());
        if (!f.rename(newPath)) {
            emit errorOccurred(tr("Не удалось переместить '%1': %2")
                                   .arg(srcInfo.fileName(), f.errorString()));
            return false;
        }
    }
    return true;
}
