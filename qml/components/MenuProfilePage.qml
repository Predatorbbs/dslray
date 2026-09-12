import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import DSLRay

ColumnLayout {
    spacing: 16

    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        // Превью аватара (картинка или инициал).
        Rectangle {
            width: 64; height: 64; radius: 32
            color: Theme.accent
            clip: true
            border.color: Theme.border; border.width: 1
            Text {
                anchors.centerIn: parent
                visible: Preferences.avatarPath == ""
                text: Preferences.userName.length > 0 ? Preferences.userName.charAt(0).toUpperCase() : "—"
                color: Theme.accentFg
                font.family: Theme.fontSans
                font.pixelSize: 26
                font.weight: Font.Bold
            }
            Image {
                anchors.fill: parent
                visible: Preferences.avatarPath != ""
                source: Preferences.avatarPath
                fillMode: Image.PreserveAspectCrop
                smooth: true; mipmap: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                spacing: 8
                MenuButton { label: "Сменить аватар"; onClicked: avatarDlg.open() }
                MenuButton {
                    label: "Убрать"
                    visible: Preferences.avatarPath != ""
                    onClicked: Preferences.avatarPath = ""
                }
                Item { Layout.fillWidth: true }
            }
            Text {
                text: "PNG/JPG · отображается в статус-баре"
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontPanelHeader
                color: Theme.textFaint
            }
        }
    }

    ProfileField {
        label: "Имя"
        text: Preferences.userName
        placeholderText: "Ваше имя"
        onCommitted: function (value) { Preferences.userName = value }
    }

    ProfileField {
        label: "Почта"
        text: Preferences.userEmail
        placeholderText: "name@example.com"
        onCommitted: function (value) { Preferences.userEmail = value }
    }

    Item { Layout.fillHeight: true }

    FileDialog {
        id: avatarDlg
        title: "Выберите аватар"
        nameFilters: ["Изображения (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: Preferences.avatarPath = avatarDlg.selectedFile
    }

    component ProfileField: ColumnLayout {
        id: field
        property string label: ""
        property alias text: input.text
        property alias placeholderText: input.placeholderText
        signal committed(string value)
        Layout.fillWidth: true
        spacing: 5

        Text {
            text: field.label
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontPanelHeader
            font.weight: Font.Medium
            color: Theme.textMuted
        }
        TextField {
            id: input
            Layout.fillWidth: true
            implicitHeight: 34
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontContent
            color: Theme.textPrimary
            placeholderTextColor: Theme.textGhost
            selectByMouse: true
            leftPadding: 10; rightPadding: 10
            background: Rectangle {
                radius: Theme.rSmall
                color: Theme.bgPanel
                border.color: input.activeFocus ? Theme.accent : Theme.border
                border.width: 1
            }
            onEditingFinished: field.committed(input.text)
        }
    }
}
