import QtQuick
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
            { title: "Проект",      hint: "Открытие, создание и настройки проекта" },
            { title: "Редактор кода", hint: "Режим записи изменений в файл" },
            { title: "Внешний вид", hint: "Тема и цветовая схема приложения" },
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

                    Text {
                        text: popup.sections[popup.selectedIndex].title
                        font.family: Theme.fontSans
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                    Text {
                        text: popup.sections[popup.selectedIndex].hint
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontContent
                        color: Theme.textMuted
                    }

                    // Раздел «Редактор кода» — переключатель режима записи.
                    ColumnLayout {
                        visible: popup.selectedIndex === 1
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

                        Item { Layout.fillHeight: true }
                    }

                    // Прочие разделы — заглушка.
                    Rectangle {
                        visible: popup.selectedIndex !== 1
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
