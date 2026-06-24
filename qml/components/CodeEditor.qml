import QtQuick
import QtQuick.Controls.Basic
import DSLRay

// Панель «КОД» — редактор активного документа.
// Возможности: показ содержимого, нумерация строк, подсветка синтаксиса JSON,
// подсветка текущей строки каретки, переход к объекту по смещению (из «Структуры»).
// Запись правок на диск («Прозрачный режим») подключается в следующей итерации.
PanelFrame {
    id: root
    title: "КОД"
    subtitle: Docs.hasDocuments ? Docs.activeName : ""

    // Какой путь сейчас загружен в редактор — чтобы не перетирать текст при
    // обновлениях активного контента, не связанных со сменой документа.
    property string loadedPath: ""
    // Гасит реакцию на programmatic-смену текста (перезагрузку), чтобы она не
    // воспринималась как пользовательская правка.
    property bool suppressEdit: false

    readonly property int lineHeight: Math.ceil(fm.lineSpacing)

    FontMetrics {
        id: fm
        font.family: Theme.fontMono
        font.pixelSize: 13
    }

    function reload() {
        if (Docs.activePath !== root.loadedPath) {
            // Незаписанные правки уходящего документа — сбросить на диск
            // по его пути (активным уже стал другой документ).
            if (editTimer.running) {
                editTimer.stop()
                if (root.loadedPath.length > 0)
                    Docs.flushEdit(root.loadedPath, ta.text)
            }
            root.loadedPath = Docs.activePath
            root.suppressEdit = true
            ta.text = Docs.activeContent
            root.suppressEdit = false
            ta.cursorPosition = 0
            flick.contentY = 0
            flick.contentX = 0
        }
    }

    // Применить накопленную правку активного документа немедленно.
    function flushPending() {
        if (editTimer.running) {
            editTimer.stop()
            Docs.applyEdit(ta.text)
        }
    }

    // Дебаунс записи: правки применяются через паузу после ввода.
    Timer {
        id: editTimer
        interval: 400
        onTriggered: Docs.applyEdit(ta.text)
    }

    // Перейти к смещению в тексте и подкрутить его в видимую зону.
    function gotoOffset(pos) {
        if (!Docs.hasDocuments)
            return
        ta.cursorPosition = Math.max(0, Math.min(pos, ta.length))
        ta.forceActiveFocus()
        const r = ta.cursorRectangle
        if (r.y < flick.contentY)
            flick.contentY = Math.max(0, r.y - 2 * root.lineHeight)
        else if (r.y + r.height > flick.contentY + flick.height)
            flick.contentY = r.y + r.height - flick.height + 2 * root.lineHeight
    }

    Connections {
        target: Docs
        function onActiveChanged() { root.reload() }
    }
    Component.onCompleted: root.reload()

    // ── Пустое состояние ──────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: !Docs.hasDocuments
        text: "откройте файл"
        font.family: Theme.fontMono
        font.pixelSize: 13
        color: Theme.textGhost
    }

    // ── Редактор ──────────────────────────────────────────────────────
    Item {
        id: editor
        anchors.fill: parent
        visible: Docs.hasDocuments

        // Текущая строка каретки (для подсветки номера в гаттере).
        readonly property int caretLine: ta.text.substring(0, ta.cursorPosition).split("\n").length - 1
        readonly property int gutterWidth:
            Math.max(2, String(Math.max(1, ta.lineCount)).length) * fm.advanceWidth("0") + 18

        // Гаттер с номерами строк.
        Rectangle {
            id: gutter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: editor.gutterWidth
            color: Theme.bgSubtle
            clip: true

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Theme.borderSoft
            }

            Item {
                width: parent.width
                y: ta.topPadding - flick.contentY

                Repeater {
                    model: Math.max(1, ta.lineCount)
                    delegate: Text {
                        required property int index
                        y: index * root.lineHeight
                        width: gutter.width - 8
                        height: root.lineHeight
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        text: index + 1
                        font.family: Theme.fontMono
                        font.pixelSize: 13
                        color: index === editor.caretLine ? Theme.accent : Theme.textGhost
                    }
                }
            }
        }

        // Текст.
        Flickable {
            id: flick
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: gutter.right
            anchors.right: parent.right
            clip: true
            contentWidth: ta.width
            contentHeight: ta.height

            ScrollBar.vertical: ScrollBar {}
            ScrollBar.horizontal: ScrollBar {}

            TextArea {
                id: ta
                width: Math.max(implicitWidth, flick.width)
                height: Math.max(implicitHeight, flick.height)
                wrapMode: TextArea.NoWrap
                selectByMouse: true
                persistentSelection: true
                font.family: Theme.fontMono
                font.pixelSize: 13
                color: Theme.textPrimary
                leftPadding: 8
                topPadding: 6
                bottomPadding: 6
                tabStopDistance: fm.advanceWidth("0") * 2

                // Пользовательская правка — запустить дебаунс записи.
                onTextChanged: if (!root.suppressEdit) editTimer.restart()
                // Уход фокуса — сразу применить накопленное.
                onActiveFocusChanged: if (!activeFocus) root.flushPending()

                // Подсветка текущей строки — позади текста.
                background: Rectangle {
                    color: "transparent"
                    Rectangle {
                        x: 0
                        width: ta.width
                        y: ta.cursorRectangle.y
                        height: ta.cursorRectangle.height
                        color: Qt.alpha(Theme.accent, 0.06)
                        visible: ta.activeFocus
                    }
                }

                JsonHighlighter { document: ta.textDocument }
            }
        }
    }
}
