import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DSLRay

ColumnLayout {
    id: about
    spacing: 16

    // История версий. Свежие — сверху.
    readonly property var changelog: [
        {
            ver: "0.3",
            tag: "DeepAlpha",
            date: "июнь 2026",
            items: [
                "Тёмная тема и переключатель в тулбаре; реактивная система тем.",
                "Раздел «Настройки тем» с превью светлой и тёмной темы.",
                "Обновлённый тулбар: логотип приложения и кнопка меню.",
                "Вкладки в новом стиле – акцентное подчёркивание активной.",
                "Раздел «Пользователь»: имя, почта и аватар (виден в статус-баре).",
                "Живые счётчики строк, символов и токенов активного файла.",
                "Видимая мигающая каретка и надёжная прогрузка текста вкладок."
            ]
        },
        {
            ver: "0.2",
            tag: "DeepAlpha",
            date: "июнь 2026",
            items: [
                "Подсветка текущей строки — на всю логическую строку, включая перенос.",
                "Парные скобки: подсветка пары и акцентная вертикаль между ними от начала текста строки.",
                "Базовая проверка синтаксиса: подсветка несбалансированных скобок и незакрытых строк.",
                "Вертикальные направляющие вложений.",
                "Авто-отступ по структуре при Enter; тип отступа (табы/пробелы) и его ширина в настройках.",
                "Кнопка «Форматировать отступы» — выравнивание всего документа по глубине вложенности.",
                "Висячий отступ переноса: продолжение строки держит уровень вложенности (файл не меняется).",
                "Настраиваемые цвета подсветки (ключ/строка/число/литералы/пунктуация) — блок «Внешний вид кода».",
                "Ускоренная прокрутка колесом и слежение вьюпорта за кареткой.",
                "Защита редактора от слишком больших файлов."
            ]
        },
        {
            ver: "0.1",
            tag: "DeepAlpha",
            date: "июнь 2026",
            items: [
                "Дерево проекта на собственной модели: drag-and-drop, переименование, удаление с подтверждением.",
                "Редактор кода: подсветка JSON, нумерация строк, перенос по словам, регулировка размера шрифта.",
                "Панель «Структура»: навигация по объектам elementName с подсветкой пройденного.",
                "Режимы записи «Прозрачный» и «Безопасный» (черновики + сохранение по Ctrl+S).",
                "Восстановление сессии: открытый проект и вкладки между запусками.",
                "Иконка приложения и экран «О программе»."
            ]
        },
        {
            ver: "0.0",
            tag: "каркас",
            date: "ранние сборки",
            items: [
                "Скелет приложения на Qt 6 / QML, раскладка из панелей на SplitView.",
                "Контроллеры проекта и документов, связь C++ ↔ QML через контекстные свойства."
            ]
        }
    ]

    // Шапка: иконка + название + версия.
    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        Image {
            source: "qrc:/icons/dslray_icon.png"
            sourceSize.width: 200
            sourceSize.height: 200
            Layout.preferredWidth: 72
            Layout.preferredHeight: 72
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "DSLRay"
                font.family: Theme.fontSans
                font.pixelSize: 26
                font.weight: Font.Bold
                color: Theme.textPrimary
            }
            RowLayout {
                spacing: 8
                // Пилюля с номером версии.
                Rectangle {
                    implicitWidth: verText.implicitWidth + 18
                    implicitHeight: 22
                    radius: 11
                    color: Qt.alpha(Theme.accent, 0.12)
                    Text {
                        id: verText
                        anchors.centerIn: parent
                        text: "Версия 0.3"
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontPanelHeader
                        font.weight: Font.DemiBold
                        color: Theme.accent
                    }
                }
                Text {
                    text: "DeepAlpha"
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontContent
                    font.weight: Font.Medium
                    color: Theme.textMuted
                }
            }
        }
    }

    // Описание.
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "IDE для помощи в написании json-based DSL для работы с AI."
        font.family: Theme.fontSans
        font.pixelSize: 14
        lineHeight: 1.25
        color: Theme.textPrimary
    }

    // Подпись к списку изменений.
    Text {
        Layout.topMargin: 2
        text: "ИЗМЕНЕНИЯ"
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontPanelHeader
        font.weight: Font.Bold
        font.letterSpacing: Theme.letterSpacingHeader
        color: Theme.textFaint
    }

    // ── Скроллируемый список Changelog ────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.rSmall
        color: Theme.bgSubtle
        border.color: Theme.borderSoft
        border.width: 1
        clip: true

        ListView {
            id: clList
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: about.changelog

            ScrollBar.vertical: ScrollBar {
                policy: clList.contentHeight > clList.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: Item {
                required property var modelData
                required property int index
                width: clList.width
                implicitHeight: entryCol.implicitHeight + 24

                ColumnLayout {
                    id: entryCol
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 8

                    // Заголовок записи: версия + кодовое имя + дата.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: modelData.ver
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontContent
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                        }
                        Text {
                            text: modelData.tag
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontPanelHeader
                            font.weight: Font.DemiBold
                            color: Theme.accent
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modelData.date
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontPanelHeader
                            color: Theme.textFaint
                        }
                    }

                    // Пункты изменений.
                    Repeater {
                        model: modelData.items
                        delegate: RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                Layout.topMargin: 6
                                Layout.alignment: Qt.AlignTop
                                width: 4; height: 4; radius: 2
                                color: Theme.textGhost
                            }
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: modelData
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontContent
                                lineHeight: 1.2
                                color: Theme.textMuted
                            }
                        }
                    }
                }

                // Разделитель между записями (кроме последней).
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Theme.divider
                    visible: index < clList.count - 1
                }
            }
        }
    }
}
