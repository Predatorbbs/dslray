import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DSLRay

// Корневое окно DSLRay. Раскладка:
//
//   ┌── Toolbar ─────────────────────────────────────────────┐
//   ├── FileTabs ────────────────────────────────────────────┤
//   ├─ Sidebar ─┬──────── Center ─────────┬── Properties ───┤
//   │  Files    │   Board (58%)           │                  │
//   │  ─────    │   ─── handle ───        │                  │
//   │  Struct.  │   Code  (42%)           │                  │
//   ├───────────┴─────────────────────────┴──────────────────┤
//   └── StatusBar ───────────────────────────────────────────┘
//
// Сплиттер «доска / код» на этом шаге статичный (58%/42%) —
// перетаскивание и сохранение позиции в QSettings прикручиваем на шаге 2.
ApplicationWindow {
    id: window
    visible: true

    width: 1400
    height: 900
    minimumWidth: 1100
    minimumHeight: 700
    title: "DSLRay"

    color: Theme.bgApp

    // Шрифт по умолчанию — Segoe UI на Windows.
    font.family: Theme.fontSans
    font.pixelSize: Theme.fontContent

    // Открыто ли всплывающее меню приложения (попап поверх всего окна).
    property bool menuOpen: false

    // Ctrl+S — сохранить активный документ (в «Безопасном режиме» пишет
    // черновик в оригинал и удаляет его). Видимая кнопка появится позже.
    Shortcut {
        sequences: [ StandardKey.Save ]
        onActivated: Docs.saveActive()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Тулбар ─────────────────────────────────────────────────
        Toolbar {
            Layout.fillWidth: true
            menuActive: window.menuOpen
            onMenuClicked: window.menuOpen = !window.menuOpen
        }

        // ── Полоса вкладок ────────────────────────────────────────
        FileTabs {
            Layout.fillWidth: true
        }

        // ── Рабочая область (3 колонки) ───────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bgWorkspace

            // Горизонтальный сплиттер: левая колонка ⟷ центр+свойства.
            SplitView {
                anchors.fill: parent
                anchors.margins: Theme.gap
                orientation: Qt.Horizontal

                // Вертикальная ручка между колонками.
                handle: Rectangle {
                    id: vHandle
                    implicitWidth: Theme.gap
                    color: "transparent"
                    Rectangle {
                        anchors.centerIn: parent
                        width: 5; height: 46; radius: 3
                        color: vHandle.SplitHandle.pressed ? Theme.accent
                             : (vHandle.SplitHandle.hovered ? "#b9bec9" : "#cfd3db")
                    }
                    HoverHandler { cursorShape: Qt.SplitHCursor }
                }

                // ── Левая колонка: ПРОЕКТ + СТРУКТУРА (160…550px) ──
                Item {
                    SplitView.preferredWidth: Theme.sidebarLeftWidth
                    SplitView.minimumWidth: 160
                    SplitView.maximumWidth: 550

                    FilesPanel {
                        id: filesPanel
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Math.round((parent.height - Theme.gap) * Theme.filesProjectRatio)
                    }
                    StructurePanel {
                        anchors.top: filesPanel.bottom
                        anchors.topMargin: Theme.gap
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        codeTopOffset: codeEditor.topOffset
                        onObjectActivated: function (offset) { codeEditor.gotoOffset(offset) }
                    }
                }

                // ── Центр + Свойства ──────────────────────────────
                RowLayout {
                    SplitView.fillWidth: true
                    spacing: Theme.gap

                    // Вертикальный сплиттер: ДОСКА над КОДОМ (мин. 100px каждая).
                    SplitView {
                        orientation: Qt.Vertical
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        handle: Rectangle {
                            id: hHandle
                            implicitHeight: Theme.splitterHandle
                            color: "transparent"
                            Rectangle {
                                anchors.centerIn: parent
                                width: 46; height: 5; radius: 3
                                color: hHandle.SplitHandle.pressed ? Theme.accent
                                     : (hHandle.SplitHandle.hovered ? "#b9bec9" : "#cfd3db")
                            }
                            HoverHandler { cursorShape: Qt.SplitVCursor }
                        }

                        BoardPanel {
                            SplitView.preferredHeight: 380
                            SplitView.minimumHeight: 100
                        }
                        CodeEditor {
                            id: codeEditor
                            SplitView.fillHeight: true
                            SplitView.minimumHeight: 100
                        }
                    }

                    // ── Правая колонка: СВОЙСТВА ──────────────────
                    PropertiesPanel {
                        Layout.preferredWidth: Theme.sidebarRightWidth
                        Layout.minimumWidth: Theme.sidebarRightWidth
                        Layout.maximumWidth: Theme.sidebarRightWidth
                        Layout.fillHeight: true
                    }
                }
            }
        }

        // ── Статус-бар ────────────────────────────────────────────
        StatusBar {
            Layout.fillWidth: true
        }
    }

    // ── Всплывающее меню приложения ───────────────────────────────────
    // Лежит поверх всей раскладки: затемняет окно и показывает попап.
    MenuOverlay {
        open: window.menuOpen
        onCloseRequested: window.menuOpen = false
    }
}
