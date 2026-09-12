#include "documentcontroller.h"
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QSettings>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>
#include <QUuid>

class DocumentControllerTest : public QObject
{
    Q_OBJECT
    QTemporaryDir m_settings;
    QString m_dataPath;

    static QString read(const QString &path)
    {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            return {};
        return QString::fromUtf8(file.readAll());
    }
    static void write(const QString &path, const QString &text)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Text));
        QCOMPARE(file.write(text.toUtf8()), text.toUtf8().size());
    }
    QString draft(const QString &path) const
    {
        return m_dataPath + "/drafts/" + QCryptographicHash::hash(
            QDir::cleanPath(path).toUtf8(), QCryptographicHash::Sha1).toHex() + ".draft";
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_settings.isValid());
        QCoreApplication::setOrganizationName("DSLRayTests");
        QCoreApplication::setApplicationName("documents-" + QUuid::createUuid().toString(QUuid::WithoutBraces));
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_settings.path());
        QStandardPaths::setTestModeEnabled(true);
        m_dataPath = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    }
    void init() { QSettings().clear(); }

    void transparentAndSafeWrites()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath("example.json");
        write(path, "");
        DocumentController docs;
        docs.openFile(path);
        QVERIFY(docs.hasDocuments());
        QVERIFY(docs.activeContent().isEmpty());
        docs.applyEdit("transparent");
        QCOMPARE(read(path), QString("transparent"));
        QVERIFY(!docs.hasUnsavedChanges());
        docs.setSafeMode(true);
        docs.applyEdit("draft");
        QCOMPARE(read(path), QString("transparent"));
        QCOMPARE(read(draft(path)), QString("draft"));
        QVERIFY(docs.hasUnsavedChanges());
        QVERIFY(docs.saveActive());
        QCOMPARE(read(path), QString("draft"));
        QVERIFY(!QFile::exists(draft(path)));
        QVERIFY(!docs.hasUnsavedChanges());
    }
    void failedSaveKeepsDraftAndCanRetry()
    {
        QTemporaryDir dir;
        const QString folder = dir.filePath("folder");
        QVERIFY(QDir().mkdir(folder));
        const QString path = folder + "/example.json";
        write(path, "original");
        DocumentController docs;
        docs.setSafeMode(true);
        docs.openFile(path);
        docs.applyEdit("unsaved");
        QVERIFY(QDir().rename(folder, dir.filePath("moved")));
        QSignalSpy errors(&docs, &DocumentController::errorOccurred);
        QVERIFY(!docs.saveActive());
        QCOMPARE(errors.count(), 1);
        QCOMPARE(read(draft(path)), QString("unsaved"));
        QVERIFY(docs.hasUnsavedChanges());
        QCOMPARE(read(dir.filePath("moved/example.json")), QString("original"));
        QVERIFY(QDir().rename(dir.filePath("moved"), folder));
        QVERIFY(docs.saveActive());
        QCOMPARE(read(path), QString("unsaved"));
        QVERIFY(!QFile::exists(draft(path)));
    }
    void applyAndDiscardHandlePartialFailures()
    {
        QTemporaryDir dir;
        QVERIFY(QDir().mkdir(dir.filePath("sub")));
        const QString first = dir.filePath("first.json");
        const QString second = dir.filePath("sub/second.json");
        write(first, "first");
        write(second, "second");
        DocumentController docs;
        docs.setSafeMode(true);
        docs.openFile(first);
        docs.applyEdit("first draft");
        docs.openFile(second);
        docs.applyEdit("second draft");
        QVERIFY(QDir().rename(dir.filePath("sub"), dir.filePath("moved")));
        QVERIFY(!docs.applyAllDrafts());
        QCOMPARE(read(first), QString("first draft"));
        QVERIFY(!QFile::exists(draft(first)));
        QCOMPARE(read(draft(second)), QString("second draft"));
        QVERIFY(!docs.discardAllDrafts());
        QCOMPARE(docs.activeContent(), QString("second draft"));
        docs.setSafeMode(false);
        QVERIFY(docs.safeMode());
        QVERIFY(QDir().rename(dir.filePath("moved"), dir.filePath("sub")));
        QVERIFY(docs.discardAllDrafts());
        QCOMPARE(docs.activeContent(), QString("second"));
        QVERIFY(!docs.hasUnsavedChanges());
        docs.setSafeMode(false);
        QVERIFY(!docs.safeMode());
    }
    void pendingEditsFlushBeforeSaveAndClose()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath("example.json");
        write(path, "original");
        DocumentController docs;
        docs.setSafeMode(true);
        docs.openFile(path);
        QString pending = "latest keystroke";
        connect(&docs, &DocumentController::flushRequested, &docs, [&] {
            if (!pending.isEmpty()) {
                const QString text = pending;
                pending.clear();
                docs.applyEdit(text);
            }
        });
        QVERIFY(docs.saveActive());
        QCOMPARE(read(path), QString("latest keystroke"));
        pending = "last edit before closing";
        docs.closeAt(0);
        QCOMPARE(docs.rowCount(), 0);
        docs.openFile(path);
        QCOMPARE(docs.activeContent(), QString("last edit before closing"));
        QVERIFY(docs.hasUnsavedChanges());
    }
    void renameFolderRebasesOpenDocumentsAndDrafts()
    {
        QTemporaryDir dir;
        const QString oldFolder = dir.filePath("old");
        const QString newFolder = dir.filePath("new");
        QVERIFY(QDir().mkdir(oldFolder));
        QVERIFY(QDir().mkdir(dir.filePath("old-sibling")));
        const QString first = oldFolder + "/a.json";
        const QString second = oldFolder + "/b.json";
        const QString unrelated = dir.filePath("old-sibling/c.json");
        write(first, "a");
        write(second, "b");
        write(unrelated, "c");
        DocumentController docs;
        docs.setSafeMode(true);
        docs.openFile(first);
        docs.applyEdit("draft a");
        docs.openFile(second);
        docs.openFile(unrelated);
        QVERIFY(QDir().rename(oldFolder, newFolder));
        docs.handlePathRenamed(oldFolder, newFolder);
        QCOMPARE(docs.data(docs.index(0, 0), DocumentController::PathRole).toString(), newFolder + "/a.json");
        QCOMPARE(docs.data(docs.index(1, 0), DocumentController::PathRole).toString(), newFolder + "/b.json");
        QCOMPARE(docs.activePath(), unrelated);
        QVERIFY(!QFile::exists(draft(first)));
        QCOMPARE(read(draft(newFolder + "/a.json")), QString("draft a"));
        docs.closeAt(0);
        docs.openFile(newFolder + "/a.json");
        QCOMPARE(docs.activeContent(), QString("draft a"));
    }
    void closeAndActivationKeepValidModelState()
    {
        QTemporaryDir dir;
        DocumentController docs;
        for (int i = 0; i < 3; ++i) {
            const QString path = dir.filePath(QString::number(i) + ".json");
            write(path, QString::number(i));
            docs.openFile(path);
        }
        docs.activate(1);
        docs.closeAt(0);
        QCOMPARE(docs.activeIndex(), 0);
        QCOMPARE(docs.activeContent(), QString("1"));
        docs.closeAt(0);
        QCOMPARE(docs.activeContent(), QString("2"));
        docs.closeAt(0);
        QCOMPARE(docs.activeIndex(), -1);
        QVERIFY(!docs.hasDocuments());
    }
    void cleanupTestCase()
    {
        // This uniquely named test profile never contains user application data.
        QVERIFY(m_dataPath.endsWith(QCoreApplication::applicationName()));
        if (QDir(m_dataPath).exists())
            QVERIFY(QDir(m_dataPath).removeRecursively());
    }
};

QTEST_GUILESS_MAIN(DocumentControllerTest)
#include "documentcontroller_test.moc"
