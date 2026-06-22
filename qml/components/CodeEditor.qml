import QtQuick
import DSLRay

// Панель «КОД» — текстовый редактор .dsl-файла.
// На шаге 1 — только рамка и подпись. Реальный TextArea с
// моноширинным шрифтом, нумерацией и подсветкой появится на шаге 4.
PanelFrame {
    title: "КОД"
    subtitle: Docs.hasDocuments ? Docs.activeName : ""

    Text {
        anchors.centerIn: parent
        text: Docs.hasDocuments ? Docs.activeName : "откройте файл"
        font.family: Theme.fontMono
        font.pixelSize: 13
        color: Theme.textGhost
    }
}
