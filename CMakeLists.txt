cmake_minimum_required(VERSION 3.21)

project(DSLRay
    VERSION 0.1.0
    DESCRIPTION "DSLRay — desktop IDE for the DSL UI language"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Qt 6.7+ нужен ради topLeftRadius / topRightRadius на Rectangle.
find_package(Qt6 6.7 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
)

qt_standard_project_setup(REQUIRES 6.7)

qt_add_executable(appDSLRay
    src/main.cpp
)

# Theme.qml — синглтон. Свойство нужно установить ДО qt_add_qml_module.
set_source_files_properties(qml/theme/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(appDSLRay
    URI DSLRay
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/theme/Theme.qml
        qml/components/Toolbar.qml
        qml/components/FileTabs.qml
        qml/components/StatusBar.qml
        qml/components/PanelFrame.qml
        qml/components/FilesPanel.qml
        qml/components/StructurePanel.qml
        qml/components/BoardPanel.qml
        qml/components/CodeEditor.qml
        qml/components/PropertiesPanel.qml
)

target_link_libraries(appDSLRay PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

# Под Windows прячем консольное окно у release-сборки.
set_target_properties(appDSLRay PROPERTIES
    WIN32_EXECUTABLE ON
    MACOSX_BUNDLE OFF
)

include(GNUInstallDirs)
install(TARGETS appDSLRay
    BUNDLE  DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
