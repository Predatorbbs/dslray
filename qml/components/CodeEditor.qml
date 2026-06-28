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

    // Символьное смещение начала строки, идущей сразу под верхом видимой
    // области — для подсветки «пройденных» объектов в «Структуре». Берём с
    // поправкой на строку, чтобы объект на самой верхней видимой строке уже
    // считался пройденным. Пересчитывается при прокрутке и смене текста.
    readonly property int topOffset: (ta.length, ta.positionAt(ta.leftPadding + 2, flick.contentY + root.lineHeight + 2))

    // Смещения начал логических строк (для нумерации, корректной при переносе).
    property var lineStarts: computeLineStarts(ta.text)
    function computeLineStarts(t) {
        var arr = [0]
        for (var i = 0; i < t.length; ++i)
            if (t.charCodeAt(i) === 10) arr.push(i + 1)
        return arr
    }

    FontMetrics {
        id: fm
        font.family: Theme.fontMono
        font.pixelSize: Docs.codeFontSize
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

    // Перейти к смещению: ставим каретку и подкручиваем строку объекта к верху
    // (так он попадает в «пройденные» и подсвечивается в «Структуре»).
    function gotoOffset(pos) {
        if (!Docs.hasDocuments)
            return
        ta.cursorPosition = Math.max(0, Math.min(pos, ta.length))
        ta.forceActiveFocus()
        const r = ta.cursorRectangle
        const maxY = Math.max(0, ta.height - flick.height)
        flick.contentY = Math.max(0, Math.min(r.y - 2, maxY))
    }

    Connections {
        target: Docs
        function onActiveChanged() { root.reload() }
        // Содержимое заменено программно (отброс черновика) — перечитать текст
        // даже если путь не менялся.
        function onActiveContentReset() {
            root.suppressEdit = true
            ta.text = Docs.activeContent
            root.suppressEdit = false
        }
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
                y: -flick.contentY

                Repeater {
                    model: root.lineStarts ? root.lineStarts.length : 1
                    delegate: Text {
                        required property int index
                        // Позиция логической строки (учитывает перенос).
                        y: ta.positionToRectangle(root.lineStarts[index]).y
                        width: gutter.width - 8
                        height: root.lineHeight
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        text: index + 1
                        font.family: Theme.fontMono
                        font.pixelSize: Docs.codeFontSize
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
                width: Docs.wordWrap ? flick.width : Math.max(implicitWidth, flick.width)
                height: Math.max(implicitHeight, flick.height)
                wrapMode: Docs.wordWrap ? TextArea.Wrap : TextArea.NoWrap
                selectByMouse: true
                persistentSelection: true
                font.family: Theme.fontMono
                font.pixelSize: Docs.codeFontSize
                color: Theme.textPrimary
                // Мягкое серо-голубое выделение, текст остаётся тёмным.
                selectionColor: "#d7dbe6"
                selectedTextColor: Theme.textPrimary
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
