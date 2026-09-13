#include <QElapsedTimer>
#include "documentcontroller.h"
#include "editorpreferences.h"
#include "jsonhighlighter.h"
#include "projectcontroller.h"
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QSignalSpy>
#include <QTextDocument>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSettings>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>
#include <memory>

class LineNumberMonitor : public QObject
{
    Q_OBJECT
public:
    explicit LineNumberMonitor(QObject *repeater) : m_repeater(repeater) { recordCount(); }
    int peak = 0;
public slots:
    void recordCount() { peak = qMax(peak, m_repeater->property("count").toInt()); }
private:
    QObject *m_repeater;
};

class QmlIntegrationTest : public QObject
{
    Q_OBJECT
    QTemporaryDir m_temp;
    QStringList m_warnings;
    std::unique_ptr<ProjectController> m_project;
    std::unique_ptr<DocumentController> m_docs;
    std::unique_ptr<EditorPreferences> m_preferences;
    std::unique_ptr<QQmlApplicationEngine> m_engine;
    QObject *m_root = nullptr;

    QVariant evaluate(QObject *scope, const QString &expression)
    {
        const qsizetype dot = expression.indexOf('.');
        QObject *target = scope->findChild<QObject *>(expression.left(dot));
        return target ? target->property(expression.mid(dot + 1).toUtf8().constData()) : QVariant();
    }
    QObject *object(QObject *scope, const QString &expression)
    {
        return expression.contains('.') ? evaluate(scope, expression).value<QObject *>()
                                        : scope->findChild<QObject *>(expression);
    }
    void capture(const QString &name)
    {
        const QString output = qEnvironmentVariable("DSLRAY_TEST_CAPTURE_DIR");
        if (output.isEmpty()) return;
        QDir().mkpath(output);
        auto *window = qobject_cast<QQuickWindow *>(m_root);
        QVERIFY(window);
        QTest::qWait(80);
        const QImage image = window->grabWindow();
        QVERIFY(!image.isNull());
        QVERIFY(image.save(output + "/" + name + ".png"));
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_temp.isValid());
        QCoreApplication::setOrganizationName("DSLRayTests");
        QCoreApplication::setApplicationName("qml-integration");
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_temp.path());
        QStandardPaths::setTestModeEnabled(true);
        m_project = std::make_unique<ProjectController>();
        m_docs = std::make_unique<DocumentController>();
        m_preferences = std::make_unique<EditorPreferences>();
        connect(m_project.get(), &ProjectController::fileOperationRequested,
                m_docs.get(), &DocumentController::flushRequested);
        qmlRegisterType<JsonHighlighter>("DSLRay", 1, 0, "JsonHighlighter");
        m_engine = std::make_unique<QQmlApplicationEngine>();
        m_engine->rootContext()->setContextProperty("Project", m_project.get());
        m_engine->rootContext()->setContextProperty("Docs", m_docs.get());
        m_engine->rootContext()->setContextProperty("Preferences", m_preferences.get());
        connect(m_engine.get(), &QQmlEngine::warnings, this, [this](const QList<QQmlError> &errors) {
            for (const auto &error : errors) m_warnings.append(error.toString());
        });
        m_engine->loadFromModule("DSLRay", "Main");
        QVERIFY2(!m_engine->rootObjects().isEmpty(), qPrintable(m_warnings.join("\n")));
        m_root = m_engine->rootObjects().first();
        QTest::qWait(100);
    }
    void menuPagesLoadOnDemandAndKeepState()
    {
        QObject *menu = nullptr;
        for (QObject *child : m_root->findChildren<QObject *>()) {
            if (child->metaObject()->indexOfMethod("requestToggleSafe()") >= 0) {
                menu = child;
                break;
            }
        }
        QVERIFY(menu);
        QCOMPARE(evaluate(menu, "profilePage.active").toBool(), false);
        QCOMPARE(evaluate(menu, "editorPage.active").toBool(), false);
        m_root->setProperty("menuOpen", true);
        QTest::qWait(50);
        QObject *popup = object(menu, "popup");
        QVERIFY(popup);
        const QList<QPair<int, QString>> pages {
            {0, "profilePage"}, {2, "editorPage"}, {3, "appearancePage"}, {4, "aboutPage"}
        };
        for (const auto &page : pages) {
            popup->setProperty("selectedIndex", page.first);
            QTest::qWait(50);
            QVERIFY(evaluate(menu, page.second + ".active").toBool());
            QCOMPARE(evaluate(menu, page.second + ".status").toInt(), 1); // Loader.Ready
            QVERIFY(object(menu, page.second + ".item"));
            if (page.first == 3) capture("appearance-light");
        }
        QObject *profile = object(menu, "profilePage.item");
        popup->setProperty("selectedIndex", 0);
        QCOMPARE(object(menu, "profilePage.item"), profile);
        m_preferences->setThemeId("dark");
        popup->setProperty("selectedIndex", 3);
        capture("appearance-dark");
        m_root->setProperty("menuOpen", false);
    }
    void pendingEditorTextSurvivesSaveRenameMoveDelete()
    {
        const QString folder = m_temp.filePath("project");
        QVERIFY(QDir().mkdir(folder));
        const QString path = folder + "/sample.json";
        {
            QFile file(path);
            QVERIFY(file.open(QIODevice::WriteOnly));
            file.write("{\n  \"elementName\": \"root\"\n}");
        }
        m_project->openProject(QUrl::fromLocalFile(folder));
        m_docs->openFile(path);
        QTest::qWait(50);
        QObject *editor = object(m_root, "codeEditor");
        QVERIFY(editor);
        QObject *area = object(editor, "ta");
        QVERIFY(area);
        const QString edited = "{\n  \"elementName\": \"edited\"\n}";
        area->setProperty("text", edited);
        QVERIFY(m_docs->saveActive()); // Before the 400ms debounce fires.
        {
            QFile saved(path);
            QVERIFY(saved.open(QIODevice::ReadOnly | QIODevice::Text));
            QCOMPARE(QString::fromUtf8(saved.readAll()), edited);
        }
        area->setProperty("text", QString("{\"elementName\":\"renamed\"}"));
        const QString renamed = m_project->renameItem(path, "renamed.json");
        QVERIFY(!renamed.isEmpty());
        m_docs->handlePathRenamed(path, renamed);
        QCOMPARE(m_docs->activeContent(), QString("{\"elementName\":\"renamed\"}"));
        QVERIFY(!QFile::exists(path));
        QVERIFY(m_project->createFolder(folder, "target"));
        area->setProperty("text", QString("{\"elementName\":\"moved\"}"));
        const QString moved = m_project->moveItem(renamed, folder + "/target");
        QVERIFY(!moved.isEmpty());
        m_docs->handlePathRenamed(renamed, moved);
        QCOMPARE(m_docs->activeContent(), QString("{\"elementName\":\"moved\"}"));
        m_preferences->setWordWrap(true);
        m_preferences->setCodeFontSize(20);
        QTest::qWait(80);
        capture("editor-dark");
        const QString large = QString("{}\n").repeated(5000);
        area->setProperty("text", large);
        QTest::qWait(100);
        QVERIFY(QMetaObject::invokeMethod(editor, "gotoOffset", Q_ARG(QVariant, QVariant(large.size()))));
        QTest::qWait(100);
        QObject *viewport = object(editor, "editor");
        QVERIFY(viewport);
        QVERIFY(viewport->property("firstVisibleLine").toInt() > 4900);
        QObject *lineNumbers = object(editor, "lineNumbers");
        QVERIFY(lineNumbers);
        const int lineNumberItems = lineNumbers->property("count").toInt();
        QVERIFY(lineNumberItems > 0);
        QVERIFY(lineNumberItems < 100);
        area->setProperty("text", QString("{\"elementName\":\"deleted\"}"));
        QVERIFY(m_project->deleteItem(moved));
        m_docs->closePath(moved);
        QVERIFY(!QFile::exists(moved));
        QVERIFY(!m_docs->hasDocuments());
    }
    void switchingIndentedAndEmptyTabs_data()
    {
        QTest::addColumn<int>("lines");
        QTest::addColumn<bool>("wrap");
        QTest::newRow("385-no-wrap") << 385 << false;
        QTest::newRow("385-wrap") << 385 << true;
        QTest::newRow("2000-no-wrap") << 2000 << false;
        QTest::newRow("2000-wrap") << 2000 << true;
    }
    void switchingIndentedAndEmptyTabs()
    {
        QTest::failOnWarning();
        QFETCH(int, lines);
        QFETCH(bool, wrap);
        m_preferences->setWordWrap(wrap);
        const QString path = m_temp.filePath("indented.json");
        const QString emptyPath = m_temp.filePath("empty.json");
        QString text = "[\n";
        for (int i = 0; i < lines - 2; ++i) {
            text += QStringLiteral("    {\"elementName\": \"item%1\", \"value\": \"some text for a wrapped JSON line with indentation\"}%2\n")
                        .arg(i).arg(i == lines - 3 ? "" : ",");
        }
        text += "]";
        for (const auto &entry : {qMakePair(path, text), qMakePair(emptyPath, QString())}) {
            QFile file(entry.first);
            QVERIFY(file.open(QIODevice::WriteOnly));
            QCOMPARE(file.write(entry.second.toUtf8()), entry.second.toUtf8().size());
        }
        m_docs->openFile(path);
        m_docs->openFile(emptyPath);
        QTest::qWait(20);
        QObject *editor = object(m_root, "codeEditor");
        QVERIFY(editor);
        QObject *area = object(editor, "ta");
        QVERIFY(area);
        auto *quickDoc = area->property("textDocument").value<QQuickTextDocument *>();
        QVERIFY(quickDoc);
        QObject *lineNumbers = object(editor, "lineNumbers");
        QVERIFY(lineNumbers);
        LineNumberMonitor monitor(lineNumbers);
        QVERIFY(connect(lineNumbers, SIGNAL(countChanged()), &monitor, SLOT(recordCount())));
        int peakNotifications = 0;
        for (int repeat = 0; repeat < 2; ++repeat) {
            for (int target : {0, 1}) {
                QSignalSpy changes(quickDoc->textDocument(), &QTextDocument::contentsChanged);
                QElapsedTimer elapsed;
                elapsed.start();
                m_docs->activate(target);
                QTest::qWait(1); // Include deferred formatting and scene updates.
                qInfo() << "Switch" << lines << "lines, wrap" << wrap << "to" << target
                        << ":" << elapsed.elapsed() << "ms," << changes.count() << "notifications";
                QCOMPARE(area->property("text").toString(), target == 0 ? text : QString());
                peakNotifications = qMax(peakNotifications, int(changes.count()));
                if (target == 0) {
                    QVERIFY(QMetaObject::invokeMethod(editor, "gotoOffset", Q_ARG(QVariant, QVariant(text.size()))));
                    QTest::qWait(1);
                }
            }
        }
        // Switching before the debounce fires must flush the outgoing file only.
        m_docs->activate(0);
        const QString edited = text + "\n  ";
        area->setProperty("text", edited);
        m_docs->activate(1);
        QCOMPARE(area->property("text").toString(), QString());
        m_docs->activate(0);
        QCOMPARE(area->property("text").toString(), edited);
        {
            QFile saved(path);
            QVERIFY(saved.open(QIODevice::ReadOnly | QIODevice::Text));
            QCOMPARE(QString::fromUtf8(saved.readAll()), edited);
            QFile emptyFile(emptyPath);
            QCOMPARE(emptyFile.size(), 0);
        }
        QTest::qWait(1);
        if (lines == 385 && wrap)
            capture("tab-switch-wrapped");
        m_docs->closePath(path);
        m_docs->closePath(emptyPath);
        QVERIFY2(peakNotifications <= 5, "Tab switch must not update the editor once per line");
        QVERIFY2(monitor.peak < 100, "Tab switch must not instantiate line numbers for the entire file");
    }
    void selectedLinesIndentAndUndo_data()
    {
        QTest::addColumn<bool>("tabs");
        QTest::addColumn<bool>("reverse");
        QTest::newRow("spaces-forward") << false << false;
        QTest::newRow("spaces-reverse") << false << true;
        QTest::newRow("tabs-forward") << true << false;
        QTest::newRow("tabs-reverse") << true << true;
    }
    void selectedLinesIndentAndUndo()
    {
        QTest::failOnWarning();
        QFETCH(bool, tabs);
        QFETCH(bool, reverse);
        m_preferences->setIndentWidth(tabs ? 4 : 2);
        m_preferences->setIndentUseTabs(tabs);
        const QString path = m_temp.filePath("indent-keys.json");
        const QString body = "  \"first\": 1,\n  \"second\": 2\n";
        const QString original = "{\n" + body + "}\n";
        {
            QFile file(path);
            QVERIFY(file.open(QIODevice::WriteOnly));
            file.write(original.toUtf8());
        }
        m_docs->openFile(path);
        QTest::qWait(20);
        QObject *area = object(object(m_root, "codeEditor"), "ta");
        QVERIFY(area);
        auto *item = qobject_cast<QQuickItem *>(area);
        QVERIFY(item);
        item->forceActiveFocus();
        auto *window = qobject_cast<QQuickWindow *>(m_root);
        QVERIFY(window);
        QVERIFY(area->property("activeFocus").toBool());
        const int from = 2, to = original.indexOf('}');
        QVERIFY(QMetaObject::invokeMethod(area, "select",
            Q_ARG(int, reverse ? to : from), Q_ARG(int, reverse ? from : to)));
        const QString unit = tabs ? "\t" : "  ";
        const QString once = "{\n" + unit + "  \"first\": 1,\n" + unit + "  \"second\": 2\n}\n";
        const QString twice = "{\n" + unit + unit + "  \"first\": 1,\n" + unit + unit + "  \"second\": 2\n}\n";
        QTest::keyClick(window, Qt::Key_Tab);
        QTest::qWait(20); // Exercise deferred layout too, before checking Undo.
        QCOMPARE(area->property("text").toString(), once);
        QCOMPARE(area->property("selectionStart").toInt(), from);
        QCOMPARE(area->property("selectionEnd").toInt(), to + 2 * unit.size());
        QCOMPARE(area->property("cursorPosition").toInt(), reverse ? from : to + 2 * unit.size());
        QTest::keyClick(window, Qt::Key_Tab);
        QTest::qWait(20);
        QCOMPARE(area->property("text").toString(), twice);
        QTest::keyClick(window, Qt::Key_Tab, Qt::ShiftModifier);
        QTest::qWait(20);
        QCOMPARE(area->property("text").toString(), once);
        QTest::keyClick(window, Qt::Key_Backtab);
        QTest::qWait(20);
        QCOMPARE(area->property("text").toString(), original);
        QCOMPARE(area->property("cursorPosition").toInt(), reverse ? from : to);
        for (const QString &expected : {once, twice, once, original}) {
            QTest::keyClick(window, Qt::Key_Z, Qt::ControlModifier);
            QTest::qWait(20);
            QCOMPARE(area->property("text").toString(), expected);
        }
        for (const QString &expected : {once, twice, once, original}) {
            QTest::keyClick(window, Qt::Key_Y, Qt::ControlModifier);
            QTest::qWait(20);
            QCOMPARE(area->property("text").toString(), expected);
        }
        // A tab without a selection inserts at the caret, not at line start.
        area->setProperty("cursorPosition", 1);
        QTest::keyClick(window, Qt::Key_Tab);
        QTest::qWait(20);
        const QString insertion = tabs ? "\t" : " ";
        QCOMPARE(area->property("text").toString(), "{" + insertion + original.mid(1));
        QTest::keyClick(window, Qt::Key_Z, Qt::ControlModifier);
        QTest::qWait(20);
        QCOMPARE(area->property("text").toString(), original);
        // Shift+Tab without selection removes the current line's leading indent.
        area->setProperty("cursorPosition", 6);
        QTest::keyClick(window, Qt::Key_Backtab, Qt::ShiftModifier);
        QTest::qWait(20);
        QCOMPARE(area->property("text").toString(), "{\n\"first\": 1,\n  \"second\": 2\n}\n");
        QTest::keyClick(window, Qt::Key_Z, Qt::ControlModifier);
        QTest::qWait(20);
        QCOMPARE(area->property("text").toString(), original);
        m_docs->closePath(path);
    }
    void largeSelectionIsOneEdit()
    {
        QTest::failOnWarning();
        m_preferences->setIndentWidth(2);
        m_preferences->setIndentUseTabs(false);
        const QString path = m_temp.filePath("large-indent.json");
        const QString original = "[\n" + QString("  true,\n").repeated(499) + "  true\n]";
        {
            QFile file(path);
            QVERIFY(file.open(QIODevice::WriteOnly));
            file.write(original.toUtf8());
        }
        m_docs->openFile(path);
        QTest::qWait(20);
        QObject *area = object(object(m_root, "codeEditor"), "ta");
        QVERIFY(area);
        auto *item = qobject_cast<QQuickItem *>(area);
        QVERIFY(item);
        item->forceActiveFocus();
        auto *quickDoc = area->property("textDocument").value<QQuickTextDocument *>();
        QVERIFY(quickDoc);
        QVERIFY(QMetaObject::invokeMethod(area, "select", Q_ARG(int, 0), Q_ARG(int, int(original.size()))));
        QSignalSpy changes(quickDoc->textDocument(), &QTextDocument::contentsChanged);
        QElapsedTimer elapsed;
        elapsed.start();
        auto *window = qobject_cast<QQuickWindow *>(m_root);
        QVERIFY(window);
        QTest::keyClick(window, Qt::Key_Tab);
        QTest::qWait(20);
        qInfo() << "Indent 502 selected lines:" << elapsed.elapsed() << "ms," << changes.count() << "notifications";
        QString indented = original;
        indented.replace("\n", "\n  ");
        indented.prepend("  ");
        QCOMPARE(area->property("text").toString(), indented);
        QVERIFY(changes.count() <= 3);
        QTest::keyClick(window, Qt::Key_Z, Qt::ControlModifier);
        QTest::qWait(20);
        QCOMPARE(area->property("text").toString(), original);
        QTest::keyClick(window, Qt::Key_Y, Qt::ControlModifier);
        QTest::qWait(20);
        QCOMPARE(area->property("text").toString(), indented);
        QVERIFY(m_docs->saveActive());
        QFile saved(path);
        QVERIFY(saved.open(QIODevice::ReadOnly | QIODevice::Text));
        QCOMPARE(QString::fromUtf8(saved.readAll()), indented);
        saved.close();
        m_docs->closePath(path);
    }
    void noQmlBindingErrors()
    {
        QVERIFY2(m_warnings.isEmpty(), qPrintable(m_warnings.join("\n")));
    }
    void cleanupTestCase()
    {
        m_engine.reset();
        m_preferences.reset();
        m_docs.reset();
        m_project.reset();
    }
};
int main(int argc, char **argv)
{
    qputenv("QT_QPA_PLATFORM", "offscreen");
    qputenv("QT_QUICK_BACKEND", "software");
#ifdef Q_OS_WIN
    qputenv("QT_QPA_FONTDIR", "C:/Windows/Fonts");
#endif
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Basic");
    QmlIntegrationTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "qmlintegration_test.moc"
