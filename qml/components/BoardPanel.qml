import QtQuick
import DSLStudio

// Панель «ДОСКА» — визуальный канвас. На шаге 1 рисуем только фон-сетку
// (как в макете: точки 1.1px каждые 18px) и кладём заглушечный текст.
// Реальные блоки появятся на шаге 7.
PanelFrame {
    id: panel
    title: "ДОСКА"

    // Зум-контролы в шапке — пока визуальные.
    headerRight: [
        ZoomBtn { glyph: "\u2212" },         // −
        Rectangle {
            width: 42; height: 26
            color: "transparent"
            Text {
                anchors.centerIn: parent
                text: "100%"
                font.family: Theme.fontSans
                font.pixelSize: 12
                color: Theme.textMuted
            }
        },
        ZoomBtn { glyph: "+" },
        Rectangle {
            width: 50; height: 26
            radius: Theme.rSmall
            color: Theme.bgPanel
            border.color: Theme.border
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: "сброс"
                font.family: Theme.fontSans
                font.pixelSize: 12
                color: Theme.textMuted
            }
        }
    ]

    // Фон-канвас с точечной сеткой.
    Rectangle {
        anchors.fill: parent
        color: Theme.bgCanvas

        // Канвас рисуем как ShaderEffect/Canvas? Самое простое и быстрое —
        // заполнить мелкими точками через Repeater. Но для шага 1 оставим
        // равномерную заливку + Canvas для сетки.
        Canvas {
            id: grid
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "#dfe2e8";
                const step = 18;
                const r = 1.1;
                for (let y = step / 2; y < height; y += step) {
                    for (let x = step / 2; x < width; x += step) {
                        ctx.beginPath();
                        ctx.arc(x, y, r, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }
            // Перерисовка при ресайзе.
            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()
        }

        // Подсказка-подпись внизу слева.
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.bottomMargin: 10
            text: "тяни фон — панорама · ⠿ на блоке — перетащить"
            font.family: Theme.fontSans
            font.pixelSize: 11
            color: Theme.textGhost
        }

        // Placeholder в центре, чтобы понимать что это доска.
        Text {
            anchors.centerIn: parent
            text: "доска"
            font.family: Theme.fontSans
            font.pixelSize: 14
            color: Theme.textGhost
        }
    }

    // Инлайн-кнопка зума.
    component ZoomBtn: Rectangle {
        id: zb
        property string glyph: ""
        width: 26; height: 26
        radius: Theme.rSmall
        color: Theme.bgPanel
        border.color: Theme.border
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: zb.glyph
            font.family: Theme.fontSans
            font.pixelSize: 15
            color: Theme.textMuted
        }
    }
}
