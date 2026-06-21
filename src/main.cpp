#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QGuiApplication::setApplicationName("DSLRAY");
    QGuiApplication::setApplicationDisplayName("DSLRAY");
    QGuiApplication::setOrganizationName("DSLRay");
    QGuiApplication::setOrganizationDomain("dslray.local");
    QGuiApplication::setApplicationVersion("0.1.0");

    // Базовый стиль Controls — рисуем UI сами, лишний нативный стиль ни к чему.
    QQuickStyle::setStyle("Basic");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("DSLRAY", "Main");

    return app.exec();
}
