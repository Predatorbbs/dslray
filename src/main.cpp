#include <QDir>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSettings>
#include <QStringList>
#include <QUrl>
#include <QtQml>

#include "documentcontroller.h"
#include "jsonhighlighter.h"
#include "projectcontroller.h"

// Восстанавливает прошлую сессию: открытый проект, набор вкладок и активную.
// Вызывается после загрузки QML — состояние применяется через сигналы, как при
// обычном открытии пользователем (без гонок с асинхронной загрузкой модели ФС).
static void restoreSession(ProjectController &project, DocumentController &documents)
{
    QSettings settings;
    const QString projectPath = settings.value(QStringLiteral("session/projectPath")).toString();
    const QStringList openFiles = settings.value(QStringLiteral("session/openFiles")).toStringList();
    const QString activePath = settings.value(QStringLiteral("session/activePath")).toString();

    if (!projectPath.isEmpty() && QDir(projectPath).exists())
        project.openProject(QUrl::fromLocalFile(projectPath));

    for (const QString &file : openFiles)
        documents.openFile(file);

    // Повторное открытие уже открытого файла просто делает его активным.
    if (!activePath.isEmpty())
        documents.openFile(activePath);
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QGuiApplication::setApplicationName("DSLRay");
    QGuiApplication::setApplicationDisplayName("DSLRay");
    QGuiApplication::setOrganizationName("DSLRay");
    QGuiApplication::setOrganizationDomain("dslray.local");
    QGuiApplication::setApplicationVersion("0.3.0");

    // Иконка окна / панели задач из встроенных ресурсов (см. dslray_icons.qrc).
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/icons/dslray_icon.png")));

    // Базовый стиль Controls — рисуем UI сами, лишний нативный стиль ни к чему.
    QQuickStyle::setStyle("Basic");

    // JSON-подсветка для редактора кода.
    qmlRegisterType<JsonHighlighter>("DSLRay", 1, 0, "JsonHighlighter");

    ProjectController project;
    DocumentController documents;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Project", &project);
    engine.rootContext()->setContextProperty("Docs", &documents);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("DSLRay", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    // Восстанавливаем прошлую сессию уже поверх готового QML.
    restoreSession(project, documents);

    return app.exec();
}
