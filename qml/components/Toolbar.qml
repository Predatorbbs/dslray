import QtQuick
import QtQuick.Layouts
import DSLRay

// Верхний тулбар. На шаге 1 — только визуал; сигналы и обработчики
// добавим на шаге 3, когда подключим C++-контроллер.
Rectangle {
    id: root
    height: Theme.toolbarHeight
    color: Theme.bgSubtle

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
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        ToolBtn { glyph: "\u2630"; glyphSize: 16 }      // ☰ меню

        Divider {}

        FlatBtn   { label: "Сохранить" }
        AccentBtn { label: "Запуск"; glyph: "\u25B6" }   // ▶

        Divider {}

        ToolBtn { glyph: "\u21B6"; glyphSize: 15; glyphColor: Theme.textMuted }  // ↶
        ToolBtn { glyph: "\u21B7"; glyphSize: 15; glyphColor: Theme.textMuted }  // ↷

        Item { Layout.fillWidth: true }

        // ● автосинхронизация
        Row {
            spacing: 7
            Layout.alignment: Qt.AlignVCenter
            Rectangle {
                width: 7; height: 7; radius: 4
                color: Theme.ok
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "автосинхронизация"
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontStatus
                color: Theme.textFaint
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ─────────────── вспомогательные inline-компоненты ───────────────

    component ToolBtn: Rectangle {
        id: tb
        property string glyph: ""
        property int    glyphSize: 16
        property color  glyphColor: Theme.textPrimary

        width: Theme.toolBtnSize
        height: Theme.toolBtnSize
        radius: Theme.rButton
        color: hover.hovered ? "#f4f5f8" : Theme.bgPanel
        border.color: Theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: tb.glyph
            color: tb.glyphColor
            font.family: Theme.fontSans
            font.pixelSize: tb.glyphSize
        }
        HoverHandler { id: hover }
    }

    component FlatBtn: Rectangle {
        id: fb
        property string label: ""
        implicitWidth: txt.implicitWidth + 26
        implicitHeight: Theme.toolBtnSize
        radius: Theme.rButton
        color: hover.hovered ? "#f4f5f8" : Theme.bgPanel
        border.color: Theme.border
        border.width: 1
        Text {
            id: txt
            anchors.centerIn: parent
            text: fb.label
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontToolbar
            font.weight: Font.Medium
            color: Theme.textPrimary
        }
        HoverHandler { id: hover }
    }

    component AccentBtn: Rectangle {
        id: ab
        property string label: ""
        property string glyph: ""
        implicitWidth: row.implicitWidth + 28
        implicitHeight: Theme.toolBtnSize
        radius: Theme.rButton
        color: hover.hovered ? Qt.darker(Theme.accent, 1.06) : Theme.accent
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: ab.glyph
                color: Theme.accentFg
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: ab.label
                color: Theme.accentFg
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontToolbar
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        HoverHandler { id: hover }
    }

    component Divider: Rectangle {
        width: 1
        Layout.preferredHeight: 22
        Layout.alignment: Qt.AlignVCenter
        color: Theme.border
    }
}
