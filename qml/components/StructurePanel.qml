import QtQuick
import QtQuick.Controls.Basic
import DSLRay

// Панель «СТРУКТУРА» — список объектов активного JSON-документа.
// Для каждого объекта с полем "elementName" строится строка
// «Объект – <значение elementName>». Список перечитывается автоматически
// при переключении вкладки или открытии нового файла, т.к. привязан к
// Docs.activeContent.
PanelFrame {
    id: root
    title: "СТРУКТУРА"
    subtitle: Docs.hasDocuments ? Docs.activeName : ""

    // null  — содержимое не разобралось как JSON;
    // []    — JSON валиден, но объектов с elementName нет;
    // [..]  — найденные имена объектов.
    property var elements: computeElements(Docs.activeContent)

    readonly property bool noDoc:      !Docs.hasDocuments
    readonly property bool parseError: Docs.hasDocuments && elements === null
    readonly property bool empty:      !!elements && elements.length === 0

    // Рекурсивно обходит JSON и собирает значения "elementName".
    function computeElements(text) {
        if (!text || text.length === 0)
            return []
        var rootNode
        try {
            rootNode = JSON.parse(text)
        } catch (e) {
            return null
        }
        var out = []
        function walk(node) {
            if (node === null || typeof node !== "object")
                return
            if (Array.isArray(node)) {
                for (var i = 0; i < node.length; ++i)
                    walk(node[i])
                return
            }
            if (node.hasOwnProperty("elementName"))
                out.push(String(node.elementName))
            for (var k in node) {
                if (node.hasOwnProperty(k))
                    walk(node[k])
            }
        }
        walk(rootNode)
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
            required property string modelData

            width: list.width
            implicitHeight: 27

            Rectangle {
                anchors.fill: parent
                color: rowHover.hovered ? Theme.bgSubtle : "transparent"
            }
            HoverHandler { id: rowHover }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 7

                // Маркер объекта.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "◆"
                    font.pixelSize: 9
                    color: Theme.accent
                }
                // Тип.
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
                // Имя объекта.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: rowItem.width - 12 - 10 - x
                    text: rowItem.modelData
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontContent
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }
            }
        }
    }
}
