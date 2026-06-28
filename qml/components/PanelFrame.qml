import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DSLRay

// Карточка-панель: белый фон, граница, скругление, шапка с заголовком
// и слотом для дополнительных контролов справа (зум, кнопки и т.п.).
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""

    // Дополнительные элементы в шапке справа.
    // Можно передать как массив: headerRight: [ Item {...}, Item {...} ].
    property alias headerRight: headerRightRow.data

    // Тело панели — сюда по default попадают дочерние QML-элементы.
    default property alias bodyChildren: body.data

    color: Theme.bgPanel
    border.color: Theme.border
    border.width: 1
    radius: Theme.rCard

    // ── Шапка ──────────────────────────────────────────────────────
    // Отступ 1px от краёв — чтобы бордюр родителя не оказался затёрт
    // фоном шапки (Qt Quick рисует детей поверх рамки Rectangle).
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        height: Theme.panelHeaderHeight
        color: Theme.bgSubtle

        // Скругляем только верхние углы; радиус на 1px меньше внешнего,
        // т.к. шапка вставлена внутрь рамки на 1px.
        topLeftRadius: Theme.rCard - 1
        topRightRadius: Theme.rCard - 1

        // Линия-разделитель снизу.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.borderSoft
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 13
            anchors.rightMargin: 10
            spacing: 8

            Text {
                text: root.title
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontPanelHeader
                font.weight: Font.Bold
                font.letterSpacing: Theme.letterSpacingHeader
                font.capitalization: Font.AllUppercase
                color: Theme.textFaint
            }

            Text {
                id: subtitleLabel
                text: root.subtitle
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontPanelHeader
                font.weight: Font.Medium
                color: Theme.textGhost

                // Полное имя во всплывающей подсказке, если оно не помещается.
                HoverHandler { id: subHover }
                ToolTip.visible: subHover.hovered && subtitleLabel.truncated
                ToolTip.text: root.subtitle
                ToolTip.delay: 500
            }

            // Слот для контролов справа в шапке.
            Row {
                id: headerRightRow
                spacing: 5
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ── Тело ────────────────────────────────────────────────────────
    Item {
        id: body
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 1   // не залезать на border
        anchors.rightMargin: 1
        anchors.bottomMargin: 1
        clip: true
    }
}
