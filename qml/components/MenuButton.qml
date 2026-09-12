import QtQuick
import DSLRay

Rectangle {
    id: db
    property string label: ""
    property bool accent: false
    property bool danger: false
    signal clicked()
    implicitWidth: dbText.implicitWidth + 26
    implicitHeight: 30
    radius: Theme.rButton
    color: db.accent ? (dbHover.hovered ? Qt.darker(Theme.accent, 1.06) : Theme.accent)
                     : (dbHover.hovered ? "#f4f5f8" : Theme.bgPanel)
    border.color: db.accent ? Theme.accent : (db.danger ? Theme.err : Theme.border)
    border.width: 1
    Text {
        id: dbText
        anchors.centerIn: parent
        text: db.label
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontToolbar
        font.weight: Font.Medium
        color: db.accent ? Theme.accentFg : (db.danger ? Theme.err : Theme.textPrimary)
    }
    HoverHandler { id: dbHover }
    TapHandler { onTapped: db.clicked() }
}
