import QtQuick
import DSLStudio

// Панель «ПРОЕКТ» — дерево файлов проекта.
// На шаге 1 — пустое тело; реальное TreeView появится на шаге 5
// после подключения QFileSystemModel.
//
// Кнопки «+ папка» / «+ файл» в шапке добавим, когда определимся с
// иконочным набором (Fluent UI / Material Symbols / SVG) — это
// открытый вопрос §7.6 брифа.
PanelFrame {
    title: "ПРОЕКТ"

    Text {
        anchors.centerIn: parent
        text: "проект пока не открыт"
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontContent
        color: Theme.textGhost
    }
}
