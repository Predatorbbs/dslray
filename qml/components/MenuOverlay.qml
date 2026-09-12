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
    objectName: "applicationMenu"

    property bool open: false
    onOpenChanged: loadSelectedPage()

    function loadSelectedPage() {
        if (!root.open) return
        const pages = [profilePage, null, editorPage, appearancePage, aboutPage]
        const page = pages[popup.selectedIndex]
        if (page) page.active = true
    }

    Component.onCompleted: loadSelectedPage()
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
        Docs.flushRequested()
        if (Docs.safeMode) {
            if (Docs.hasUnsavedChanges())
                root.confirmOpen = true
            else
                Docs.safeMode = false
        } else {
            Docs.safeMode = true
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
        objectName: "popup"
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
        onSelectedIndexChanged: root.loadSelectedPage()
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

                    // Pages are created on first visit and retained so fields and
                    // changelog scrolling survive switching sections.
                    PageLoader {
                        id: profilePage
                        objectName: "profilePage"
                        visible: popup.selectedIndex === 0
                        source: "MenuProfilePage.qml"
                    }
                    PageLoader {
                        id: editorPage
                        objectName: "editorPage"
                        visible: popup.selectedIndex === 2
                        source: "MenuEditorPage.qml"
                    }
                    Connections {
                        target: editorPage.item
                        function onToggleSafeRequested() { root.requestToggleSafe() }
                    }
                    PageLoader {
                        id: appearancePage
                        objectName: "appearancePage"
                        visible: popup.selectedIndex === 3
                        source: "MenuAppearancePage.qml"
                    }
                    PageLoader {
                        id: aboutPage
                        objectName: "aboutPage"
                        visible: popup.selectedIndex === 4
                        source: "MenuAboutPage.qml"
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

                    MenuButton {
                        label: "Отмена"
                        onClicked: root.confirmOpen = false
                    }
                    Item { Layout.fillWidth: true }
                    MenuButton {
                        label: "Отбросить"
                        danger: true
                        onClicked: {
                            if (Docs.discardAllDrafts()) {
                                Docs.safeMode = false
                                root.confirmOpen = false
                            }
                        }
                    }
                    MenuButton {
                        label: "Применить"
                        accent: true
                        onClicked: {
                            if (Docs.applyAllDrafts()) {
                                Docs.safeMode = false
                                root.confirmOpen = false
                            }
                        }
                    }
                }
            }
        }
    }

    component PageLoader: Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: false
    }

    // Esc закрывает меню (или сперва диалог подтверждения).
    Keys.onEscapePressed: {
        if (root.confirmOpen) root.confirmOpen = false
        else                  root.closeRequested()
    }
    focus: root.open
}
