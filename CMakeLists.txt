cmake_minimum_required(VERSION 3.21)

project(DSLRay
    VERSION 0.3.0
    DESCRIPTION "DSLRay — desktop IDE for the DSL UI language"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
# AUTORCC — чтобы .qrc с иконками (resources/dslray_icons.qrc, с алиасами) компилировался
# в ресурсы как есть, сохраняя путь :/icons/dslray_icon.png.
set(CMAKE_AUTORCC ON)

# Qt 6.7+ нужен ради topLeftRadius / topRightRadius на Rectangle.
find_package(Qt6 6.7 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    QuickDialogs2
)

qt_standard_project_setup(REQUIRES 6.7)

qt_add_executable(appDSLRay
    MANUAL_FINALIZATION
    src/main.cpp
    src/projectcontroller.h
    src/projectcontroller.cpp
    src/projecttreemodel.h
    src/projecttreemodel.cpp
    src/editorpreferences.h
    src/editorpreferences.cpp
    src/documentcontroller.h
    src/documentcontroller.cpp
    src/jsonhighlighter.h
    src/jsonhighlighter.cpp
    # Иконки приложения (runtime-ресурс :/icons/...). Алиасы — внутри .qrc.
    resources/dslray_icons.qrc
)

# Иконка исполняемого файла под Windows (taskbar / Проводник).
if (WIN32)
    target_sources(appDSLRay PRIVATE platform/windows/dslray.rc)
endif()

# Theme.qml — синглтон. Свойство нужно установить ДО qt_add_qml_module.
set_source_files_properties(qml/theme/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

set(dslray_qml_files
        qml/Main.qml
        qml/theme/Theme.qml
        qml/components/Toolbar.qml
        qml/components/MenuOverlay.qml
        qml/components/MenuProfilePage.qml
        qml/components/MenuEditorPage.qml
        qml/components/MenuAppearancePage.qml
        qml/components/MenuAboutPage.qml
        qml/components/MenuButton.qml
        qml/components/FileTabs.qml
        qml/components/StatusBar.qml
        qml/components/PanelFrame.qml
        qml/components/FilesPanel.qml
        qml/components/StructurePanel.qml
        qml/components/BoardPanel.qml
        qml/components/CodeEditor.qml
        qml/components/EditorText.js
        qml/components/PropertiesPanel.qml
)

qt_add_qml_module(appDSLRay
    URI DSLRay
    VERSION 1.0
    QML_FILES ${dslray_qml_files}
)

target_link_libraries(appDSLRay PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::QuickDialogs2
)

# Под Windows прячем консольное окно у release-сборки.
# OUTPUT_NAME фиксируем явно — иначе Qt Creator на новом Qt с установленным
# Qt ApplicationManager иногда подсовывает в Run-конфиг фантомный
# appman-controller вместо нашего бинаря.
set_target_properties(appDSLRay PROPERTIES
    WIN32_EXECUTABLE ON
    MACOSX_BUNDLE OFF
    OUTPUT_NAME appDSLRay
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

# Явная финализация Qt-таргета — помогает Qt Creator однозначно
# определить наш appDSLRay как primary executable проекта.
qt_finalize_target(appDSLRay)

include(GNUInstallDirs)
install(TARGETS appDSLRay
    BUNDLE  DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Keep the developer build intact; "portable" creates a separate runnable package.
if(WIN32)
    add_executable(dslray_launcher WIN32 EXCLUDE_FROM_ALL
        platform/windows/launcher.cpp platform/windows/dslray.rc)
    set_target_properties(dslray_launcher PROPERTIES
        AUTOMOC OFF AUTOUIC OFF AUTORCC OFF
        OUTPUT_NAME appDSLRay
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/launcher")
    if(MINGW)
        target_link_options(dslray_launcher PRIVATE -municode -static)
    elseif(MSVC)
        set_property(TARGET dslray_launcher PROPERTY
            MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    endif()
    find_program(DSLRAY_POWERSHELL NAMES powershell pwsh REQUIRED)
    get_filename_component(dslray_compiler_bin "${CMAKE_CXX_COMPILER}" DIRECTORY)
    add_custom_target(portable
        COMMAND "${DSLRAY_POWERSHELL}" -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_SOURCE_DIR}/cmake/PackageWindows.ps1"
            -AppExe "$<TARGET_FILE:appDSLRay>"
            -LauncherExe "$<TARGET_FILE:dslray_launcher>"
            -DeployTool "$<TARGET_FILE_DIR:Qt6::Core>/windeployqt.exe"
            -CompilerBin "${dslray_compiler_bin}"
            -SourceDir "${CMAKE_SOURCE_DIR}"
            -LogDirectory "${CMAKE_BINARY_DIR}/package-logs"
            -Configuration "$<CONFIG>"
        DEPENDS appDSLRay dslray_launcher
        USES_TERMINAL VERBATIM)
endif()
include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    function(dslray_add_test name)
        qt_add_executable(${name} ${ARGN})
        set_target_properties(${name} PROPERTIES WIN32_EXECUTABLE OFF MACOSX_BUNDLE OFF)
        target_include_directories(${name} PRIVATE src)
        target_link_libraries(${name} PRIVATE Qt6::Core Qt6::Gui Qt6::Test)
        add_test(NAME ${name} COMMAND ${name})
    endfunction()

    dslray_add_test(documentcontroller_test
        tests/documentcontroller_test.cpp src/documentcontroller.cpp src/documentcontroller.h)
    dslray_add_test(editorpreferences_test
        tests/editorpreferences_test.cpp src/editorpreferences.cpp src/editorpreferences.h)
    dslray_add_test(projecttreemodel_test
        tests/projecttreemodel_test.cpp src/projecttreemodel.cpp src/projecttreemodel.h)
    dslray_add_test(editortext_test tests/editortext_test.cpp tests/editortext_test.h)
    target_link_libraries(editortext_test PRIVATE Qt6::Qml)
    target_compile_definitions(editortext_test PRIVATE
        EDITOR_TEXT_SOURCE_PATH="${CMAKE_CURRENT_SOURCE_DIR}/qml/components/EditorText.js")


    dslray_add_test(jsonhighlighter_test
        tests/jsonhighlighter_test.cpp src/jsonhighlighter.cpp src/jsonhighlighter.h)
    target_link_libraries(jsonhighlighter_test PRIVATE Qt6::Quick Qt6::Qml)
    set_tests_properties(jsonhighlighter_test PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

    dslray_add_test(qmlintegration_test
        tests/qmlintegration_test.cpp
        src/documentcontroller.cpp src/documentcontroller.h
        src/editorpreferences.cpp src/editorpreferences.h
        src/projectcontroller.cpp src/projectcontroller.h
        src/projecttreemodel.cpp src/projecttreemodel.h
        src/jsonhighlighter.cpp src/jsonhighlighter.h
        resources/dslray_icons.qrc)
    target_link_libraries(qmlintegration_test PRIVATE
        Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::QuickDialogs2)
    qt_add_resources(qmlintegration_test test_qml
        PREFIX "/qt/qml/DSLRay" BASE "${CMAKE_CURRENT_SOURCE_DIR}"
        FILES ${dslray_qml_files})
    qt_add_resources(qmlintegration_test test_qmldir
        PREFIX "/qt/qml/DSLRay" BASE "${CMAKE_CURRENT_BINARY_DIR}/DSLRay"
        FILES "${CMAKE_CURRENT_BINARY_DIR}/DSLRay/qmldir")
    add_dependencies(qmlintegration_test appDSLRay)
endif()