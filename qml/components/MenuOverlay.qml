import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import DSLRay

// Всплывающее меню приложения. Занимает всё окно: затемняет фон и кладёт
// по центру попап в цветовой схеме приложения. Слева — разделы меню,
// справа — свойства выбранного раздела.
//
// Открытием/закрытием управляет владелец через свойство `open`. Закрыть
// можно кликом по затемнённому фону или клавишей Esc; повторное нажатие
// на кнопку-бургер обрабатывает владелец.
Item {
    id: root

    property bool open: false
    signal closeRequested()

    // Открыт ли диалог подтверждения при выключении «Безопасного режима».
    property bool confirmOpen: false

    anchors.fill: parent
    visible: opacity > 0
    opacity: open ? 1 : 0
    z: 1000

    Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

    // Запрос на переключение режима. Включение — сразу; выключение при наличии
    // несохранённых черновиков — через подтверждение.
    function requestToggleSafe() {
        if (Docs.safeMode) {
            if (Docs.hasUnsavedChanges())
                root.confirmOpen = true
            else
                Docs.setSafeMode(false)
        } else {
            Docs.setSafeMode(true)
        }
    }

    // Перехватываем все события, пока меню открыто (фон-блокер).
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        hoverEnabled: true
        onClicked: root.closeRequested()
    }

    // Затемняющая подложка.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.42
    }

    // ── Попап ─────────────────────────────────────────────────────────
    Rectangle {
        id: popup
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 760)
        height: Math.min(parent.height - 120, 480)
        radius: Theme.rCard
        color: Theme.bgPanel
        border.color: Theme.border
        border.width: 1

        // Лёгкий подъём при открытии.
        scale: root.open ? 1 : 0.97
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        // Клик внутри попапа не должен закрывать меню.
        MouseArea { anchors.fill: parent }

        property int selectedIndex: 0
        readonly property var sections: [
            { title: "Пользователь", hint: "Имя, почта и аватар профиля" },
            { title: "Проект",      hint: "Открытие, создание и настройки проекта" },
            { title: "Редактор кода", hint: "Режим записи изменений в файл" },
            { title: "Внешний вид", hint: "Темы оформления и цвета подсветки кода" },
            { title: "О программе", hint: "Версия и сведения о DSLRay" }
        ]

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ── Левая колонка: разделы ────────────────────────────────
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 230
                color: Theme.bgSubtle
                topLeftRadius: Theme.rCard
                bottomLeftRadius: Theme.rCard

                // правая граница-разделитель
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.border
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: "МЕНЮ"
                        Layout.leftMargin: 6
                        Layout.bottomMargin: 6
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontPanelHeader
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.letterSpacingHeader
                        color: Theme.textFaint
                    }

                    Repeater {
                        model: popup.sections
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.rButton
                            color: popup.selectedIndex === index
                                   ? Qt.alpha(Theme.accent, 0.12)
                                   : (secHover.hovered ? "#eef0f3" : "transparent")

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                text: modelData.title
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontContent
                                font.weight: popup.selectedIndex === index ? Font.DemiBold : Font.Normal
                                color: popup.selectedIndex === index ? Theme.accent : Theme.textPrimary
                            }
                            HoverHandler { id: secHover }
                            TapHandler { onTapped: popup.selectedIndex = index }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ── Правая колонка: свойства раздела ──────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 10

                    // «О программе» рисует собственную шапку (иконка + название),
                    // поэтому стандартный заголовок раздела для неё скрыт.
                    Text {
                        visible: popup.selectedIndex !== 4
                        text: popup.sections[popup.selectedIndex].title
                        font.family: Theme.fontSans
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                    Text {
                        visible: popup.selectedIndex !== 4
                        text: popup.sections[popup.selectedIndex].hint
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontContent
                        color: Theme.textMuted
                    }

                    // ── Раздел «Пользователь» — имя, почта, аватар ────────
                    ColumnLayout {
                        visible: popup.selectedIndex === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            // Превью аватара (картинка или инициал).
                            Rectangle {
                                width: 64; height: 64; radius: 32
                                color: Theme.accent
                                clip: true
                                border.color: Theme.border; border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    visible: Docs.avatarPath == ""
                                    text: Docs.userName.length > 0 ? Docs.userName.charAt(0).toUpperCase() : "—"
                                    color: Theme.accentFg
                                    font.family: Theme.fontSans
                                    font.pixelSize: 26
                                    font.weight: Font.Bold
                                }
                                Image {
                                    anchors.fill: parent
                                    visible: Docs.avatarPath != ""
                                    source: Docs.avatarPath
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true; mipmap: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                RowLayout {
                                    spacing: 8
                                    DlgBtn { label: "Сменить аватар"; onClicked: avatarDlg.open() }
                                    DlgBtn {
                                        label: "Убрать"
                                        visible: Docs.avatarPath != ""
                                        onClicked: Docs.avatarPath = ""
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                                Text {
                                    text: "PNG/JPG · отображается в статус-баре"
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontPanelHeader
                                    color: Theme.textFaint
                                }
                            }
                        }

                        // Имя
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Text {
                                text: "Имя"
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontPanelHeader
                                font.weight: Font.Medium
                                color: Theme.textMuted
                            }
                            UserField {
                                text: Docs.userName
                                placeholderText: "Ваше имя"
                                onCommitted: function (v) { Docs.userName = v }
                            }
                        }

                        // Почта
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Text {
                                text: "Почта"
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontPanelHeader
                                font.weight: Font.Medium
                                color: Theme.textMuted
                            }
                            UserField {
                                text: Docs.userEmail
                                placeholderText: "name@example.com"
                                onCommitted: function (v) { Docs.userEmail = v }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        FileDialog {
                            id: avatarDlg
                            title: "Выберите аватар"
                            nameFilters: ["Изображения (*.png *.jpg *.jpeg *.webp *.bmp)"]
                            onAccepted: Docs.avatarPath = avatarDlg.selectedFile
                        }
                    }

                    // Раздел «Редактор кода» — переключатель режима записи.
                    ColumnLayout {
                        visible: popup.selectedIndex === 2
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        // Безопасный режим.
                        CheckRow {
                            label: "Безопасный режим"
                            checked: Docs.safeMode
                            onToggled: root.requestToggleSafe()
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
                            checked: Docs.wordWrap
                            onToggled: Docs.wordWrap = !Docs.wordWrap
                        }

                        // Размер шрифта кода (14…32).
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                Layout.fillWidth: true
                                text: "Размер шрифта кода"
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontContent
                                font.weight: Font.Medium
                                color: Theme.textPrimary
                            }
                            StepperBtn { glyph: "−"; onClicked: Docs.codeFontSize = Docs.codeFontSize - 1 }
                            Text {
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignHCenter
                                text: Docs.codeFontSize
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontContent
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            StepperBtn { glyph: "+"; onClicked: Docs.codeFontSize = Docs.codeFontSize + 1 }
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
                                active: !Docs.indentUseTabs
                                onClicked: Docs.indentUseTabs = false
                            }
                            SegBtn {
                                label: "Табы"
                                active: Docs.indentUseTabs
                                onClicked: Docs.indentUseTabs = true
                            }
                        }

                        // Ширина отступа (1…8).
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                Layout.fillWidth: true
                                text: "Ширина отступа"
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontContent
                                font.weight: Font.Medium
                                color: Theme.textPrimary
                            }
                            StepperBtn { glyph: "−"; onClicked: Docs.indentWidth = Docs.indentWidth - 1 }
                            Text {
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignHCenter
                                text: Docs.indentWidth
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontContent
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }
                            StepperBtn { glyph: "+"; onClicked: Docs.indentWidth = Docs.indentWidth + 1 }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // ── Раздел «О программе» ──────────────────────────────
                    ColumnLayout {
                        id: about
                        visible: popup.selectedIndex === 4
                        Layout.fillWidth: true
                        Layout.fillHeight: true
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

                    // ── Раздел «Внешний вид» — темы + цвета подсветки кода ─
                    ColumnLayout {
                        visible: popup.selectedIndex === 3
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        // Карточка «Настройки тем» — выбор темы оформления.
                        // Сюда же добавляются новые темы помимо светлой/тёмной.
                        Rectangle {
                            Layout.fillWidth: true
                            radius: Theme.rSmall
                            color: Theme.bgSubtle
                            border.color: Theme.borderSoft
                            border.width: 1
                            implicitHeight: themeCol.implicitHeight + 24

                            ColumnLayout {
                                id: themeCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 10

                                Text {
                                    text: "Настройки тем"
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontContent
                                    font.weight: Font.DemiBold
                                    color: Theme.textPrimary
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    ThemeCard {
                                        label: "Светлая"
                                        themeId: "light"
                                        swatchBg: "#ffffff"
                                        swatchPanel: "#f1f3f6"
                                        swatchAccent: "#4b5bd6"
                                    }
                                    ThemeCard {
                                        label: "Тёмная"
                                        themeId: "dark"
                                        swatchBg: "#15171c"
                                        swatchPanel: "#1e2128"
                                        swatchAccent: "#7080f0"
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }

                        // Карточка «Внешний вид кода».
                        Rectangle {
                            Layout.fillWidth: true
                            radius: Theme.rSmall
                            color: Theme.bgSubtle
                            border.color: Theme.borderSoft
                            border.width: 1
                            implicitHeight: appCol.implicitHeight + 24

                            ColumnLayout {
                                id: appCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 10

                                Text {
                                    text: "Внешний вид кода"
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontContent
                                    font.weight: Font.DemiBold
                                    color: Theme.textPrimary
                                }

                                ColorRow {
                                    label: "Ключ"; sample: "\"ключ\""
                                    current: Docs.colorKey
                                    onPicked: function (c) { Docs.colorKey = c }
                                }
                                ColorRow {
                                    label: "Строка (значение)"; sample: "\"текст\""
                                    current: Docs.colorString
                                    onPicked: function (c) { Docs.colorString = c }
                                }
                                ColorRow {
                                    label: "Число"; sample: "42"
                                    current: Docs.colorNumber
                                    onPicked: function (c) { Docs.colorNumber = c }
                                }
                                ColorRow {
                                    label: "true / false / null"; sample: "true"
                                    current: Docs.colorKeyword
                                    onPicked: function (c) { Docs.colorKeyword = c }
                                }
                                ColorRow {
                                    label: "Пунктуация"; sample: "{ } [ ] : ,"
                                    current: Docs.colorPunct
                                    onPicked: function (c) { Docs.colorPunct = c }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            DlgBtn { label: "Сбросить цвета"; onClicked: Docs.resetColors() }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // Прочие разделы — заглушка.
                    Rectangle {
                        visible: popup.selectedIndex !== 0 && popup.selectedIndex !== 2
                                 && popup.selectedIndex !== 3 && popup.selectedIndex !== 4
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.rSmall
                        color: Theme.bgWorkspace
                        border.color: Theme.borderSoft
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "свойства раздела появятся здесь"
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontContent
                            color: Theme.textGhost
                        }
                    }
                }

                // Кнопка закрытия в правом верхнем углу.
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 12
                    anchors.rightMargin: 12
                    width: 26; height: 26
                    radius: Theme.rSmall
                    color: closeHover.hovered ? "#f0f1f4" : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }
                    HoverHandler { id: closeHover }
                    TapHandler { onTapped: root.closeRequested() }
                }
            }
        }
    }

    // ── Диалог подтверждения при выключении «Безопасного режима» ───────
    Item {
        anchors.fill: parent
        visible: root.confirmOpen
        z: 10

        // Блокер кликов мимо диалога.
        MouseArea { anchors.fill: parent }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.28 }

        Rectangle {
            anchors.centerIn: parent
            width: 420
            implicitHeight: dlgCol.implicitHeight + 36
            radius: Theme.rCard
            color: Theme.bgPanel
            border.color: Theme.border
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: dlgCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                Text {
                    text: "Несохранённые изменения"
                    font.family: Theme.fontSans
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Есть черновики с несохранёнными правками. Применить их к файлам перед выключением «Безопасного режима»?"
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontContent
                    color: Theme.textMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    DlgBtn {
                        label: "Отмена"
                        onClicked: root.confirmOpen = false
                    }
                    Item { Layout.fillWidth: true }
                    DlgBtn {
                        label: "Отбросить"
                        danger: true
                        onClicked: {
                            Docs.discardAllDrafts()
                            Docs.setSafeMode(false)
                            root.confirmOpen = false
                        }
                    }
                    DlgBtn {
                        label: "Применить"
                        accent: true
                        onClicked: {
                            Docs.applyAllDrafts()
                            Docs.setSafeMode(false)
                            root.confirmOpen = false
                        }
                    }
                }
            }
        }
    }

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

    component UserField: TextField {
        id: uf
        signal committed(string value)
        Layout.fillWidth: true
        implicitHeight: 34
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontContent
        color: Theme.textPrimary
        placeholderTextColor: Theme.textGhost
        selectByMouse: true
        leftPadding: 10; rightPadding: 10
        background: Rectangle {
            radius: Theme.rSmall
            color: Theme.bgPanel
            border.color: uf.activeFocus ? Theme.accent : Theme.border
            border.width: 1
        }
        onEditingFinished: uf.committed(uf.text)
    }

    component ThemeCard: Rectangle {
        id: tc
        property string label: ""
        property string themeId: "light"
        property color swatchBg: "#ffffff"
        property color swatchPanel: "#f1f3f6"
        property color swatchAccent: "#4b5bd6"
        readonly property bool active: Docs.themeId === tc.themeId

        implicitWidth: 124
        implicitHeight: 70
        radius: Theme.rSmall
        color: tc.active ? Theme.accentSoft : (tcHover.hovered ? Theme.hover : Theme.bgPanel)
        border.color: tc.active ? Theme.accent : Theme.border
        border.width: tc.active ? 2 : 1

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6
            // Мини-превью окна темы.
            Rectangle {
                width: parent.width
                height: 30
                radius: 4
                color: tc.swatchBg
                border.color: Theme.border
                border.width: 1
                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4
                    Rectangle { width: 22; height: parent.height; radius: 3; color: tc.swatchPanel }
                    Rectangle { width: parent.width - 22 - 4; height: parent.height; radius: 3; color: tc.swatchPanel
                        Rectangle { x: 4; y: 4; width: 26; height: 4; radius: 2; color: tc.swatchAccent }
                        Rectangle { x: 4; y: 12; width: 40; height: 3; radius: 2; color: tc.swatchAccent; opacity: 0.4 }
                    }
                }
            }
            Text {
                text: tc.label
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontContent
                font.weight: tc.active ? Font.DemiBold : Font.Normal
                color: tc.active ? Theme.accent : Theme.textPrimary
            }
        }
        HoverHandler { id: tcHover }
        TapHandler { onTapped: Docs.themeId = tc.themeId }
    }

    component ColorRow: RowLayout {
        id: crow
        property string label: ""
        property color current: "black"
        property string sample: ""
        signal picked(color c)
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: crow.label
            Layout.fillWidth: true
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontContent
            color: Theme.textPrimary
        }
        // Образец текущим цветом.
        Text {
            visible: crow.sample.length > 0
            text: crow.sample
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontContent
            font.weight: Font.DemiBold
            color: crow.current
        }
        // Свотч — клик открывает палитру.
        Rectangle {
            implicitWidth: 44
            implicitHeight: 24
            radius: Theme.rSmall
            color: crow.current
            border.color: Theme.border
            border.width: 1
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    colorDlg.selectedColor = crow.current
                    colorDlg.open()
                }
            }
        }
        ColorDialog {
            id: colorDlg
            onAccepted: crow.picked(colorDlg.selectedColor)
        }
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

    component DlgBtn: Rectangle {
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

    // Esc закрывает меню (или сперва диалог подтверждения).
    Keys.onEscapePressed: {
        if (root.confirmOpen) root.confirmOpen = false
        else                  root.closeRequested()
    }
    focus: root.open
}
