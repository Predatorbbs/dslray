import QtQuick
import DSLRay

// Строка вкладок открытых файлов. Управляется моделью Docs.
//
// Поведение:
//  · до первого открытого файла строка пустая, но высоту сохраняет;
//  · новая вкладка всегда становится активной и подкручивается в видимую зону;
//  · если вкладки не влезают по ширине — у краёв появляются кнопки прокрутки
//    (левая, когда есть скрытые слева; правая — когда есть скрытые справа).
Rectangle {
    id: root
    height: Theme.tabsRowHeight
    color: Theme.bgTabsRow

    readonly property int scrollBtnW: 28

    // нижняя граница
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.divider
    }

    // Есть ли скрытые вкладки слева / справа от видимой области.
    property bool canScrollLeft:  tabsView.contentX > 0.5
    property bool canScrollRight: tabsView.contentX < tabsView.contentWidth - tabsView.width - 0.5

    function scrollBy(dx) {
        const maxX = Math.max(0, tabsView.contentWidth - tabsView.width)
        const target = Math.max(0, Math.min(maxX, tabsView.contentX + dx))
        scrollAnim.stop()
        scrollAnim.from = tabsView.contentX
        scrollAnim.to = target
        scrollAnim.start()
    }

    function ensureActiveVisible() {
        if (Docs.activeIndex >= 0)
            tabsView.positionViewAtIndex(Docs.activeIndex, ListView.Contain)
    }

    NumberAnimation {
        id: scrollAnim
        target: tabsView
        property: "contentX"
        duration: 170
        easing.type: Easing.OutCubic
    }

    // Новая/переключённая вкладка — подкрутить в видимую зону.
    Connections {
        target: Docs
        function onActiveIndexChanged() { Qt.callLater(root.ensureActiveVisible) }
        function onCountChanged()       { Qt.callLater(root.ensureActiveVisible) }
    }

    // ── Ряд вкладок ───────────────────────────────────────────────────
    ListView {
        id: tabsView
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        orientation: ListView.Horizontal
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: Docs

        delegate: Item {
            id: tab
            required property int index
            required property string name
            required property string path
            required property bool modified
            readonly property bool active: Docs.activeIndex === index

            width: tabContent.implicitWidth + 24
            height: tabsView.height

            // Клик по телу вкладки — активировать (нижний слой; кнопка
            // закрытия выше перехватит свой клик).
            MouseArea {
                anchors.fill: parent
                onClicked: Docs.activate(tab.index)
            }

            Rectangle {
                id: bg
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.bottomMargin: -1   // «съезжает» на нижнюю линию
                color: tab.active ? Theme.bgPanel
                                  : (tabHover.hovered ? "#eef0f3" : "transparent")
                border.color: tab.active ? Theme.border : "transparent"
                border.width: 1
                topLeftRadius: 8
                topRightRadius: 8

                HoverHandler { id: tabHover }

                Row {
                    id: tabContent
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: tab.name
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontTabs
                        color: tab.active ? Theme.textPrimary : Theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // ✕ / точка несохранённых изменений
                    Rectangle {
                        width: 17; height: 17; radius: 5
                        color: closeHover.hovered ? "#e3e6ec" : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: (tab.modified && !closeHover.hovered) ? "●" : "✕"
                            font.pixelSize: tab.modified && !closeHover.hovered ? 9 : 11
                            color: Theme.textFaint
                        }
                        HoverHandler { id: closeHover }
                        TapHandler { onTapped: Docs.closeAt(tab.index) }
                    }
                }
            }
        }
    }

    // ── Кнопка прокрутки влево ────────────────────────────────────────
    ScrollEdge {
        visible: root.canScrollLeft
        anchors.left: parent.left
        glyph: "‹"
        onClicked: root.scrollBy(-tabsView.width * 0.7)
    }

    // ── Кнопка прокрутки вправо ───────────────────────────────────────
    ScrollEdge {
        visible: root.canScrollRight
        anchors.right: parent.right
        glyph: "›"
        onClicked: root.scrollBy(tabsView.width * 0.7)
    }

    // Кнопка-стрелка у края ряда. Непрозрачный фон перекрывает уезжающую
    // под неё вкладку.
    component ScrollEdge: Rectangle {
        id: edge
        property string glyph: ""
        signal clicked()

        width: root.scrollBtnW
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        color: Theme.bgTabsRow

        Rectangle {
            anchors.centerIn: parent
            width: 22; height: 22
            radius: Theme.rSmall
            color: edgeHover.hovered ? "#e3e6ec" : Theme.bgPanel
            border.color: Theme.border
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: edge.glyph
                font.family: Theme.fontSans
                font.pixelSize: 16
                color: Theme.textMuted
            }
        }
        HoverHandler { id: edgeHover }
        TapHandler { onTapped: edge.clicked() }
    }
}
