#include <QDir>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSettings>
#include <QTemporaryDir>
#include <memory>
#include <QStringList>
#include <QUrl>
#include <QtQml>

#include "documentcontroller.h"
#include "editorpreferences.h"
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

    // Packaging check: load the real UI without showing it or touching user state.
    const bool checkDeployment = app.arguments().contains(QStringLiteral("--check-deployment"));
    std::unique_ptr<QTemporaryDir> checkSettings;
    if (checkDeployment) {
        checkSettings = std::make_unique<QTemporaryDir>();
        if (!checkSettings->isValid())
            return 1;
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, checkSettings->path());
        QSettings::setPath(QSettings::IniFormat, QSettings::SystemScope, checkSettings->path());
    }

    // Иконка окна / панели задач из встроенных ресурсов (см. dslray_icons.qrc).
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/icons/dslray_icon.png")));

    // Базовый стиль Controls — рисуем UI сами, лишний нативный стиль ни к чему.
    QQuickStyle::setStyle("Basic");

    // JSON-подсветка для редактора кода.
    qmlRegisterType<JsonHighlighter>("DSLRay", 1, 0, "JsonHighlighter");

    ProjectController project;
    DocumentController documents;
    EditorPreferences preferences;
    QObject::connect(&project, &ProjectController::fileOperationRequested,
                     &documents, &DocumentController::flushRequested);

    bool deploymentWarnings = false;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Project", &project);
    engine.rootContext()->setContextProperty("Docs", &documents);
    engine.rootContext()->setContextProperty("Preferences", &preferences);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    if (checkDeployment) {
        engine.setInitialProperties({{QStringLiteral("visible"), false}});
        QObject::connect(&engine, &QQmlEngine::warnings, &engine,
                         [&deploymentWarnings](const QList<QQmlError> &) { deploymentWarnings = true; });
    }
    engine.loadFromModule("DSLRay", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    if (checkDeployment)
        return deploymentWarnings ? 1 : 0;

    // Восстанавливаем прошлую сессию уже поверх готового QML.
    restoreSession(project, documents);

    return app.exec();
}
