// Add after QApplication app(argc, argv);
#include <QApplication>
#include <QIcon>

// Runtime window/taskbar icon from Qt resources:
app.setWindowIcon(QIcon(":/icons/dslray_icon.png"));

// If you create a QMainWindow / QWidget manually, you can also set:
window.setWindowIcon(QIcon(":/icons/dslray_icon.png"));
