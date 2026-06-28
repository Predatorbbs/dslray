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

    // Тема оформления приходит из настроек (Docs.themeId) — выставляем синглтону.
    Binding { target: Theme; property: "id"; value: Docs.themeId }

    // Шрифт по умолчанию — Segoe UI на Windows.
    font.family: Theme.fontSans
    font.pixelSize: Theme.fontContent

    // Открыто ли всплывающее меню приложения (попап поверх всего окна).
    property bool menuOpen: false

    // Состояние диалога подтверждения удаления.
    property bool   deleteDialogOpen: false
    property string pendingDeletePath: ""
    property bool   pendingDeleteIsDir: false
    property string pendingDeleteName: ""
    property bool   dontAskAgain: false

    function requestDelete(path, isDir, name) {
        if (!Project.confirmDelete) {
            window.performDelete(path)
            return
        }
        pendingDeletePath = path
        pendingDeleteIsDir = isDir
        pendingDeleteName = name
        dontAskAgain = false
        deleteDialogOpen = true
    }
    function performDelete(path) {
        if (Project.deleteItem(path))
            Docs.closePath(path)   // закрыть вкладку удалённого файла, если открыта
    }

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
                        onDeleteRequested: function (path, isDir, name) {
                            window.requestDelete(path, isDir, name)
                        }
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
            fileName:   Docs.hasDocuments ? Docs.activeName : ""
            lineCount:  codeEditor.liveLines
            charCount:  codeEditor.liveChars
            tokenCount: codeEditor.liveTokens
        }
    }

    // ── Всплывающее меню приложения ───────────────────────────────────
    // Лежит поверх всей раскладки: затемняет окно и показывает попап.
    MenuOverlay {
        open: window.menuOpen
        onCloseRequested: window.menuOpen = false
    }

    // ── Диалог подтверждения удаления ─────────────────────────────────
    Item {
        id: deleteOverlay
        anchors.fill: parent
        visible: opacity > 0
        opacity: window.deleteDialogOpen ? 1 : 0
        z: 2000
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; enabled: window.deleteDialogOpen }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.42 }

        Rectangle {
            anchors.centerIn: parent
            width: 440
            implicitHeight: dlgCol.implicitHeight + 40
            radius: Theme.rCard
            color: Theme.bgPanel
            border.color: Theme.border
            border.width: 1
            scale: window.deleteDialogOpen ? 1 : 0.97
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: dlgCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 14

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: window.pendingDeleteIsDir
                          ? "Вы точно хотите удалить папку со всем содержимым?"
                          : "Вы точно хотите удалить файл?"
                    font.family: Theme.fontSans
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: window.pendingDeleteName
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontContent
                    color: Theme.textMuted
                }

                // «Больше не спрашивать».
                Row {
                    Layout.topMargin: 2
                    spacing: 8
                    Rectangle {
                        width: 17; height: 17; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: window.dontAskAgain ? Theme.accent : Theme.bgPanel
                        border.color: window.dontAskAgain ? Theme.accent : Theme.border
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            visible: window.dontAskAgain
                            text: "✓"; font.pixelSize: 11; color: Theme.accentFg
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Больше не спрашивать"
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontContent
                        color: Theme.textMuted
                    }
                    TapHandler { onTapped: window.dontAskAgain = !window.dontAskAgain }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    DeleteBtn {
                        label: "Нет"
                        onClicked: window.deleteDialogOpen = false
                    }
                    DeleteBtn {
                        label: "Да"
                        danger: true
                        onClicked: {
                            if (window.dontAskAgain)
                                Project.confirmDelete = false
                            window.performDelete(window.pendingDeletePath)
                            window.deleteDialogOpen = false
                        }
                    }
                }
            }
        }

        Keys.onEscapePressed: window.deleteDialogOpen = false
        focus: window.deleteDialogOpen
    }

    component DeleteBtn: Rectangle {
        id: db
        property string label: ""
        property bool danger: false
        signal clicked()
        implicitWidth: dbText.implicitWidth + 30
        implicitHeight: 32
        radius: Theme.rButton
        color: db.danger ? (dbHover.hovered ? Qt.darker(Theme.err, 1.06) : Theme.err)
                         : (dbHover.hovered ? "#f4f5f8" : Theme.bgPanel)
        border.color: db.danger ? Theme.err : Theme.border
        border.width: 1
        Text {
            id: dbText
            anchors.centerIn: parent
            text: db.label
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontToolbar
            font.weight: Font.DemiBold
            color: db.danger ? Theme.accentFg : Theme.textPrimary
        }
        HoverHandler { id: dbHover }
        TapHandler { onTapped: db.clicked() }
    }
}
