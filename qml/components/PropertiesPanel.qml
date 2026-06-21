import QtQuick
import DSLStudio

// Панель «СВОЙСТВА» — атрибуты выделенного блока.
// На шаге 1 — пусто. Реальные поля появятся на шаге 9.
PanelFrame {
    title: "СВОЙСТВА"

    Text {
        anchors.centerIn: parent
        text: "ничего не выделено"
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontContent
        color: Theme.textGhost
    }
}
