#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "projectcontroller.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QGuiApplication::setApplicationName("DSLRay");
    QGuiApplication::setApplicationDisplayName("DSLRay");
    QGuiApplication::setOrganizationName("DSLRay");
    QGuiApplication::setOrganizationDomain("dslray.local");
    QGuiApplication::setApplicationVersion("0.1.0");

    // Базовый стиль Controls — рисуем UI сами, лишний нативный стиль ни к чему.
    QQuickStyle::setStyle("Basic");

    ProjectController project;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Project", &project);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("DSLRay", "Main");

    return app.exec();
}
