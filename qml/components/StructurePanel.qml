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

            width: list.width
            implicitHeight: 27

            Rectangle {
                anchors.fill: parent
                color: rowMouse.containsMouse ? Theme.bgSubtle : "transparent"
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
                    color: Theme.accent
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
                    anchors.verticalCenter: parent.verticalCenter
                    width: rowItem.width - 12 - 10 - x
                    text: rowItem.modelData.name
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontContent
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    elide: Text.ElideRight
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
