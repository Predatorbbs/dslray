import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DSLRay

// Верхний тулбар. Слева — логотип приложения и кнопка-бургер (одного размера и
// скругления), открывающая всплывающее меню. Справа — переключатель тёмной темы.
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

        // Логотип — иконка приложения, того же размера/скругления, что и кнопки.
        Rectangle {
            Layout.preferredWidth: Theme.toolBtnSize
            Layout.preferredHeight: Theme.toolBtnSize
            radius: Theme.rButton
            color: "transparent"
            clip: true
            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: "qrc:/icons/dslray_icon.png"
                sourceSize.width: 96
                sourceSize.height: 96
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
        }

        // ☰ кнопка меню — открывает всплывающее меню приложения.
        ToolBtn {
            glyph: "☰"
            glyphSize: 16
            active: root.menuActive
            onClicked: root.menuClicked()
        }

        Item { Layout.fillWidth: true }

        // Переключатель тёмной темы (☾ — включить тёмную, ☀ — вернуть светлую).
        ToolBtn {
            glyph: Theme.dark ? "☀" : "☾"
            glyphSize: 15
            glyphColor: Theme.dark ? Theme.warn : Theme.textMuted
            tooltip: Theme.dark ? "Светлая тема" : "Тёмная тема"
            onClicked: Docs.themeId = Theme.dark ? "light" : "dark"
        }
    }

    // ─────────────── вспомогательные inline-компоненты ───────────────

    component ToolBtn: Rectangle {
        id: tb
        property string glyph: ""
        property int    glyphSize: 16
        property color  glyphColor: Theme.textPrimary
        property bool   active: false
        property string tooltip: ""
        signal clicked()

        width: Theme.toolBtnSize
        height: Theme.toolBtnSize
        radius: Theme.rButton
        color: tb.active ? Theme.accentSoft
                         : (hover.hovered ? Theme.hover : Theme.bgPanel)
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

        ToolTip.visible: tb.tooltip.length > 0 && hover.hovered
        ToolTip.text: tb.tooltip
        ToolTip.delay: 500
    }
}
