import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import DSLRay

// Панель «ПРОЕКТ» — проводник по проекту.
// Кнопки в шапке: «Открыть…» (FolderDialog), «+ файл», «+ папка».
// Дерево файлов — QFileSystemModel из ProjectController. Поддерживает
// drag-and-drop: подсветка строки для папки-цели (drop INTO),
// линия сверху строки для файла-цели (drop в его родителя).
PanelFrame {
    id: root
    title: "ПРОЕКТ"
    subtitle: Project.hasProject ? rootName() : ""

    // Папка, в которую попадут «+ файл» / «+ папка».
    // Меняется при клике по ряду; по умолчанию — корень проекта.
    property string activeFolderPath: Project.rootPath

    // Режим инлайн-создания: "" | "file" | "folder".
    property string pendingCreateMode: ""

    function rootName() {
        const p = Project.rootPath
        const sep = Math.max(p.lastIndexOf("/"), p.lastIndexOf("\\"))
        return sep >= 0 ? p.substring(sep + 1) : p
    }

    function startCreate(mode) {
        if (!Project.hasProject)
            return
        pendingCreateMode = mode
        nameField.text = (mode === "folder") ? "новая-папка" : "untitled.dsl"
        nameField.selectAll()
        nameField.forceActiveFocus()
    }

    function confirmCreate() {
        const dir = activeFolderPath || Project.rootPath
        const name = nameField.text.trim()
        if (name.length > 0) {
            if (pendingCreateMode === "folder")
                Project.createFolder(dir, name)
            else
                Project.createFile(dir, name)
        }
        pendingCreateMode = ""
    }

    headerRight: [
        HeaderBtn { label: "Открыть…"; onClicked: openDialog.open() },
        HeaderBtn { label: "+ файл";   btnEnabled: Project.hasProject; onClicked: root.startCreate("file") },
        HeaderBtn { label: "+ папка";  btnEnabled: Project.hasProject; onClicked: root.startCreate("folder") }
    ]

    component HeaderBtn: Rectangle {
        id: hb
        property string label: ""
        property bool btnEnabled: true
        signal clicked()
        implicitWidth: hbText.implicitWidth + 14
        implicitHeight: 22
        radius: Theme.rSmall
        color: hover.hovered && hb.btnEnabled ? "#f0f1f4" : "transparent"
        border.color: hb.btnEnabled ? Theme.border : Theme.borderSoft
        border.width: 1
        opacity: hb.btnEnabled ? 1.0 : 0.45
        Text {
            id: hbText
            anchors.centerIn: parent
            text: hb.label
            font.family: Theme.fontSans
            font.pixelSize: 11
            color: Theme.textMuted
        }
        HoverHandler { id: hover; enabled: hb.btnEnabled }
        TapHandler { enabled: hb.btnEnabled; onTapped: hb.clicked() }
    }

    FolderDialog {
        id: openDialog
        title: "Выберите папку проекта"
        onAccepted: Project.openProject(selectedFolder)
    }

    Connections {
        target: Project
        function onRootPathChanged() {
            root.activeFolderPath = Project.rootPath
        }
    }

    // ── Пустое состояние ──────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        visible: !Project.hasProject
        spacing: 10

        Text {
            text: "проект пока не открыт"
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontContent
            color: Theme.textGhost
            Layout.alignment: Qt.AlignHCenter
        }
        Rectangle {
            implicitWidth: emptyText.implicitWidth + 28
            implicitHeight: 30
            radius: Theme.rButton
            color: emptyHover.hovered ? Qt.darker(Theme.accent, 1.06) : Theme.accent
            Layout.alignment: Qt.AlignHCenter
            Text {
                id: emptyText
                anchors.centerIn: parent
                text: "Открыть проект"
                color: Theme.accentFg
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontContent
                font.weight: Font.DemiBold
            }
            HoverHandler { id: emptyHover }
            TapHandler { onTapped: openDialog.open() }
        }
    }

    // ── Состояние с открытым проектом ─────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        visible: Project.hasProject
        spacing: 0

        // Инлайн-поле создания файла / папки.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            visible: root.pendingCreateMode !== ""
            color: Theme.bgSubtle

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.borderSoft
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: root.pendingCreateMode === "folder" ? "📁" : "📄"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }
                TextField {
                    id: nameField
                    Layout.fillWidth: true
                    selectByMouse: true
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontContent
                    color: Theme.textPrimary
                    leftPadding: 6; rightPadding: 6
                    topPadding: 2;  bottomPadding: 2
                    background: Rectangle {
                        color: Theme.bgPanel
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.rSmall
                    }
                    Keys.onReturnPressed: root.confirmCreate()
                    Keys.onEnterPressed:  root.confirmCreate()
                    Keys.onEscapePressed: root.pendingCreateMode = ""
                }
            }
        }

        // Само дерево.
        TreeView {
            id: tree
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Project.model
            rootIndex: Project.projectRootIndex

            // Состояние drag-and-drop, разделяемое всеми делегатами.
            property string draggingPath: ""
            property int    dropRow: -1
            property string dropMode: ""  // "" | "into" | "before"

            ScrollBar.vertical: ScrollBar {}

            // У модели одна колонка, но TableView всё равно может попытаться
            // показать остальные. Принудительно даём ширину только нулевой.
            columnWidthProvider: function (col) {
                return col === 0 ? tree.width : 0
            }

            delegate: Item {
                id: rowItem

                required property TreeView treeView
                required property int  row
                required property int  column
                required property bool isTreeNode
                required property bool expanded
                required property bool hasChildren
                required property int  depth
                required property var  model

                readonly property bool   isDir:    rowItem.model.isDir === true
                readonly property string path:     rowItem.model.filePath
                readonly property string nameText: rowItem.model.display
                readonly property bool   dropping: tree.dropRow === rowItem.row

                implicitWidth: tree.width
                implicitHeight: 22
                visible: rowItem.column === 0

                // Фон: подсветка папки-цели (drop INTO) или hover.
                Rectangle {
                    anchors.fill: parent
                    color: rowItem.dropping && tree.dropMode === "into"
                           ? Qt.alpha(Theme.accent, 0.10)
                           : (rowMouse.containsMouse ? Theme.bgSubtle : "transparent")
                }

                // Линия-индикатор: drop сверху строки (в родителя этого файла).
                Rectangle {
                    visible: rowItem.dropping && tree.dropMode === "before"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 2
                    color: Theme.accent
                    z: 2
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 4 + rowItem.depth * 14
                    spacing: 4

                    Item {
                        width: 12
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            visible: rowItem.hasChildren
                            text: rowItem.expanded ? "▾" : "▸"  // ▾ ▸
                            font.pixelSize: 10
                            color: Theme.textMuted
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowItem.isDir ? "📁" : "📄"  // 📁 📄
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowItem.nameText
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontContent
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }
                }

                // Невидимый таргет для Drag — двигается под курсором, носит Drag.active.
                Item {
                    id: dragGhost
                    width: 1; height: 1; visible: false
                    Drag.active: rowMouse.drag.active
                    Drag.source: rowItem
                    Drag.hotSpot.x: 0
                    Drag.hotSpot.y: 0
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    drag.target: dragGhost
                    drag.threshold: 5

                    onClicked: function (mouse) {
                        // Клик в зону шеврона — раскрыть/свернуть; иначе — выбрать.
                        const chevronEnd = 4 + rowItem.depth * 14 + 12
                        if (rowItem.hasChildren && mouse.x < chevronEnd) {
                            if (rowItem.expanded) tree.collapse(rowItem.row)
                            else                  tree.expand(rowItem.row)
                            return
                        }
                        root.activeFolderPath = rowItem.isDir
                            ? rowItem.path
                            : Project.parentDir(rowItem.path)
                    }
                    onDoubleClicked: {
                        if (rowItem.hasChildren) {
                            if (rowItem.expanded) tree.collapse(rowItem.row)
                            else                  tree.expand(rowItem.row)
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: function (drag) {
                        const src = drag.source
                        if (!src || !src.path || src.path === rowItem.path) {
                            tree.dropRow = -1
                            return
                        }
                        tree.dropRow  = rowItem.row
                        tree.dropMode = rowItem.isDir ? "into" : "before"
                    }
                    onExited: {
                        if (tree.dropRow === rowItem.row) {
                            tree.dropRow  = -1
                            tree.dropMode = ""
                        }
                    }
                    onDropped: function (drop) {
                        const src = drop.source
                        const sourcePath = (src && src.path) ? src.path : ""
                        const targetDir  = rowItem.isDir
                            ? rowItem.path
                            : Project.parentDir(rowItem.path)
                        tree.dropRow  = -1
                        tree.dropMode = ""
                        if (sourcePath && targetDir)
                            Project.moveItem(sourcePath, targetDir)
                    }
                }
            }

            // Drop в пустую область под деревом — переносим в корень проекта.
            DropArea {
                anchors.fill: parent
                z: -1
                onDropped: function (drop) {
                    const src = drop.source
                    const sourcePath = (src && src.path) ? src.path : ""
                    if (sourcePath && Project.rootPath)
                        Project.moveItem(sourcePath, Project.rootPath)
                }
            }
        }
    }
}
