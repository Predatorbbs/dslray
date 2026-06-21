import QtQuick
import DSLStudio

// Панель «СТРУКТУРА» — дерево блоков текущего .dsl.
// Подпись в шапке — имя активного файла; на шаге 1 захардкожено.
PanelFrame {
    title: "СТРУКТУРА"
    subtitle: "main.dsl"

    Text {
        anchors.centerIn: parent
        text: "структура появится\nпосле разбора файла"
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontContent
        color: Theme.textGhost
    }
}
