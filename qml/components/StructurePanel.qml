import QtQuick
import QtQuick.Controls.Basic
import DSLRay

// Панель «СТРУКТУРА» — список объектов активного JSON-документа.
// Для каждого объекта с полем "elementName" строится строка
// «Объект – <значение>». Клик по строке переводит каретку редактора к этому
// объекту (сигнал objectActivated с символьным смещением). Список
// перечитывается автоматически при смене вкладки или открытии файла.
PanelFrame {
    id: root
    title: "СТРУКТУРА"
    subtitle: Docs.hasDocuments ? Docs.activeName : ""

    // Сигнал перехода к объекту: offset — смещение в тексте документа.
    signal objectActivated(int offset)

    // null  — содержимое не разобралось как JSON;
    // []    — JSON валиден, но объектов с elementName нет;
    // [..]  — массив { name, index }.
    property var elements: computeElements(Docs.activeContent)

    readonly property bool noDoc:      !Docs.hasDocuments
    readonly property bool parseError: Docs.hasDocuments && elements === null
    readonly property bool empty:      !!elements && elements.length === 0

    // Верх видимой области кода (символьное смещение) — приходит из CodeEditor.
    property int codeTopOffset: -1
    // «Текущий» объект — последний, чьё начало уже выше верха видимой области.
    // Объекты 0..currentItemIndex считаются пройденными.
    readonly property int currentItemIndex: {
        if (!elements || elements.length === 0)
            return -1
        var last = -1
        for (var i = 0; i < elements.length; ++i) {
            if (elements[i].index <= codeTopOffset) last = i
            else break
        }
        return last
    }

    // Проверяет валидность JSON и собирает позиции всех "elementName".
    function computeElements(text) {
        if (!text || text.length === 0)
            return []
        try {
            JSON.parse(text)
        } catch (e) {
            return null
        }
        var out = []
        var re = /"elementName"\s*:\s*"((?:[^"\\]|\\.)*)"/g
        var m
        while ((m = re.exec(text)) !== null) {
            out.push({ name: m[1], index: m.index })
            if (re.lastIndex === m.index) // защита от зацикливания на пустом совпадении
                re.lastIndex++
        }
        return out
    }

    // ── Подсказка для пустых/ошибочных состояний ──────────────────────
    Text {
        anchors.centerIn: parent
        visible: root.noDoc || root.parseError || root.empty
        horizontalAlignment: Text.AlignHCenter
        text: root.noDoc      ? "откройте файл"
            : root.parseError ? "не удалось разобрать JSON"
            :                   "объекты не найдены"
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontContent
        color: Theme.textGhost
    }

    // ── Список объектов ───────────────────────────────────────────────
    ListView {
        id: list
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        clip: true
        visible: !root.noDoc && !root.parseError && !root.empty
        model: root.elements

        ScrollBar.vertical: ScrollBar {}

        delegate: Item {
            id: rowItem
            required property int index
            required property var modelData

            readonly property bool passed:  rowItem.index <= root.currentItemIndex
            readonly property bool current: rowItem.index === root.currentItemIndex

            width: list.width
            implicitHeight: 27

            Rectangle {
                anchors.fill: parent
                color: rowItem.current ? Qt.alpha(Theme.accent, 0.10)
                     : (rowMouse.containsMouse ? Theme.bgSubtle : "transparent")
            }

            // Левая полоса у пройденных объектов («трасса»).
            Rectangle {
                visible: rowItem.passed
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 2
                color: Theme.accent
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 7

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "◆"
                    font.pixelSize: 9
                    color: rowItem.passed ? Theme.accent : Theme.textGhost
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Объект"
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontContent
                    color: Theme.textFaint
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "–"
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontContent
                    color: Theme.textGhost
                }
                Text {
                    id: nameLabel
                    anchors.verticalCenter: parent.verticalCenter
                    width: rowItem.width - 12 - 10 - x
                    text: rowItem.modelData.name
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontContent
                    font.weight: rowItem.current ? Font.DemiBold : Font.Medium
                    color: rowItem.passed ? Theme.accent : Theme.textPrimary
                    elide: Text.ElideRight

                    // Полное имя во всплывающей подсказке, если не помещается.
                    ToolTip.visible: rowMouse.containsMouse && nameLabel.truncated
                    ToolTip.text: rowItem.modelData.name
                    ToolTip.delay: 500
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.objectActivated(rowItem.modelData.index)
            }
        }
    }
}
