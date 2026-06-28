import QtQuick
import QtQuick.Layouts
import DSLRay

// Нижняя строка состояния. На шаге 1 — все значения захардкожены.
Rectangle {
    id: root
    height: Theme.statusHeight
    color: Theme.bgSubtle

    // верхняя граница
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.divider
    }

    // Захардкоженные значения — заменим на реальные после шагов 4–6.
    property string userName:    "designer"
    property string userInitial: "D"
    property string fileName:    "main.dsl"
    property int    lineCount:   42
    property int    charCount:   1180
    property int    tokenCount:  340
    property string appVersion:  "0.2.0"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        // Пользователь
        Row {
            spacing: 7
            Layout.alignment: Qt.AlignVCenter
            Rectangle {
                width: 18; height: 18; radius: 9
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: root.userInitial
                    color: Theme.accentFg
                    font.family: Theme.fontSans
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }
            Text {
                text: root.userName
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontStatus
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        VSep {}

        StatusText { text: root.fileName }

        Item { Layout.fillWidth: true }

        StatusText { text: "строк: " + root.lineCount }
        StatusText { text: "символов: " + root.charCount }
        StatusText { text: "≈ " + root.tokenCount + " токенов" }

        VSep {}

        StatusText { text: "v" + root.appVersion }
    }

    component StatusText: Text {
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontStatus
        color: Theme.textFaint
        Layout.alignment: Qt.AlignVCenter
    }

    component VSep: Rectangle {
        width: 1
        Layout.preferredHeight: 13
        Layout.alignment: Qt.AlignVCenter
        color: Theme.border
    }
}
