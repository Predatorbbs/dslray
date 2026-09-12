import QtQuick
import QtQuick.Layouts
import DSLRay

ColumnLayout {
    id: editorSettings
    signal toggleSafeRequested()

    spacing: 12

    // Безопасный режим.
    CheckRow {
        label: "Безопасный режим"
        checked: Docs.safeMode
        onToggled: editorSettings.toggleSafeRequested()
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: Docs.safeMode
              ? "Все вносимые изменения будут применены к файлу только после сохранения."
              : "Все вносимые изменения тут же будут перезаписывать файл на лету."
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontContent
        color: Theme.textMuted
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        visible: Docs.safeMode
        text: "Сохранить активный файл — Ctrl+S."
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontPanelHeader
        color: Theme.textFaint
    }

    // Перенос текста по строкам.
    CheckRow {
        label: "Перенос текста по строкам"
        checked: Preferences.wordWrap
        onToggled: Preferences.wordWrap = !Preferences.wordWrap
    }

    StepperRow {
        label: "Размер шрифта кода"
        value: Preferences.codeFontSize
        onStepped: function (delta) { Preferences.codeFontSize += delta }
    }

    // Тип отступа: табы / пробелы.
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: "Тип отступа"
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontContent
            font.weight: Font.Medium
            color: Theme.textPrimary
        }
        SegBtn {
            label: "Пробелы"
            active: !Preferences.indentUseTabs
            onClicked: Preferences.indentUseTabs = false
        }
        SegBtn {
            label: "Табы"
            active: Preferences.indentUseTabs
            onClicked: Preferences.indentUseTabs = true
        }
    }

    StepperRow {
        label: "Ширина отступа"
        value: Preferences.indentWidth
        onStepped: function (delta) { Preferences.indentWidth += delta }
    }

    Item { Layout.fillHeight: true }

    component CheckRow: Rectangle {
        id: cr
        property string label: ""
        property bool checked: false
        signal toggled()
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Theme.rSmall
        color: crHover.hovered ? "#f4f5f8" : Theme.bgSubtle
        border.color: Theme.border
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Rectangle {
                width: 18; height: 18; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: cr.checked ? Theme.accent : Theme.bgPanel
                border.color: cr.checked ? Theme.accent : Theme.border
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    visible: cr.checked
                    text: "✓"
                    font.pixelSize: 12
                    color: Theme.accentFg
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cr.label
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontContent
                font.weight: Font.Medium
                color: Theme.textPrimary
            }
        }
        HoverHandler { id: crHover }
        TapHandler { onTapped: cr.toggled() }
    }

    component StepperRow: RowLayout {
        id: stepper
        property string label: ""
        property int value: 0
        signal stepped(int delta)
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: stepper.label
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontContent
            font.weight: Font.Medium
            color: Theme.textPrimary
        }
        StepperBtn { glyph: "−"; onClicked: stepper.stepped(-1) }
        Text {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignHCenter
            text: stepper.value
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontContent
            font.weight: Font.DemiBold
            color: Theme.textPrimary
        }
        StepperBtn { glyph: "+"; onClicked: stepper.stepped(1) }
    }

    component SegBtn: Rectangle {
        id: seg
        property string label: ""
        property bool active: false
        signal clicked()
        implicitWidth: segText.implicitWidth + 22
        implicitHeight: 26
        radius: Theme.rSmall
        color: seg.active ? Qt.alpha(Theme.accent, 0.12)
                          : (segHover.hovered ? "#f0f1f4" : Theme.bgPanel)
        border.color: seg.active ? Theme.accent : Theme.border
        border.width: 1
        Text {
            id: segText
            anchors.centerIn: parent
            text: seg.label
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontToolbar
            font.weight: seg.active ? Font.DemiBold : Font.Normal
            color: seg.active ? Theme.accent : Theme.textMuted
        }
        HoverHandler { id: segHover }
        TapHandler { onTapped: seg.clicked() }
    }

    component StepperBtn: Rectangle {
        id: sb
        property string glyph: ""
        signal clicked()
        implicitWidth: 28
        implicitHeight: 26
        radius: Theme.rSmall
        color: sbHover.hovered ? "#f0f1f4" : Theme.bgPanel
        border.color: Theme.border
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: sb.glyph
            font.family: Theme.fontSans
            font.pixelSize: 16
            color: Theme.textMuted
        }
        HoverHandler { id: sbHover }
        TapHandler { onTapped: sb.clicked() }
    }
}
