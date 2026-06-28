import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Shapes
import DSLRay

// Панель «ПРОЕКТ» — файловое дерево по design-хэндоффу
// (design_handoff_file_tree): двухтоновые SVG-иконки папок, документы с цветом
// по типу, шевроны с поворотом, направляющие отступов, ховер/выделение/drop.
// Дерево — QFileSystemModel из ProjectController; поддержка открытия по клику,
// инлайн-создания/переименования и drag-and-drop перемещения.
PanelFrame {
    id: root
    title: "ПРОЕКТ"
    subtitle: Project.hasProject ? rootName() : ""

    property string activeFolderPath: Project.rootPath
    property string pendingCreateMode: "" // "" | "file" | "folder"

    function rootName() {
        const p = Project.rootPath
        const sep = Math.max(p.lastIndexOf("/"), p.lastIndexOf("\\"))
        return sep >= 0 ? p.substring(sep + 1) : p
    }

    function startCreate(mode) {
        if (!Project.hasProject)
            return
        pendingCreateMode = mode
        nameField.text = (mode === "folder") ? "новая-папка" : "untitled.json"
        if (mode === "file") {
            const dot = nameField.text.lastIndexOf(".")
            if (dot > 0) nameField.select(0, dot)
            else         nameField.selectAll()
        } else {
            nameField.selectAll()
        }
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
        HeaderSvgBtn { kind: "open";      tip: "Открыть"; onClicked: openDialog.open() },
        HeaderSvgBtn { kind: "newFile";   tip: "Создать файл";
                       btnEnabled: Project.hasProject; onClicked: root.startCreate("file") },
        HeaderSvgBtn { kind: "newFolder"; tip: "Создать каталог";
                       btnEnabled: Project.hasProject; onClicked: root.startCreate("folder") }
    ]

    // ── Кнопка шапки 26×26 с SVG-иконкой 15×15 ────────────────────────
    component HeaderSvgBtn: Rectangle {
        id: hb
        property string kind: ""   // "open" | "newFile" | "newFolder"
        property string tip: ""
        property bool   btnEnabled: true
        signal clicked()

        implicitWidth: 26
        implicitHeight: 26
        radius: 6
        color: hbHover.hovered && hb.btnEnabled ? "#f0f1f4" : "#ffffff"
        border.color: hb.btnEnabled ? "#e6e8ed" : Theme.borderSoft
        border.width: 1
        opacity: hb.btnEnabled ? 1.0 : 0.45

        Shape {
            anchors.centerIn: parent
            width: 15; height: 15
            antialiasing: true
            // Силуэт: документ для newFile, иначе папка.
            ShapePath {
                fillColor: "#9aa0ad"; strokeWidth: 0
                PathSvg {
                    path: hb.kind === "newFile"
                        ? "M4.1 1.8h4.0L12 5.6v7.6c0 .44-.36.8-.8.8H4.1c-.44 0-.8-.36-.8-.8V2.6c0-.44.36-.8.8-.8z"
                        : "M1.6 4.4c0-.62.5-1.12 1.12-1.12h2.4c.3 0 .58.12.78.35l.6.7c.2.23.48.35.78.35h4.6c.62 0 1.12.5 1.12 1.12v4.45c0 .62-.5 1.12-1.12 1.12H2.72c-.62 0-1.12-.5-1.12-1.12z"
                }
            }
            // Плюс (только для кнопок «создать»).
            ShapePath {
                strokeColor: "#ffffff"; strokeWidth: 1.25; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: hb.kind === "newFile" ? "M8 8.0v2.9"
                              : hb.kind === "newFolder" ? "M8 7.1v2.9" : "" }
            }
            ShapePath {
                strokeColor: "#ffffff"; strokeWidth: 1.25; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: hb.kind === "newFile" ? "M6.55 9.45h2.9"
                              : hb.kind === "newFolder" ? "M6.55 8.55h2.9" : "" }
            }
        }
        HoverHandler { id: hbHover; enabled: hb.btnEnabled }
        TapHandler { enabled: hb.btnEnabled; onTapped: hb.clicked() }
        ToolTip.visible: hbHover.hovered && hb.tip.length > 0
        ToolTip.text: hb.tip
        ToolTip.delay: 400
    }

    // ── Иконки дерева (геометрия SVG из хэндоффа, viewBox 16) ──────────
    component ChevronGlyph: Shape {
        id: chev
        property color tone: "#aab0bd"
        property bool open: false
        width: 13; height: 13
        antialiasing: true
        transform: Rotation {
            origin.x: 6.5; origin.y: 6.5
            angle: chev.open ? 90 : 0
            Behavior on angle { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
        ShapePath {
            strokeColor: chev.tone; strokeWidth: 1.7; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M6.5 4.4L10 8l-3.5 3.6" }
        }
    }

    component FolderGlyph: Shape {
        id: fg
        property color base: "#8893a8"
        property bool open: false
        width: 16; height: 16
        antialiasing: true
        ShapePath {
            fillColor: fg.base; strokeWidth: 0
            PathSvg { path: "M1.5 4.35c0-.62.5-1.12 1.12-1.12h2.46c.32 0 .62.13.82.37l.63.74c.2.24.5.37.82.37h4.81c.62 0 1.12.5 1.12 1.12v5.34c0 .62-.5 1.12-1.12 1.12H2.62c-.62 0-1.12-.5-1.12-1.12z" }
        }
        ShapePath {
            // Светлый передний план = base 60% + white 40%.
            fillColor: Qt.rgba(fg.base.r * 0.6 + 0.4, fg.base.g * 0.6 + 0.4, fg.base.b * 0.6 + 0.4, 1)
            strokeWidth: 0
            PathSvg {
                path: fg.open
                    ? "M1.5 6.7h13l-.92 4.0c-.12.5-.57.86-1.09.86H2.62c-.62 0-1.12-.5-1.12-1.12z"
                    : "M1.5 6.05h13v4.5c0 .62-.5 1.12-1.12 1.12H2.62c-.62 0-1.12-.5-1.12-1.12z"
            }
        }
    }

    component FileGlyph: Shape {
        id: flg
        property color tint: "#8893a8"
        width: 16; height: 16
        antialiasing: true
        ShapePath {
            fillColor: flg.tint; strokeWidth: 0
            PathSvg { path: "M4.1 1.8h4.0L12 5.6v7.6c0 .44-.36.8-.8.8H4.1c-.44 0-.8-.36-.8-.8V2.6c0-.44.36-.8.8-.8z" }
        }
        ShapePath {
            fillColor: Qt.rgba(1, 1, 1, 0.42); strokeWidth: 0
            PathSvg { path: "M8.0 1.85v3.0c0 .42.34.76.76.76h3.07z" }
        }
    }

    FolderDialog {
        id: openDialog
        title: "Выберите папку проекта"
        onAccepted: Project.openProject(selectedFolder)
    }

    Connections {
        target: Project
        function onRootPathChanged() { root.activeFolderPath = Project.rootPath }
    }

    // Переключение/открытие вкладки — подсветить её файл в дереве, развернув
    // схлопнутые папки до него. Реагируем на смену активной вкладки (а не на
    // правки контента — те шлют только activeChanged).
    Connections {
        target: Docs
        function onActiveIndexChanged() { root.revealActiveFile() }
    }

    function revealActiveFile() {
        if (!Project.hasProject)
            return
        const p = Docs.activePath
        if (!p)
            return
        const idx = Project.indexForPath(p)
        if (idx.row < 0)
            return // файл не в дереве проекта
        tree.expandToIndex(idx)
        tree.selectedPath = p
        root.activeFolderPath = Project.parentDir(p)
        Qt.callLater(function () { tree.positionViewAtIndex(idx, TableView.Contain) })
    }

    // ── Пустое состояние ──────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        visible: !Project.hasProject
        spacing: 10

        Text {
            text: "Откройте каталог проекта"
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
                text: "Открыть"
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
                anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1; color: Theme.borderSoft
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 6

                FolderGlyph { visible: root.pendingCreateMode === "folder"; Layout.alignment: Qt.AlignVCenter }
                FileGlyph   { visible: root.pendingCreateMode === "file";   tint: tree.fileTint("x.json"); Layout.alignment: Qt.AlignVCenter }

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

        // ── Дерево ────────────────────────────────────────────────────
        TreeView {
            id: tree
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Project.model
            rootIndex: Project.projectRootIndex

            // Токены дизайна (design_handoff_file_tree).
            readonly property color accent:          "#4b5bd6"
            readonly property color accSoft:         "#eef1fe"
            readonly property color accRing:         Qt.rgba(75/255, 91/255, 214/255, 0.16)
            readonly property color rowText:         "#39404e"
            readonly property color chevronInactive: "#aab0bd"
            readonly property color hoverBg:         "#f3f4f8"
            readonly property color guideColor:      "#e8eaef"
            readonly property color folderBase:      "#8893a8"

            // Выделение / переименование / drop.
            property string selectedPath: ""
            property string renamingPath: ""
            property int    dropRow: -1
            property bool   dropValid: false
            function clearDrop() { dropRow = -1; dropValid = false }

            function fileTint(name) {
                const i = name.lastIndexOf(".")
                const ext = i >= 0 ? name.substring(i + 1).toLowerCase() : ""
                switch (ext) {
                case "json": return "#d68a1c"
                case "dsl":  return "#4b5bd6"
                case "js":   return "#caa321"
                case "ts":   return "#2f74c0"
                case "md":   return "#52916b"
                case "css":  return "#3aa0c4"
                case "html": return "#d9682f"
                case "yml":
                case "yaml": return "#8a6fb0"
                case "png":  return "#7a8aa8"
                case "svg":  return "#cf7bb0"
                default:     return "#8893a8"
                }
            }

            ScrollBar.vertical: ScrollBar {}

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_F2 && tree.selectedPath.length > 0) {
                    tree.renamingPath = tree.selectedPath
                    event.accepted = true
                }
            }

            columnWidthProvider: function (col) { return col === 0 ? tree.width : 0 }

            delegate: Item {
                id: node

                required property int  row
                required property int  column
                required property bool expanded
                required property bool hasChildren
                required property int  depth
                required property var  model

                readonly property bool   isDir:    node.model.isDir === true
                readonly property string path:     node.model.filePath
                readonly property string nameText: node.model.display
                readonly property bool   selected: tree.selectedPath === node.path
                readonly property bool   renaming: tree.renamingPath === node.path
                readonly property bool   dropTarget: tree.dropRow === node.row && tree.dropValid

                implicitWidth: tree.width
                implicitHeight: 25
                visible: node.column === 0

                function commitRename() {
                    const oldPath = node.path
                    const np = Project.renameItem(oldPath, renameField.text)
                    tree.renamingPath = ""
                    if (np && np.length > 0) {
                        Docs.handlePathRenamed(oldPath, np)
                        tree.selectedPath = np
                    }
                }

                // Фон строки: drop > selected > hover.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 6
                    radius: 6
                    color: node.dropTarget ? tree.accRing
                         : node.selected   ? tree.accSoft
                         : (rowMouse.containsMouse ? tree.hoverBg : "transparent")
                    border.width: node.dropTarget ? 1 : 0
                    border.color: tree.accent
                }

                // Левая акцент-полоса у выделенной строки.
                Rectangle {
                    visible: node.selected && !node.dropTarget
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2.5
                    color: tree.accent
                }

                // Направляющие отступов (у выделенной — нет).
                Repeater {
                    model: node.selected ? 0 : node.depth
                    delegate: Rectangle {
                        required property int index
                        width: 1
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        x: 14.5 + index * 15
                        color: tree.guideColor
                    }
                }

                // Содержимое строки.
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 8 + node.depth * 15

                    Item {
                        id: discloseSlot
                        width: 13; height: 13
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        ChevronGlyph {
                            anchors.centerIn: parent
                            visible: node.hasChildren
                            open: node.expanded
                            tone: node.selected ? tree.accent : tree.chevronInactive
                        }
                    }

                    Item {
                        id: iconSlot
                        width: 16; height: 16
                        anchors.left: discloseSlot.right
                        anchors.leftMargin: 6.5
                        anchors.verticalCenter: parent.verticalCenter
                        FolderGlyph {
                            visible: node.isDir
                            anchors.centerIn: parent
                            open: node.expanded
                            base: node.selected ? tree.accent : tree.folderBase
                        }
                        FileGlyph {
                            visible: !node.isDir
                            anchors.centerIn: parent
                            tint: node.selected ? tree.accent : tree.fileTint(node.nameText)
                        }
                    }

                    Text {
                        visible: !node.renaming
                        anchors.left: iconSlot.right
                        anchors.leftMargin: 6.5
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: node.nameText
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                        font.letterSpacing: -0.05
                        font.weight: node.selected ? Font.DemiBold : Font.Medium
                        color: node.selected ? tree.accent : tree.rowText
                        elide: Text.ElideRight
                    }
                }

                // Поле инлайн-переименования (поверх имени).
                TextField {
                    id: renameField
                    visible: node.renaming
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8 + node.depth * 15 + 42
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    height: 21
                    selectByMouse: true
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontContent
                    color: Theme.textPrimary
                    leftPadding: 5; rightPadding: 5
                    topPadding: 0;  bottomPadding: 0
                    background: Rectangle {
                        color: Theme.bgPanel
                        border.color: tree.accent
                        border.width: 1
                        radius: Theme.rSmall
                    }
                    onVisibleChanged: {
                        if (visible) {
                            text = node.nameText
                            const dot = text.lastIndexOf(".")
                            if (!node.isDir && dot > 0) select(0, dot)
                            else                        selectAll()
                            forceActiveFocus()
                        }
                    }
                    onAccepted: node.commitRename()
                    Keys.onEscapePressed: tree.renamingPath = ""
                    onActiveFocusChanged: { if (!activeFocus && node.renaming) node.commitRename() }
                }

                // Drag-таргет 1×1, привязанный прямо к позиции курсора внутри
                // строки → точка попадания DropArea ровно под указателем
                // (нет смещения на соседнюю строку).
                Item {
                    id: dragProxy
                    width: 1; height: 1
                    x: rowMouse.mouseX
                    y: rowMouse.mouseY
                    Drag.active: rowMouse.dragActive
                    Drag.source: node
                    Drag.hotSpot.x: 0
                    Drag.hotSpot.y: 0

                    // «Призрак» — плашка с именем перетаскиваемого файла у курсора.
                    Rectangle {
                        visible: rowMouse.dragActive
                        x: 15; y: 6
                        width: ghostText.implicitWidth + 26
                        height: 24
                        radius: 6
                        color: tree.accent
                        opacity: 0.94
                        z: 9999

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: node.isDir ? "▸" : "•"
                                color: Theme.accentFg
                                font.pixelSize: node.isDir ? 11 : 14
                            }
                            Text {
                                id: ghostText
                                anchors.verticalCenter: parent.verticalCenter
                                text: node.nameText
                                color: Theme.accentFg
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // Открытие файла по двойному клику — с задержкой-арбитром, чтобы
                // тройной клик (переименование) не открывал файл «по пути».
                Timer {
                    id: openTimer
                    interval: 260
                    onTriggered: {
                        root.activeFolderPath = Project.parentDir(node.path)
                        Docs.openFile(node.path)
                    }
                }

                // Клики: 1 — выбрать (папка ещё и раскрывается), 2 — открыть файл,
                // 3 — переименовать. Drag — вручную (proxy следует за курсором).
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    enabled: !node.renaming
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    // Не отдаём захват дереву-Flickable: зажатие на строке —
                    // это перетаскивание файла, а не прокрутка списка.
                    preventStealing: true

                    property real pressX: 0
                    property real pressY: 0
                    property bool dragActive: false
                    property int  clickCount: 0
                    property real lastReleaseMs: 0

                    onPressed: function (mouse) {
                        pressX = mouse.x; pressY = mouse.y
                        dragActive = false
                        tree.selectedPath = node.path
                        tree.forceActiveFocus()
                    }
                    onPositionChanged: function (mouse) {
                        if (pressed && !dragActive) {
                            const dx = mouse.x - pressX, dy = mouse.y - pressY
                            if (dx * dx + dy * dy >= 36)   // порог 6px
                                dragActive = true
                        }
                    }

                    onReleased: function (mouse) {
                        if (dragActive) {
                            // Явная доставка drop в DropArea под курсором —
                            // снятие Drag.active само по себе drop НЕ генерирует.
                            dragProxy.Drag.drop()
                            dragActive = false
                            clickCount = 0
                            return
                        }

                        const now = Date.now()
                        clickCount = (now - lastReleaseMs < 380) ? clickCount + 1 : 1
                        lastReleaseMs = now
                        tree.selectedPath = node.path

                        if (clickCount >= 3) {
                            openTimer.stop()
                            tree.renamingPath = node.path
                            clickCount = 0
                            return
                        }
                        if (node.isDir) {
                            if (clickCount === 1) {
                                root.activeFolderPath = node.path
                                if (node.expanded) tree.collapse(node.row)
                                else               tree.expand(node.row)
                            }
                        } else {
                            if (clickCount === 1)
                                root.activeFolderPath = Project.parentDir(node.path)
                            else if (clickCount === 2)
                                openTimer.restart()   // откроет, если не придёт 3-й клик
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: function (drag) {
                        const src = drag.source
                        const sp = (src && src.path) ? src.path : ""
                        if (!sp || sp === node.path) { tree.clearDrop(); return }
                        // Запрет drop папки в саму себя/потомка.
                        if (src.isDir && node.path.indexOf(sp + "/") === 0) {
                            tree.dropRow = node.row; tree.dropValid = false; return
                        }
                        tree.dropRow = node.row
                        tree.dropValid = true
                    }
                    onExited: { if (tree.dropRow === node.row) tree.clearDrop() }
                    onDropped: function (drop) {
                        drop.accepted = true   // не пропускаем в нижний DropArea
                        const src = drop.source
                        const sp = (src && src.path) ? src.path : ""
                        const ok = tree.dropValid
                        tree.clearDrop()
                        if (!sp || !ok) return
                        const targetDir = node.isDir ? node.path : Project.parentDir(node.path)
                        if (!targetDir) return
                        const np = Project.moveItem(sp, targetDir)
                        if (np && np.length > 0) {
                            // Открытый файл остаётся доступным для редактирования.
                            Docs.handlePathRenamed(sp, np)
                            if (tree.selectedPath === sp) tree.selectedPath = np
                            if (node.isDir && !node.expanded) tree.expand(node.row)
                        }
                    }
                }
            }

            // Клик по пустому месту дерева — забрать фокус (зафиксировать
            // активное поле переименования) и снять выделение.
            TapHandler {
                onTapped: tree.forceActiveFocus()
            }

            // Drop в пустую область — перенос в корень проекта.
            DropArea {
                anchors.fill: parent
                z: -1
                onDropped: function (drop) {
                    const src = drop.source
                    const sp = (src && src.path) ? src.path : ""
                    if (sp && Project.rootPath) {
                        const np = Project.moveItem(sp, Project.rootPath)
                        if (np && np.length > 0) {
                            Docs.handlePathRenamed(sp, np)
                            if (tree.selectedPath === sp) tree.selectedPath = np
                        }
                    }
                }
            }
        }
    }
}
