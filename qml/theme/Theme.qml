pragma Singleton
import QtQuick

QtObject {
    // ─── Поверхности / фоны ─────────────────────────────────────────
    readonly property color bgApp:       "#ffffff"   // основа окна
    readonly property color bgPanel:     "#ffffff"   // тело панелей-карточек
    readonly property color bgSubtle:    "#fbfbfc"   // шапки панелей, тулбар, статус-бар
    readonly property color bgCanvas:    "#f7f8fa"   // фон доски
    readonly property color bgWorkspace: "#f1f3f6"   // фон между панелями (gutter)
    readonly property color bgTabsRow:   "#f6f7f9"   // полоса с вкладками

    // ─── Границы ─────────────────────────────────────────────────────
    readonly property color border:     "#e6e8ed"
    readonly property color borderSoft: "#eef0f3"
    readonly property color divider:    "#eceef2"

    // ─── Текст ───────────────────────────────────────────────────────
    readonly property color textPrimary: "#3a4050"
    readonly property color textMuted:   "#6b7280"
    readonly property color textFaint:   "#9aa0ad"
    readonly property color textGhost:   "#bcc1cc"

    // ─── Акцент ──────────────────────────────────────────────────────
    readonly property color accent:   "#4c6ef5"
    readonly property color accentFg: "#ffffff"

    // ─── Редактор кода ───────────────────────────────────────────────
    readonly property color editorGuide:    "#e4e7ee"  // вертикальные линии вложений
    readonly property color editorCurLine:  "#f3f5fc"  // подсветка текущей строки
    readonly property color editorBracket:  "#bcd0ff"  // подсветка парной скобки
    readonly property color editorBracketFg: "#1d4ed8" // символ парной скобки

    // ─── Статусы ─────────────────────────────────────────────────────
    readonly property color ok:   "#3bb273"
    readonly property color warn: "#e9a23b"
    readonly property color err:  "#e35d6a"

    // ─── Скругления ──────────────────────────────────────────────────
    readonly property int rCard:    11
    readonly property int rButton:  8
    readonly property int rSmall:   6

    // ─── Раскладка ───────────────────────────────────────────────────
    readonly property int gap:                13   // gap между панелями
    readonly property int sidebarLeftWidth:   236
    readonly property int sidebarRightWidth:  314
    readonly property real boardRatio:        0.58 // доля доски в центре
    readonly property int splitterHandle:     13
    readonly property real filesProjectRatio: 0.44 // доля «ПРОЕКТ» в левой колонке

    // Размеры тулбара / вкладок / статус-бара
    readonly property int toolbarHeight: 53
    readonly property int tabsRowHeight: 38
    readonly property int statusHeight:  29

    // Кнопки в тулбаре
    readonly property int toolBtnSize:     34
    readonly property int panelHeaderHeight: 35

    // ─── Типографика ─────────────────────────────────────────────────
    // На Windows реально подхватится Segoe UI, для других ОС Qt подберёт фолбэк.
    readonly property string fontSans: "Segoe UI"
    readonly property string fontMono: "Consolas"

    readonly property int fontToolbar:      13
    readonly property int fontContent:      13
    readonly property int fontTabs:         13
    readonly property int fontPanelHeader:  12   // ≈ 11.5px в макете
    readonly property real letterSpacingHeader: 0.7
    readonly property int fontStatus:       12
}
