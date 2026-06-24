import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import DSLRay

// Панель «ПРОЕКТ» — проводник по проекту.
// Кнопки в шапке: «Открыть» (FolderDialog), «Создать файл», «Создать каталог».
// Дерево файлов — QFileSystemModel из ProjectController. Поддерживает:
//  · drag-and-drop (подсветка папки-цели / линия для файла-цели);
//  · открытие файла во вкладке по клику;
//  · инлайн-переименование тройным кликом или клавишей F2 — при этом, если
//    файл уже открыт, обновляется и заголовок его вкладки.
PanelFrame {
    id: root
    title: "ПРОЕКТ"
    subtitle: Project.hasProject ? rootName() : ""

    // Папка, в которую попадут «Создать файл» / «Создать каталог».
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
        nameField.text = (mode === "folder") ? "новая-папка" : "untitled.json"
        // Для файла выделяем только имя без расширения — удобнее переименовать.
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
        HeaderIconBtn { glyph: "📂"; tip: "Открыть"; onClicked: openDialog.open() },
        HeaderIconBtn { glyph: "📄"; badge: true; tip: "Создать файл";
                        btnEnabled: Project.hasProject; onClicked: root.startCreate("file") },
        HeaderIconBtn { glyph: "📁"; badge: true; tip: "Создать каталог";
                        btnEnabled: Project.hasProject; onClicked: root.startCreate("folder") }
    ]

    component HeaderIconBtn: Rectangle {
        id: hb
        property string glyph: ""
        property bool   badge: false
        property string tip: ""
        property bool   btnEnabled: true
        signal clicked()

        implicitWidth: 26
        implicitHeight: 22
        radius: Theme.rSmall
        color: hover.hovered && hb.btnEnabled ? "#f0f1f4" : "transparent"
        border.color: hb.btnEnabled ? Theme.border : Theme.borderSoft
        border.width: 1
        opacity: hb.btnEnabled ? 1.0 : 0.45

        Text {
            anchors.centerIn: parent
            text: hb.glyph
            font.pixelSize: 12
        }
        // «+» в углу — признак действия «создать».
        Text {
            visible: hb.badge
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2
            anchors.rightMargin: 1
            text: "+"
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.bold: true
            color: Theme.accent
        }
        HoverHandler { id: hover; enabled: hb.btnEnabled }
        TapHandler { enabled: hb.btnEnabled; onTapped: hb.clicked() }

        ToolTip.visible: hover.hovered && hb.tip.length > 0
        ToolTip.text: hb.tip
        ToolTip.delay: 400
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

            // Инлайн-переименование: путь редактируемого элемента + выбранный ряд.
            property string renamingPath: ""
            property string selectedPath: ""

            ScrollBar.vertical: ScrollBar {}

            // F2 — переименовать выбранный элемент.
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_F2 && tree.selectedPath.length > 0) {
                    tree.renamingPath = tree.selectedPath
                    event.accepted = true
                }
            }

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
                readonly property bool   renaming: tree.renamingPath === rowItem.path

                implicitWidth: tree.width
                implicitHeight: 22
                visible: rowItem.column === 0

                function commitRename() {
                    const oldPath = rowItem.path
                    const np = Project.renameItem(oldPath, renameField.text)
                    tree.renamingPath = ""
                    if (np && np.length > 0) {
                        Docs.handlePathRenamed(oldPath, np)
                        tree.selectedPath = np
                    }
                }

                // Фон: подсветка папки-цели (drop INTO) или hover.
                Rectangle {
                    anchors.fill: parent
                    color: rowItem.dropping && tree.dropMode === "into"
                           ? Qt.alpha(Theme.accent, 0.10)
                           : (rowItem.renaming || tree.selectedPath === rowItem.path
                              ? Qt.alpha(Theme.accent, 0.06)
                              : (rowMouse.containsMouse ? Theme.bgSubtle : "transparent"))
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
                        visible: !rowItem.renaming
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowItem.nameText
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontContent
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }
                }

                // Поле инлайн-переименования (поверх имени).
                TextField {
                    id: renameField
                    visible: rowItem.renaming
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 4 + rowItem.depth * 14 + 34
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    height: 20
                    selectByMouse: true
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontContent
                    color: Theme.textPrimary
                    leftPadding: 5; rightPadding: 5
                    topPadding: 0;  bottomPadding: 0
                    background: Rectangle {
                        color: Theme.bgPanel
                        border.color: Theme.accent
                        border.width: 1
                        radius: Theme.rSmall
                    }
                    onVisibleChanged: {
                        if (visible) {
                            text = rowItem.nameText
                            const dot = text.lastIndexOf(".")
                            if (!rowItem.isDir && dot > 0) select(0, dot)
                            else                            selectAll()
                            forceActiveFocus()
                        }
                    }
                    onAccepted: rowItem.commitRename()
                    Keys.onEscapePressed: tree.renamingPath = ""
                    onActiveFocusChanged: {
                        if (!activeFocus && rowItem.renaming)
                            rowItem.commitRename()
                    }
                }

                // Невидимый таргет для Drag — носит Drag.active.
                Item {
                    id: dragGhost
                    width: 1; height: 1; visible: false
                    Drag.active: rowMouse.drag.active
                    Drag.source: rowItem
                    Drag.hotSpot.x: 0
                    Drag.hotSpot.y: 0
                }

                // Взаимодействие: drag-and-drop + ручной подсчёт кликов
                // (1 — выбрать, 2 — открыть, 3 — переименовать). Считаем по
                // onReleased — это единственные «сырые» события, не съедаемые
                // встроенной обработкой double-click у MouseArea. Одиночный клик
                // срабатывает сразу; открытие/переименование — после паузы-арбитра,
                // чтобы тройной клик не открывал вкладку «по пути».
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    enabled: !rowItem.renaming
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    drag.target: dragGhost
                    drag.threshold: 6

                    property bool didDrag: false
                    property int  clickCount: 0
                    property real lastReleaseMs: 0

                    Timer {
                        id: resolveTimer
                        interval: 300
                        onTriggered: {
                            if (rowMouse.clickCount >= 3) {
                                tree.renamingPath = rowItem.path
                            } else if (rowMouse.clickCount === 2) {
                                if (rowItem.isDir) {
                                    if (rowItem.expanded) tree.collapse(rowItem.row)
                                    else                  tree.expand(rowItem.row)
                                } else {
                                    root.activeFolderPath = Project.parentDir(rowItem.path)
                                    Docs.openFile(rowItem.path)
                                }
                            }
                            rowMouse.clickCount = 0
                        }
                    }

                    onPressed: {
                        didDrag = false
                        // Забираем фокус у возможного активного поля
                        // переименования другого ряда — оно зафиксируется.
                        tree.forceActiveFocus()
                    }
                    onPositionChanged: if (drag.active) didDrag = true

                    onReleased: function (mouse) {
                        if (didDrag) { didDrag = false; clickCount = 0; resolveTimer.stop(); return }

                        const now = Date.now()
                        clickCount = (now - lastReleaseMs < 380) ? clickCount + 1 : 1
                        lastReleaseMs = now
                        tree.selectedPath = rowItem.path

                        if (clickCount === 1) {
                            // Мгновенный одиночный клик: шеврон — раскрыть; иначе выбрать.
                            resolveTimer.stop()
                            const chevronEnd = 4 + rowItem.depth * 14 + 12
                            if (rowItem.hasChildren && mouse.x < chevronEnd) {
                                if (rowItem.expanded) tree.collapse(rowItem.row)
                                else                  tree.expand(rowItem.row)
                            } else {
                                root.activeFolderPath = rowItem.isDir
                                    ? rowItem.path
                                    : Project.parentDir(rowItem.path)
                            }
                        } else {
                            // 2+ кликов — арбитр решит: открыть (2) или переименовать (3).
                            resolveTimer.restart()
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
