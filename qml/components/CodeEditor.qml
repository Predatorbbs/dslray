import QtQuick
import QtQuick.Controls.Basic
import DSLRay
import "EditorText.js" as EditorText

// Панель «КОД» — редактор активного документа.
// Возможности: показ содержимого, нумерация строк, подсветка синтаксиса JSON,
// подсветка всей текущей логической строки (включая перенос по словам),
// подсветка парной скобки и ошибок (несбалансированные скобки / незакрытая
// строка), вертикальные направляющие вложений, авто-отступ по структуре,
// форматирование отступов всего документа, переход к объекту из «Структуры».
PanelFrame {
    id: root
    objectName: "codeEditor"
    title: "КОД"
    subtitle: Docs.hasDocuments ? Docs.activeName : ""

    // Кнопка форматирования отступов в правой части шапки.
    headerRight: [
        Rectangle {
            id: fmtBtn
            visible: Docs.hasDocuments
            implicitWidth: 30
            implicitHeight: 24
            radius: Theme.rSmall
            color: fmtHover.hovered ? "#eceef2" : "transparent"
            border.width: 1
            border.color: fmtHover.hovered ? Theme.border : "transparent"

            // Иконка «ступенчатые строки» — намёк на выравнивание отступов.
            Item {
                anchors.centerIn: parent
                width: 14; height: 12
                Rectangle { x: 0; y: 0;  width: 14; height: 2; radius: 1; color: Theme.textMuted }
                Rectangle { x: 4; y: 5;  width: 10; height: 2; radius: 1; color: Theme.textMuted }
                Rectangle { x: 4; y: 10; width: 8;  height: 2; radius: 1; color: Theme.textMuted }
            }

            HoverHandler { id: fmtHover }
            TapHandler { onTapped: root.formatDocument() }

            ToolTip.visible: fmtHover.hovered
            ToolTip.text: "Форматировать отступы"
            ToolTip.delay: 400
        }
    ]

    // Какой путь сейчас загружен в редактор — чтобы не перетирать текст при
    // обновлениях активного контента, не связанных со сменой документа.
    property string loadedPath: ""
    // Гасит реакцию на programmatic-смену текста (перезагрузку), чтобы она не
    // воспринималась как пользовательская правка.
    property bool suppressEdit: false

    readonly property int lineHeight: Math.ceil(fm.lineSpacing)
    readonly property real charWidth: fm.advanceWidth("0")

    // Защита от тяжёлых файлов: разбор скобок/ошибок и направляющие вложений —
    // O(n) на каждую правку, поэтому выше порога они выключаются. Редактор при
    // этом остаётся рабочим: подсветка синтаксиса, нумерация, текущая строка.
    // (JSON DSLRay вряд ли превысит порог — это запас на будущий рефакторинг.)
    readonly property int richLimitChars: 200000
    readonly property bool richEnabled: ta.length <= root.richLimitChars

    // Живые счётчики активного файла — для статус-бара. Токены ≈ символы/4
    // (грубая эвристика, как в прототипе).
    readonly property int liveChars:  Docs.hasDocuments ? ta.length : 0
    readonly property int liveLines:  Docs.hasDocuments ? (root.lineStarts ? root.lineStarts.length : 1) : 0
    readonly property int liveTokens: Docs.hasDocuments ? Math.max(1, Math.ceil(ta.length / 4)) : 0

    // Символьное смещение начала строки, идущей сразу под верхом видимой
    // области — для подсветки «пройденных» объектов в «Структуре».
    readonly property int topOffset: (ta.length, ta.positionAt(ta.leftPadding + 2, flick.contentY + root.lineHeight + 2))

    // Смещения начал логических строк (для нумерации, корректной при переносе).
    readonly property var lineStarts: EditorText.lineStarts(ta.text)

    // Разбор скобок/строк зависит только от текста, а не от каретки/прокрутки.
    readonly property var analysis: root.richEnabled ? EditorText.analyze(ta.text)
                                                     : ({ pairs: ({}), errors: [] })

    function formatDocument() {
        if (!Docs.hasDocuments)
            return
        var formatted = EditorText.reindent(ta.text, Preferences.indentWidth, Preferences.indentUseTabs)
        if (formatted === ta.text)
            return
        var pos = ta.cursorPosition
        ta.text = formatted          // обычная правка → дебаунс записи на диск
        ta.cursorPosition = Math.min(pos, ta.length)
    }

    // Enter с учётом структуры: сохраняем отступ текущей строки, добавляем
    // уровень после открывающей скобки, «раскрываем» пару {}/[] двумя строками.
    function insertNewline() {
        if (ta.selectedText.length > 0)
            ta.remove(ta.selectionStart, ta.selectionEnd)
        var pos = ta.cursorPosition
        var edit = EditorText.newlineEdit(ta.text, pos, Preferences.indentWidth, Preferences.indentUseTabs)
        ta.insert(pos, edit.text)
        ta.cursorPosition = edit.cursor
    }

    // Вставку выполняет TextArea: сохраняем обычную историю undo/redo.
    function insertTab() {
        ta.insert(ta.cursorPosition, EditorText.tabText(ta.text, ta.cursorPosition,
                                                      Preferences.indentWidth, Preferences.indentUseTabs))
    }

    FontMetrics {
        id: fm
        font.family: Theme.fontMono
        font.pixelSize: Preferences.codeFontSize
    }

    // Text/layout signals can arrive before cached line and bracket offsets update.
    function textRectangle(position) {
        if (root.suppressEdit)
            return Qt.rect(0, 0, 0, root.lineHeight)
        return ta.positionToRectangle(Math.max(0, Math.min(position, ta.length)))
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
            // Каретку — в начало ДО замены текста, иначе старая позиция может
            // оказаться вне диапазона нового документа (QTextCursor out of range).
            ta.cursorPosition = 0
            ta.text = Docs.activeContent
            ta.cursorPosition = 0
            root.suppressEdit = false
            flick.contentY = 0
            flick.contentX = 0
            // Форсируем фокус редактора при переключении вкладки: показывает
            // каретку и триггерит перерисовку (иначе текст новой вкладки иногда
            // не прорисовывается до первого взаимодействия).
            if (Docs.hasDocuments)
                ta.forceActiveFocus()
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

    // Подкрутить вьюпорт так, чтобы каретка оставалась видимой (когда её увели
    // стрелками за край). Вызывается на смену прямоугольника каретки.
    function ensureCursorVisible() {
        if (!Docs.hasDocuments || root.suppressEdit)
            return
        const r = ta.cursorRectangle
        const maxY = Math.max(0, ta.height - flick.height)
        if (r.y < flick.contentY)
            flick.contentY = Math.max(0, r.y)
        else if (r.y + r.height > flick.contentY + flick.height)
            flick.contentY = Math.min(maxY, r.y + r.height - flick.height)
        if (!Preferences.wordWrap) {
            const maxX = Math.max(0, ta.width - flick.width)
            const m = root.charWidth * 2
            if (r.x < flick.contentX)
                flick.contentX = Math.max(0, r.x - m)
            else if (r.x + r.width > flick.contentX + flick.width)
                flick.contentX = Math.min(maxX, r.x + r.width - flick.width + m)
        }
    }

    Connections {
        target: Docs
        function onActiveChanged() { root.reload() }
        function onFlushRequested() { root.flushPending() }
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
        objectName: "editor"
        anchors.fill: parent
        visible: Docs.hasDocuments

        // Текущая логическая строка каретки (для подсветки номера в гаттере).
        readonly property int caretLine: EditorText.lineAt(root.lineStarts, ta.cursorPosition)
        // По числу ЛОГИЧЕСКИХ строк (lineStarts) — не зависит от ширины/переноса,
        // иначе цикл биндингов gutterWidth ↔ ta.lineCount ↔ ta.width.
        readonly property int gutterWidth:
            Math.max(2, String(Math.max(1, root.lineStarts ? root.lineStarts.length : 1)).length)
            * fm.advanceWidth("0") + 18

        // Прямоугольник всей текущей логической строки (включая перенос).
        readonly property rect curLineRect: {
            var _ = [ta.cursorPosition, ta.text, ta.width, Preferences.wordWrap, Preferences.codeFontSize]
            var cl = editor.caretLine
            if (!root.lineStarts || cl < 0 || cl >= root.lineStarts.length)
                return Qt.rect(0, 0, 0, 0)
            var s = root.lineStarts[cl]
            var e = (cl + 1 < root.lineStarts.length) ? root.lineStarts[cl + 1] - 1 : ta.length
            var r1 = root.textRectangle(s)
            var r2 = root.textRectangle(e)
            return Qt.rect(0, r1.y, ta.width, (r2.y + r2.height) - r1.y)
        }

        // Пара подсвеченных скобок: [offsetA, offsetB] или null — когда каретка
        // стоит вплотную к одной из парных скобок.
        readonly property var matchPair: {
            var _ = [ta.cursorPosition, ta.text]
            var p = root.analysis.pairs
            var pos = ta.cursorPosition
            if (pos < ta.length && p[pos] !== undefined) return [pos, p[pos]]
            if (pos > 0 && p[pos - 1] !== undefined) return [pos - 1, p[pos - 1]]
            return null
        }

        // Only instantiate line-number items around the viewport. Wrapped rows
        // still map to their logical line through the same cached offsets.
        // Publish both bounds together: independent bindings briefly combined the
        // new first line with the old last line and created a delegate per file line.
        readonly property var visibleLines: {
            if (root.suppressEdit)
                return { first: 0, last: -1 }
            var dependencies = [ta.text, ta.width, ta.height, Preferences.wordWrap, Preferences.codeFontSize]
            var first = Math.max(0, EditorText.lineAt(root.lineStarts,
                ta.positionAt(ta.leftPadding, flick.contentY)) - 1)
            var last = Math.min(root.lineStarts.length - 1, EditorText.lineAt(root.lineStarts,
                ta.positionAt(ta.leftPadding, flick.contentY + flick.height)) + 1)
            return { first: first, last: last }
        }
        readonly property int firstVisibleLine: visibleLines.first
        readonly property int lastVisibleLine: visibleLines.last
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
                    objectName: "lineNumbers"
                    model: Math.max(0, editor.visibleLines.last - editor.visibleLines.first + 1)
                    delegate: Text {
                        required property int index
                        readonly property int logicalLine: editor.visibleLines.first + index
                        // Позиция логической строки (учитывает перенос).
                        y: root.textRectangle(root.lineStarts[logicalLine]).y
                        width: gutter.width - 8
                        height: root.lineHeight
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        text: logicalLine + 1
                        font.family: Theme.fontMono
                        font.pixelSize: Preferences.codeFontSize
                        color: logicalLine === editor.caretLine ? Theme.accent : Theme.textGhost
                    }
                }
            }
        }

        // Вертикальные направляющие вложений — фиксированный к окну Canvas
        // позади текста (рисуется со сдвигом на прокрутку). Видны сквозь
        // прозрачный фон Flickable/TextArea.
        Canvas {
            id: guideCanvas
            anchors.fill: flick
            renderStrategy: Canvas.Cooperative

            property var paintDeps: [root.lineStarts, ta.width, ta.text,
                Preferences.codeFontSize, Preferences.wordWrap, Preferences.indentWidth,
                flick.contentY, flick.height, root.richEnabled, editor.matchPair,
                Theme.editorGuide, Theme.accent]
            onPaintDepsChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                if (!root.richEnabled)
                    return
                var sw = fm.advanceWidth("0")
                var t = Preferences.indentWidth
                var lp = ta.leftPadding
                var top = flick.contentY
                var bottom = top + flick.height
                var txt = ta.text
                var ls = root.lineStarts
                if (!ls)
                    return

                // ── Обычные направляющие вложений ─────────────────────────
                ctx.strokeStyle = Theme.editorGuide
                ctx.lineWidth = 1
                // Начинаем с видимой строки (и соседней сверху для её границы),
                // не запрашивая геометрию всех строк до текущего скролла.
                var topPosition = ta.positionAt(lp, top)
                var firstLine = Math.max(0, EditorText.lineAt(ls, topPosition) - 1)
                for (var i = firstLine; i < ls.length; ++i) {
                    var startOff = ls[i]
                    var y0 = root.textRectangle(startOff).y
                    var y1 = (i + 1 < ls.length) ? root.textRectangle(ls[i + 1]).y
                                                 : (y0 + root.lineHeight)
                    if (y1 < top) continue
                    if (y0 > bottom) break
                    var stops = EditorText.indentStops(txt, startOff, t)
                    for (var k = 1; k <= stops; ++k) {
                        var x = Math.round(lp + k * t * sw) + 0.5
                        ctx.beginPath()
                        ctx.moveTo(x, y0 - top)
                        ctx.lineTo(x, y1 - top)
                        ctx.stroke()
                    }
                }

                // ── Активная линия парной скобки (акцентом) ───────────────
                // Вертикаль на уровень глубже строки открывающей скобки,
                // от низа её строки до верха строки закрывающей.
                var mp = editor.matchPair
                if (mp) {
                    var a = Math.min(mp[0], mp[1])
                    var b = Math.max(mp[0], mp[1])
                    // Линия идёт от начала текста строки открывающей скобки:
                    // если скобка одна на строке — от неё самой; если перед ней
                    // был текст — от его начала.
                    var lineA = ls[EditorText.lineAt(ls, a)]
                    var fnw = EditorText.firstContent(txt, lineA)
                    var gx = Math.round(root.textRectangle(fnw).x) + 0.5
                    var ra = root.textRectangle(a)
                    var rb = root.textRectangle(b)
                    var ya = ra.y + ra.height            // низ строки открывающей
                    var yb = rb.y                        // верх строки закрывающей
                    if (yb - ya > 1) {
                        ctx.strokeStyle = Theme.accent
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        ctx.moveTo(gx, Math.max(ya, top) - top)
                        ctx.lineTo(gx, Math.min(yb, bottom) - top)
                        ctx.stroke()
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

            // Прокрутка колесом — задаём свой шаг (по умолчанию ощутимо медленно).
            WheelHandler {
                property int wheelLines: 4
                onWheel: function (event) {
                    const dy = event.angleDelta.y
                    const dx = event.angleDelta.x
                    const stepY = root.lineHeight * wheelLines
                    if (dy !== 0) {
                        const maxY = Math.max(0, ta.height - flick.height)
                        flick.contentY = Math.max(0, Math.min(flick.contentY - (dy / 120) * stepY, maxY))
                    }
                    if (dx !== 0 && !Preferences.wordWrap) {
                        const maxX = Math.max(0, ta.width - flick.width)
                        flick.contentX = Math.max(0, Math.min(flick.contentX - (dx / 120) * stepY, maxX))
                    }
                    event.accepted = true
                }
            }

            TextArea {
                id: ta
                objectName: "ta"
                width: Preferences.wordWrap ? flick.width : Math.max(implicitWidth, flick.width)
                height: Math.max(implicitHeight, flick.height)
                wrapMode: Preferences.wordWrap ? TextArea.Wrap : TextArea.NoWrap
                selectByMouse: true
                persistentSelection: true
                font.family: Theme.fontMono
                font.pixelSize: Preferences.codeFontSize
                color: Theme.textPrimary
                // Мягкое выделение (тема-зависимое), текст остаётся читаемым.
                selectionColor: Theme.editorSelection
                selectedTextColor: Theme.textPrimary
                leftPadding: 8
                topPadding: 6
                bottomPadding: 6
                tabStopDistance: fm.advanceWidth("0") * Preferences.indentWidth

                // Пользовательская правка — запустить дебаунс записи.
                onTextChanged: if (!root.suppressEdit) editTimer.restart()
                // Уход фокуса — сразу применить накопленное.
                onActiveFocusChanged: if (!activeFocus) root.flushPending()
                // Каретку увели за край (стрелками/вводом) — подвинуть вьюпорт.
                onCursorRectangleChanged: root.ensureCursorVisible()

                // Явная мигающая каретка — дефолтная иногда не прорисовывается
                // до первого ввода. 2px, гаснет/зажигается, при перемещении
                // сразу показывается (как в обычных редакторах).
                cursorDelegate: Rectangle {
                    id: caret
                    width: 2
                    height: root.lineHeight
                    color: Theme.textPrimary
                    visible: ta.activeFocus && caret.blinkOn
                    property bool blinkOn: true

                    Timer {
                        id: blinkTimer
                        running: ta.activeFocus
                        repeat: true
                        interval: 530
                        onTriggered: caret.blinkOn = !caret.blinkOn
                    }
                    Connections {
                        target: ta
                        function onCursorPositionChanged() {
                            caret.blinkOn = true
                            blinkTimer.restart()
                        }
                    }
                }

                // Enter / Tab обрабатываем сами (авто-отступ, тип табуляции).
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.insertNewline()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        root.insertTab()
                        event.accepted = true
                    }
                }

                // ── Слой подсветки позади текста ──────────────────────────
                background: Item {
                    // Подсветка всей текущей логической строки.
                    Rectangle {
                        x: 0
                        y: editor.curLineRect.y
                        width: ta.width
                        height: editor.curLineRect.height
                        color: Theme.editorCurLine
                        visible: ta.activeFocus && editor.curLineRect.height > 0
                    }

                    // Парные скобки.
                    Repeater {
                        model: editor.matchPair ? editor.matchPair : []
                        delegate: Rectangle {
                            required property var modelData
                            property rect rr: {
                                var _ = [ta.width, ta.text, Preferences.wordWrap, Preferences.codeFontSize]
                                return root.textRectangle(modelData)
                            }
                            x: rr.x
                            y: rr.y
                            width: root.charWidth
                            height: rr.height
                            radius: 2
                            color: Theme.editorBracket
                            border.width: 1
                            border.color: Theme.accent
                        }
                    }

                    // Ошибки синтаксиса: подложка + красное подчёркивание.
                    Repeater {
                        model: root.analysis.errors
                        delegate: Item {
                            required property var modelData
                            property rect rr: {
                                var _ = [ta.width, ta.text, Preferences.wordWrap, Preferences.codeFontSize]
                                return root.textRectangle(modelData)
                            }
                            x: rr.x
                            y: rr.y
                            width: root.charWidth
                            height: rr.height
                            Rectangle {
                                anchors.fill: parent
                                radius: 2
                                color: Qt.alpha(Theme.err, 0.13)
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 2
                                color: Theme.err
                            }
                        }
                    }
                }

                JsonHighlighter {
                    id: jsonHl
                    document: ta.textDocument
                    tabWidth: Preferences.indentWidth
                    keyColor: Preferences.colorKey
                    stringColor: Preferences.colorString
                    numberColor: Preferences.colorNumber
                    keywordColor: Preferences.colorKeyword
                    punctColor: Preferences.colorPunct
                }
                // Размер шрифта меняет ширину пробела в пикселях — пересчитать
                // висячий отступ переноса после применения нового шрифта.
                Connections {
                    target: Preferences
                    function onCodeFontSizeChanged() { Qt.callLater(jsonHl.refreshIndent) }
                }
            }
        }
    }
}
