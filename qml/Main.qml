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
        sequence: StandardKey.Save
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

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.gap
                spacing: Theme.gap

                // ── Левая колонка: ПРОЕКТ + СТРУКТУРА ─────────────
                ColumnLayout {
                    Layout.preferredWidth: Theme.sidebarLeftWidth
                    Layout.minimumWidth: Theme.sidebarLeftWidth
                    Layout.maximumWidth: Theme.sidebarLeftWidth
                    Layout.fillHeight: true
                    spacing: Theme.gap

                    FilesPanel {
                        Layout.fillWidth: true
                        Layout.preferredHeight: parent.height * Theme.filesProjectRatio
                    }
                    StructurePanel {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onObjectActivated: function (offset) { codeEditor.gotoOffset(offset) }
                    }
                }

                // ── Центр: ДОСКА над КОДОМ с ручкой между ─────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    BoardPanel {
                        Layout.fillWidth: true
                        // На шаге 1 — фиксированная доля 58%; на шаге 2
                        // высоту начнёт контролировать SplitView.
                        Layout.preferredHeight: parent.height * Theme.boardRatio
                    }

                    // Ручка сплиттера (визуальная заглушка).
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.splitterHandle
                        Rectangle {
                            anchors.centerIn: parent
                            width: 46; height: 5
                            radius: 3
                            color: "#cfd3db"
                        }
                    }

                    CodeEditor {
                        id: codeEditor
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }

                // ── Правая колонка: СВОЙСТВА ──────────────────────
                PropertiesPanel {
                    Layout.preferredWidth: Theme.sidebarRightWidth
                    Layout.minimumWidth: Theme.sidebarRightWidth
                    Layout.maximumWidth: Theme.sidebarRightWidth
                    Layout.fillHeight: true
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
