#include "projecttreemodel.h"

#include <QAbstractItemModelTester>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

namespace {

bool writeFile(const QString &path, const QByteArray &content = {})
{
    QFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(content) == content.size();
}

QStringList childNames(const ProjectTreeModel &model, const QModelIndex &parent = {})
{
    QStringList names;
    for (int row = 0; row < model.rowCount(parent); ++row)
        names.append(model.data(model.index(row, 0, parent), Qt::DisplayRole).toString());
    return names;
}

} // namespace

class ProjectTreeModelTest : public QObject
{
    Q_OBJECT

private slots:
    void createItemsInSortedOrder();
    void lazyDirectoriesAndHiddenEntries();
    void moveRenameAndRemoveSubtree();
    void moveIntoUnpopulatedDirectory();
    void moveWithDestinationExpandedDuringRemoval();
    void invalidNames_data();
    void invalidNames();
};

void ProjectTreeModelTest::createItemsInSortedOrder()
{
    QTemporaryDir temp;
    QVERIFY(temp.isValid());
    ProjectTreeModel model;
    model.setRootDir(temp.path());
    QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
    QSignalSpy inserted(&model, &QAbstractItemModel::rowsInserted);

    QVERIFY(model.createFile(temp.path(), QStringLiteral("z.json")));
    QVERIFY(model.createFolder(temp.path(), QStringLiteral("Beta")));
    QVERIFY(model.createFile(temp.path(), QStringLiteral("a.json")));
    QVERIFY(model.createFolder(temp.path(), QStringLiteral(" alpha ")));
    QCOMPARE(childNames(model), QStringList({"alpha", "Beta", "a.json", "z.json"}));
    QCOMPARE(inserted.size(), 4);

    QVERIFY(QFileInfo(temp.filePath(QStringLiteral("alpha"))).isDir());
    QVERIFY(QFileInfo(temp.filePath(QStringLiteral("a.json"))).isFile());
    const QModelIndex alpha = model.indexForPath(temp.filePath(QStringLiteral("alpha")));
    QVERIFY(alpha.isValid());
    QVERIFY(!model.hasChildren(alpha));

    QVERIFY(!model.createFile(temp.path(), QStringLiteral("a.json")));
    QVERIFY(!model.createFolder(temp.path(), QStringLiteral("alpha")));
    QCOMPARE(inserted.size(), 4);
    QCOMPARE(model.rowCount(), 4);
}

void ProjectTreeModelTest::lazyDirectoriesAndHiddenEntries()
{
    QTemporaryDir temp;
    QVERIFY(temp.isValid());
    QDir dir(temp.path());
    QVERIFY(dir.mkpath(QStringLiteral("branch/nested")));
    QVERIFY(dir.mkdir(QStringLiteral("hiddenOnly")));
    QVERIFY(writeFile(temp.filePath(QStringLiteral(".hidden"))));
    QVERIFY(writeFile(temp.filePath(QStringLiteral("hiddenOnly/.secret"))));
    QVERIFY(writeFile(temp.filePath(QStringLiteral("branch/nested/first.json"))));

    ProjectTreeModel model;
    model.setRootDir(temp.path());
    QCOMPARE(childNames(model), QStringList({"branch", "hiddenOnly"}));
    const QModelIndex branch = model.indexForPath(temp.filePath(QStringLiteral("branch")));
    const QModelIndex hiddenOnly = model.indexForPath(temp.filePath(QStringLiteral("hiddenOnly")));
    QVERIFY(model.hasChildren(branch));
    QVERIFY(!model.hasChildren(hiddenOnly));

    // hasChildren must inspect visibility without populating or caching the directory.
    QVERIFY(writeFile(temp.filePath(QStringLiteral("hiddenOnly/visible.json"))));
    QVERIFY(model.hasChildren(hiddenOnly));
    QCOMPARE(childNames(model, hiddenOnly), QStringList({"visible.json"}));

    // Creating before the first expansion must appear once after lazy population.
    QVERIFY(model.createFile(temp.filePath(QStringLiteral("branch")), QStringLiteral("second.json")));
    const QModelIndex nested = model.indexForPath(temp.filePath(QStringLiteral("branch/nested")));
    const QModelIndex first = model.indexForPath(temp.filePath(QStringLiteral("branch/nested/first.json")));
    QVERIFY(first.isValid());
    QCOMPARE(model.parent(first), nested);
    QCOMPARE(model.parent(nested), branch);
    QCOMPARE(childNames(model, branch), QStringList({"nested", "second.json"}));
    QVERIFY(!model.indexForPath(temp.filePath(QStringLiteral("../outside.json"))).isValid());
    QVERIFY(!model.indexForPath(temp.filePath(QStringLiteral(".hidden"))).isValid());
    QVERIFY(!model.indexForPath(temp.path()).isValid());

    QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
}

void ProjectTreeModelTest::moveRenameAndRemoveSubtree()
{
    QTemporaryDir temp;
    QVERIFY(temp.isValid());
    QDir dir(temp.path());
    QVERIFY(dir.mkpath(QStringLiteral("source/nested")));
    QVERIFY(dir.mkdir(QStringLiteral("target")));
    QVERIFY(writeFile(temp.filePath(QStringLiteral("source/nested/child.json")), "preserved"));

    ProjectTreeModel model;
    model.setRootDir(temp.path());
    QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
    const QString source = temp.filePath(QStringLiteral("source"));
    const QString target = temp.filePath(QStringLiteral("target"));
    const QString moved = temp.filePath(QStringLiteral("target/source"));
    const QString renamed = temp.filePath(QStringLiteral("target/renamed"));
    const QString renamedFile = temp.filePath(QStringLiteral("target/renamed/nested/child.json"));

    QVERIFY(model.moveItem(source, source).isEmpty());
    QVERIFY(model.moveItem(source, source + QStringLiteral("/nested")).isEmpty());
    QCOMPARE(model.moveItem(source, target), moved);
    QVERIFY(!QFileInfo::exists(source));
    QVERIFY(!model.indexForPath(source).isValid());
    QVERIFY(model.indexForPath(moved + QStringLiteral("/nested/child.json")).isValid());

    QCOMPARE(model.renameItem(moved, QStringLiteral("renamed")), renamed);
    QVERIFY(!model.indexForPath(moved).isValid());
    const QModelIndex child = model.indexForPath(renamedFile);
    QVERIFY(child.isValid());
    QCOMPARE(model.data(child, ProjectTreeModel::FilePathRole).toString(), renamedFile);
    QFile saved(renamedFile);
    QVERIFY(saved.open(QIODevice::ReadOnly));
    QCOMPARE(saved.readAll(), QByteArray("preserved"));
    saved.close();

    QVERIFY(model.removeItem(renamed));
    QVERIFY(!QFileInfo::exists(renamed));
    QVERIFY(!model.indexForPath(renamedFile).isValid());
    QCOMPARE(model.rowCount(model.indexForPath(target)), 0);
    QVERIFY(!model.removeItem(renamed));
}

void ProjectTreeModelTest::moveIntoUnpopulatedDirectory()
{
    QTemporaryDir temp;
    QVERIFY(temp.isValid());
    QVERIFY(QDir(temp.path()).mkdir(QStringLiteral("target")));
    QVERIFY(writeFile(temp.filePath(QStringLiteral("source.json")), "keep"));
    ProjectTreeModel model;
    model.setRootDir(temp.path());
    QCOMPARE(model.rowCount(), 2);
    const QModelIndex target = model.indexForPath(temp.filePath(QStringLiteral("target")));
    QVERIFY(!model.hasChildren(target));

    const QString moved = temp.filePath(QStringLiteral("target/source.json"));
    QCOMPARE(model.moveItem(temp.filePath(QStringLiteral("source.json")),
                            temp.filePath(QStringLiteral("target"))), moved);
    QCOMPARE(model.rowCount(), 1);
    QVERIFY(model.hasChildren(target));
    QCOMPARE(childNames(model, target), QStringList({"source.json"}));
    QVERIFY(model.indexForPath(moved).isValid());
    QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
}

void ProjectTreeModelTest::moveWithDestinationExpandedDuringRemoval()
{
    QTemporaryDir temp;
    QVERIFY(temp.isValid());
    QVERIFY(QDir(temp.path()).mkdir(QStringLiteral("target")));
    QVERIFY(writeFile(temp.filePath(QStringLiteral("source.json"))));
    ProjectTreeModel model;
    model.setRootDir(temp.path());
    const QModelIndex target = model.indexForPath(temp.filePath(QStringLiteral("target")));
    connect(&model, &QAbstractItemModel::rowsAboutToBeRemoved, &model,
            [&model, target] { model.rowCount(target); });

    const QString moved = temp.filePath(QStringLiteral("target/source.json"));
    QCOMPARE(model.moveItem(temp.filePath(QStringLiteral("source.json")),
                            temp.filePath(QStringLiteral("target"))), moved);
    QCOMPARE(childNames(model, target), QStringList({"source.json"}));
    QCOMPARE(model.renameItem(moved, QStringLiteral("renamed.json")),
             temp.filePath(QStringLiteral("target/renamed.json")));
    QVERIFY(!model.indexForPath(moved).isValid());
    QCOMPARE(childNames(model, target), QStringList({"renamed.json"}));
}

void ProjectTreeModelTest::invalidNames_data()
{
    QTest::addColumn<QString>("name");
    QTest::newRow("empty") << QString();
    QTest::newRow("whitespace") << QStringLiteral("  ");
    QTest::newRow("dot") << QStringLiteral(".");
    QTest::newRow("parent") << QStringLiteral("..");
    QTest::newRow("padded-parent") << QStringLiteral(" .. ");
    QTest::newRow("forward-slash") << QStringLiteral("sub/child.json");
    QTest::newRow("backslash") << QStringLiteral("sub\\child.json");
    QTest::newRow("escape-folder") << QStringLiteral("../escaped");
}

void ProjectTreeModelTest::invalidNames()
{
    QFETCH(QString, name);
    QTemporaryDir temp;
    QVERIFY(temp.isValid());
    QVERIFY(QDir(temp.path()).mkdir(QStringLiteral("project")));
    const QString project = temp.filePath(QStringLiteral("project"));
    const QString file = project + QStringLiteral("/original.json");
    QVERIFY(writeFile(file, "unchanged"));

    ProjectTreeModel model;
    model.setRootDir(project);
    QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
    QSignalSpy inserted(&model, &QAbstractItemModel::rowsInserted);
    QSignalSpy removed(&model, &QAbstractItemModel::rowsRemoved);

    QVERIFY(!model.createFile(project, name));
    QVERIFY(!model.createFolder(project, name));
    QVERIFY(model.renameItem(file, name).isEmpty());
    QCOMPARE(inserted.size(), 0);
    QCOMPARE(removed.size(), 0);
    QCOMPARE(childNames(model), QStringList({"original.json"}));
    QCOMPARE(QDir(temp.path()).entryList(QDir::AllEntries | QDir::NoDotAndDotDot),
             QStringList({"project"}));
    QFile original(file);
    QVERIFY(original.open(QIODevice::ReadOnly));
    QCOMPARE(original.readAll(), QByteArray("unchanged"));
}

QTEST_GUILESS_MAIN(ProjectTreeModelTest)
#include "projecttreemodel_test.moc"
