import QtQuick
import QtQuick.Layouts
import DSLRay

// Строка вкладок открытых файлов.
// На шаге 1 — две статичные вкладки и кнопка «+», как в макете.
// Скролл-кнопки и реальное открытие/закрытие — на шаге 3.
Rectangle {
    id: root
    height: Theme.tabsRowHeight
    color: Theme.bgTabsRow

    // нижняя граница
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.divider
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 4

        Tab { label: "main.dsl";   active: true  }
        Tab { label: "header.dsl"; active: false }

        // «+»
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 26; height: 26
            radius: 7
            color: hoverPlus.hovered ? "#f4f5f8" : Theme.bgPanel
            border.color: Theme.border
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: "+"
                font.family: Theme.fontSans
                font.pixelSize: 15
                color: Theme.textMuted
            }
            HoverHandler { id: hoverPlus }
        }

        Item { Layout.fillWidth: true }
    }

    // ─────────────── inline-компонент: одна вкладка ───────────────
    component Tab: Item {
        id: tab
        property string label: ""
        property bool   active: false

        implicitWidth: row.implicitWidth + 22
        Layout.fillHeight: true

        Rectangle {
            id: bg
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: -1   // «съезжает» на разделительную линию снизу
            color: tab.active ? Theme.bgPanel : "transparent"
            border.color: tab.active ? Theme.border : "transparent"
            border.width: 1
            topLeftRadius: 8
            topRightRadius: 8

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: tab.label
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontTabs
                    color: tab.active ? Theme.textPrimary : Theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "\u2715"      // ✕
                    font.pixelSize: 11
                    color: Theme.textFaint
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
