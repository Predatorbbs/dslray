import QtQuick
import DSLStudio

// Панель «КОД» — текстовый редактор .dsl-файла.
// На шаге 1 — только рамка и подпись. Реальный TextArea с
// моноширинным шрифтом, нумерацией и подсветкой появится на шаге 4.
PanelFrame {
    title: "КОД"
    subtitle: "main.dsl"

    Text {
        anchors.centerIn: parent
        text: "редактор кода"
        font.family: Theme.fontMono
        font.pixelSize: 13
        color: Theme.textGhost
    }
}
