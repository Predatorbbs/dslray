import QtQuick
import QtQuick.Layouts
import DSLRay

// Верхний тулбар (строка меню). На этом шаге — только кнопка-бургер слева,
// открывающая всплывающее меню (см. MenuOverlay), и индикатор автосинхронизации
// справа. Остальные действия переедут внутрь попапа-меню.
Rectangle {
    id: root
    height: Theme.toolbarHeight
    color: Theme.bgSubtle

    // Подсветка кнопки-бургера, когда меню открыто.
    property bool menuActive: false
    // Нажатие на бургер — наружу: владелец решает, открыть/закрыть попап.
    signal menuClicked()

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

        // ☰ кнопка меню — открывает всплывающее меню приложения.
        ToolBtn {
            glyph: "☰"          // ☰
            glyphSize: 16
            active: root.menuActive
            onClicked: root.menuClicked()
        }

        Item { Layout.fillWidth: true }
    }

    // ─────────────── вспомогательные inline-компоненты ───────────────

    component ToolBtn: Rectangle {
        id: tb
        property string glyph: ""
        property int    glyphSize: 16
        property color  glyphColor: Theme.textPrimary
        property bool   active: false
        signal clicked()

        width: Theme.toolBtnSize
        height: Theme.toolBtnSize
        radius: Theme.rButton
        color: tb.active ? Qt.alpha(Theme.accent, 0.12)
                         : (hover.hovered ? "#f4f5f8" : Theme.bgPanel)
        border.color: tb.active ? Theme.accent : Theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: tb.glyph
            color: tb.active ? Theme.accent : tb.glyphColor
            font.family: Theme.fontSans
            font.pixelSize: tb.glyphSize
        }
        HoverHandler { id: hover }
        TapHandler { onTapped: tb.clicked() }
    }
}
