import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import DSLRay

ColumnLayout {
    id: appearance

    function pickColor(propertyName) {
        colorDialog.preferenceName = propertyName
        colorDialog.selectedColor = Preferences[propertyName]
        colorDialog.open()
    }

    ColorDialog {
        id: colorDialog
        property string preferenceName: ""
        onAccepted: Preferences[preferenceName] = selectedColor
    }

    spacing: 12

    // Карточка «Настройки тем» — выбор темы оформления.
    // Сюда же добавляются новые темы помимо светлой/тёмной.
    SettingsCard {
        title: "Настройки тем"
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ThemeCard {
                label: "Светлая"
                themeId: "light"
                swatchBg: "#ffffff"
                swatchPanel: "#f1f3f6"
                swatchAccent: "#4b5bd6"
            }
            ThemeCard {
                label: "Тёмная"
                themeId: "dark"
                swatchBg: "#15171c"
                swatchPanel: "#1e2128"
                swatchAccent: "#7080f0"
            }
            Item { Layout.fillWidth: true }
        }
    }

    // Карточка «Внешний вид кода».
    SettingsCard {
        title: "Внешний вид кода"

        ColorRow {
            label: "Ключ"; sample: "\"ключ\""
            current: Preferences.colorKey
            onPickRequested: appearance.pickColor("colorKey")
        }
        ColorRow {
            label: "Строка (значение)"; sample: "\"текст\""
            current: Preferences.colorString
            onPickRequested: appearance.pickColor("colorString")
        }
        ColorRow {
            label: "Число"; sample: "42"
            current: Preferences.colorNumber
            onPickRequested: appearance.pickColor("colorNumber")
        }
        ColorRow {
            label: "true / false / null"; sample: "true"
            current: Preferences.colorKeyword
            onPickRequested: appearance.pickColor("colorKeyword")
        }
        ColorRow {
            label: "Пунктуация"; sample: "{ } [ ] : ,"
            current: Preferences.colorPunct
            onPickRequested: appearance.pickColor("colorPunct")
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        MenuButton { label: "Сбросить цвета"; onClicked: Preferences.resetColors() }
    }

    Item { Layout.fillHeight: true }

    component SettingsCard: Rectangle {
        id: card
        property string title: ""
        default property alias content: contentColumn.data
        Layout.fillWidth: true
        implicitHeight: contentColumn.implicitHeight + 24
        radius: Theme.rSmall
        color: Theme.bgSubtle
        border.color: Theme.borderSoft
        border.width: 1

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            Text {
                text: card.title
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontContent
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }
        }
    }

    component ThemeCard: Rectangle {
        id: tc
        property string label: ""
        property string themeId: "light"
        property color swatchBg: "#ffffff"
        property color swatchPanel: "#f1f3f6"
        property color swatchAccent: "#4b5bd6"
        readonly property bool active: Preferences.themeId === tc.themeId

        implicitWidth: 124
        implicitHeight: 70
        radius: Theme.rSmall
        color: tc.active ? Theme.accentSoft : (tcHover.hovered ? Theme.hover : Theme.bgPanel)
        border.color: tc.active ? Theme.accent : Theme.border
        border.width: tc.active ? 2 : 1

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6
            // Мини-превью окна темы.
            Rectangle {
                width: parent.width
                height: 30
                radius: 4
                color: tc.swatchBg
                border.color: Theme.border
                border.width: 1
                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4
                    Rectangle { width: 22; height: parent.height; radius: 3; color: tc.swatchPanel }
                    Rectangle { width: parent.width - 22 - 4; height: parent.height; radius: 3; color: tc.swatchPanel
                        Rectangle { x: 4; y: 4; width: 26; height: 4; radius: 2; color: tc.swatchAccent }
                        Rectangle { x: 4; y: 12; width: 40; height: 3; radius: 2; color: tc.swatchAccent; opacity: 0.4 }
                    }
                }
            }
            Text {
                text: tc.label
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontContent
                font.weight: tc.active ? Font.DemiBold : Font.Normal
                color: tc.active ? Theme.accent : Theme.textPrimary
            }
        }
        HoverHandler { id: tcHover }
        TapHandler { onTapped: Preferences.themeId = tc.themeId }
    }

    component ColorRow: RowLayout {
        id: crow
        property string label: ""
        property color current: "black"
        property string sample: ""
        signal pickRequested()
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: crow.label
            Layout.fillWidth: true
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontContent
            color: Theme.textPrimary
        }
        // Образец текущим цветом.
        Text {
            visible: crow.sample.length > 0
            text: crow.sample
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontContent
            font.weight: Font.DemiBold
            color: crow.current
        }
        // Свотч — клик открывает палитру.
        Rectangle {
            implicitWidth: 44
            implicitHeight: 24
            radius: Theme.rSmall
            color: crow.current
            border.color: Theme.border
            border.width: 1
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: crow.pickRequested() }
        }
    }
}
