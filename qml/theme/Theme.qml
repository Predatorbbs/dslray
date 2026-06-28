pragma Singleton
import QtQuick

// Палитра и метрики приложения. Цвета — реактивные: переключаются между
// светлой и тёмной темой по `id`. Имена токенов одинаковы в обеих темах,
// поэтому весь UI перекрашивается автоматически (компоненты читают Theme.xxx).
//
// `id` выставляется снаружи (Main: Theme.id ← Docs.themeId). Под новые темы
// достаточно добавить ветку в тернарники ниже и пункт в «Настройки тем».
QtObject {
    id: theme

    // Текущая тема: "light" | "dark". Меняется владельцем (Main).
    property string id: "light"
    readonly property bool dark: id === "dark"

    // ─── Поверхности / фоны ─────────────────────────────────────────
    readonly property color bgApp:       dark ? "#15171c" : "#ffffff"   // основа окна
    readonly property color bgPanel:     dark ? "#1e2128" : "#ffffff"   // тело панелей-карточек
    readonly property color bgSubtle:    dark ? "#1b1e25" : "#fbfbfc"   // шапки панелей, тулбар, статус-бар
    readonly property color bgCanvas:    dark ? "#131519" : "#f7f8fa"   // фон доски
    readonly property color bgWorkspace: dark ? "#101216" : "#f1f3f6"   // фон между панелями (gutter)
    readonly property color bgTabsRow:   dark ? "#181b21" : "#f6f7f9"   // полоса с вкладками

    // ─── Границы ─────────────────────────────────────────────────────
    readonly property color border:     dark ? "#2c313b" : "#e6e8ed"
    readonly property color borderSoft: dark ? "#242831" : "#eef0f3"
    readonly property color divider:    dark ? "#21242b" : "#eceef2"

    // ─── Текст ───────────────────────────────────────────────────────
    readonly property color textPrimary: dark ? "#e3e6ec" : "#3a4050"
    readonly property color textMuted:   dark ? "#9aa1ad" : "#6b7280"
    readonly property color textFaint:   dark ? "#707782" : "#9aa0ad"
    readonly property color textGhost:   dark ? "#555c66" : "#bcc1cc"

    // ─── Акцент ──────────────────────────────────────────────────────
    readonly property color accent:     dark ? "#7080f0" : "#4b5bd6"
    readonly property color accentFg:   "#ffffff"
    readonly property color accentSoft: dark ? "#242a47" : "#eef1fe"   // фон выделения / мягкие заливки
    readonly property color accentRing: dark ? Qt.rgba(112/255,128/255,240/255,0.22)
                                             : Qt.rgba(75/255,91/255,214/255,0.16)

    // ─── Ховер-заливки ───────────────────────────────────────────────
    readonly property color hover:       dark ? "#23272f" : "#f1f3f6"  // кнопки/вкладки на панели
    readonly property color hoverStrong: dark ? "#2d323b" : "#e3e6ec"  // закрытие вкладки, край-скролл

    // ─── Статусы ─────────────────────────────────────────────────────
    readonly property color ok:   dark ? "#45c486" : "#3bb273"
    readonly property color warn: dark ? "#e6ab52" : "#e9a23b"
    readonly property color err:  dark ? "#ef7079" : "#e35d6a"

    // ─── Редактор кода ───────────────────────────────────────────────
    readonly property color editorGuide:     dark ? "#2c313b" : "#e4e7ee"  // линии вложений
    readonly property color editorCurLine:   dark ? "#1f232c" : "#f3f5fc"  // текущая строка
    readonly property color editorBracket:   dark ? "#34406a" : "#bcd0ff"  // парная скобка
    readonly property color editorBracketFg: dark ? "#9db4ff" : "#1d4ed8"  // символ парной скобки
    readonly property color editorSelection: dark ? "#34415e" : "#d7dbe6"  // выделение текста

    // ─── Дерево проекта ──────────────────────────────────────────────
    readonly property color treeFolder: dark ? "#828b9c" : "#8893a8"  // базовый цвет папки

    // ─── Доска ───────────────────────────────────────────────────────
    readonly property color canvasDot: dark ? "#2a2e37" : "#dfe2e8"  // точки фоновой сетки

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
