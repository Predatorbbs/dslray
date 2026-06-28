import QtQuick
import QtQuick.Layouts
import DSLRay

// Нижняя строка состояния. Профиль (аватар/имя) берётся из настроек (Docs),
// счётчики строк/символов/токенов — живые, приходят из редактора через Main.
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

    // Профиль — из настроек пользователя.
    readonly property string userName:    Docs.userName.length > 0 ? Docs.userName : "—"
    readonly property string userInitial: userName.charAt(0).toUpperCase()
    readonly property url    avatarUrl:   Docs.avatarPath

    // Счётчики активного файла (живые) — задаются владельцем (Main).
    property string fileName:    ""
    property int    lineCount:   0
    property int    charCount:   0
    property int    tokenCount:  0
    property string appVersion:  "0.3.0"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        // Пользователь
        Row {
            spacing: 7
            Layout.alignment: Qt.AlignVCenter

            // Аватар: загруженная картинка или кружок с инициалом.
            Rectangle {
                width: 18; height: 18; radius: 9
                color: Theme.accent
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    visible: root.avatarUrl == ""
                    text: root.userInitial
                    color: Theme.accentFg
                    font.family: Theme.fontSans
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
                Image {
                    anchors.fill: parent
                    visible: root.avatarUrl != ""
                    source: root.avatarUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
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

        StatusText { text: root.fileName; color: Theme.textMuted }

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
