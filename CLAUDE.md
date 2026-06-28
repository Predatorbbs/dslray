# DSLRay — заметки для разработки

Десктопный IDE-редактор на **Qt 6 / QML** для DSL-языка UI. Логика — в C++-контроллерах,
интерфейс — QML. Этот файл — то, что неочевидно при первом погружении; он важнее README.

## Стек и где что лежит

- **Qt 6.7+** (собирается на 6.11.1 MinGW). C++17, `CMAKE_AUTOMOC`.
- C++: `src/`. QML: `qml/` (корень `qml/Main.qml`, компоненты `qml/components/`, синглтон-токены
  `qml/theme/Theme.qml`).
- Связь C++↔QML — через **контекстные свойства** (см. `src/main.cpp`):
  - `Project` → `ProjectController` (дерево проекта, файловые операции).
  - `Docs` → `DocumentController` (открытые вкладки, режимы редактора, настройки, сессия).
  - `JsonHighlighter` — QML-тип через `qmlRegisterType` (подсветка JSON в редакторе).
- Репозиторий: github.com/Predatorbbs/dslray, ветка `main`, коммиты напрямую в main.

## Сборка и запуск (важные нюансы!)

Тулчейн (не на PATH по умолчанию):
- CMake: `C:/Qt/Tools/CMake_64/bin/cmake.exe`
- MinGW: `C:/Qt/Tools/mingw1310_64/bin`, Ninja: `C:/Qt/Tools/Ninja`
- Qt: `C:/Qt/6.11.1/mingw_64` (рантайм-DLL в `.../bin`)

Сборка (из Git Bash):
```bash
export PATH="/c/Qt/Tools/mingw1310_64/bin:/c/Qt/Tools/Ninja:$PATH"
# перед сборкой обязательно убить запущенный exe — иначе линковка падает "Permission denied":
taskkill //IM appDSLRay.exe //F 2>/dev/null
"/c/Qt/Tools/CMake_64/bin/cmake.exe" --build /c/Users/Predator/dslray/build --target appDSLRay
```
Бинарь: `build/appDSLRay.exe`. После правок `CMakeLists.txt`/новых `.cpp` — сначала
`cmake -S . -B build` (реконфиг).

### Headless-проверка (без GUI)
`appDSLRay.exe` — **WIN32 GUI-subsystem**: `qDebug` и **QML-предупреждения молча глушатся**,
если не выставить `QT_FORCE_STDERR_LOGGING=1`. Без него «чистый stderr» ничего не значит.
```bash
cd /c/Users/Predator/dslray/build
PATH="/c/Qt/6.11.1/mingw_64/bin:$PATH" QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  ./appDSLRay.exe 2>err.log &
# затем taskkill и grep -v на шум про QFontDatabase/fonts (под offscreen шрифтов нет — это норма)
```
Это ловит ошибки биндингов/типов на старте, но НЕ интерактив (мышь не сымитировать).

### Headless-тест C++ модели
`ProjectTreeModel` можно прогнать отдельно: `moc projecttreemodel.h` → `g++ test.cpp
projecttreemodel.cpp moc_*.cpp -lQt6Core`. Так проверялись move/remove/indexForPath
(детерминированно, без GUI). См. историю — паттерн рабочий.

## Архитектура: ключевые компоненты

| Файл | Роль |
|---|---|
| `src/projecttreemodel.*` | **Собственная** `QAbstractItemModel` дерева проекта |
| `src/projectcontroller.*` | Открытие проекта + проксирование операций в модель; `confirmDelete` |
| `src/documentcontroller.*` | Модель вкладок (`QAbstractListModel`) + активный документ + режимы + сессия |
| `src/jsonhighlighter.*` | `QSyntaxHighlighter` для JSON + QML-обёртка + висячий отступ переноса |
| `qml/components/FilesPanel.qml` | Дерево «Проект»: делегат, иконки, DnD, ренейм, ПКМ-удаление |
| `qml/components/CodeEditor.qml` | Редактор: `TextArea`, гаттер, подсветка, перенос, размер шрифта, направляющие вложений, парные скобки, ошибки, авто-отступ, формат |
| `qml/components/StructurePanel.qml` | Список объектов по `elementName`, подсветка «пройденных» |
| `qml/components/MenuOverlay.qml` | Всплывающее меню (бургер): разделы + настройки редактора |
| `qml/components/FileTabs.qml` | Полоса вкладок со скроллом |
| `qml/components/PanelFrame.qml` | Карточка-панель (шапка с title/subtitle + слот headerRight) |
| `qml/Main.qml` | Раскладка (SplitView), Ctrl+S, диалог удаления |
| BoardPanel / PropertiesPanel | Пока заглушки |

## Грабли и инварианты (НЕ переоткрывать заново)

- **QFileSystemModel удалён намеренно.** Он оставлял фантомные строки при перемещении внутри
  дерева (две строки на один путь → «оба выделяются»). Заменён на `ProjectTreeModel` с явными
  `beginInsertRows`/`beginRemoveRows`. Не возвращать QFileSystemModel.
- **ProjectTreeModel**: ленивое заполнение (populate при первом `rowCount`/`index`), папки
  сверху, скрытые/точко-файлы спрятаны. `indexForPath()` сам дочитывает ветки-предки
  (для подсветки вкладки в дереве). Операции мутируют модель сами.
- **Drag-and-drop (QML)**: снятие `Drag.active=false` **само по себе drop НЕ генерирует** —
  нужен явный `dragProxy.Drag.drop()` в `onReleased`. Proxy 1×1 привязан к `mouseX/mouseY`
  (= курсор), `Drag.hotSpot 0,0` → попадание ровно под курсором. На MouseArea строки
  `preventStealing: true`, иначе дерево-`Flickable` листается вместо перетаскивания.
- **Клики в дереве**: считаются вручную по `onReleased` (сырые события). 1 — выбрать,
  2 — открыть (арбитр-таймер 260мс), 3 — переименовать; F2 — тоже ренейм. ПКМ — контекст-меню.
- **Раскладка — только `SplitView`.** Не использовать `Layout.preferredHeight: parent.height*k`
  внутри `ColumnLayout` — это даёт варнинг «recursive rearrange».
- **Режимы редактора**: «Прозрачный» (пишет файл на лету, дебаунс 400мс) и «Безопасный»
  (правки в черновик `AppLocalData/DSLRay/DSLRay/drafts/<sha1(путь)>.draft`, в оригинал —
  по `Ctrl+S`). Правки идут через `Docs.applyEdit` / `Docs.flushEdit`. Переключение режима с
  непустыми черновиками — через диалог (Применить/Отбросить/Отмена).
- **Подсветка вкладки в дереве**: вешать на `Docs.activeIndexChanged`, **не** на
  `activeChanged` (последний шлётся и на каждую правку — дерево будет дёргаться).
- **Нумерация строк** в редакторе — по **логическим** строкам (`positionToRectangle` +
  `lineStarts`), чтобы корректно работало при переносе по словам.
- **Редактор кода (CodeEditor.qml) — слои и инварианты:**
  - *Подсветка текущей строки* — на всю **логическую** строку (все визуальные ряды при
    переносе): `editor.curLineRect` от `lineStarts[caretLine]` до начала следующей строки.
  - *Парные скобки / ошибки* считаются один раз на `ta.text` в `root.analyze()` (стек, с
    учётом строк JSON) → `{pairs, errors}`. Оверлеи рисуются в `background` у `TextArea`
    (скроллятся с текстом) по `positionToRectangle`. `matchPair` смотрит на скобку у каретки.
  - *Направляющие вложений* — отдельный `Canvas` (`guideCanvas`), **фиксированный к окну**
    (`anchors.fill: flick`), рисует со сдвигом `-flick.contentY`; объявлен ДО `flick`, поэтому
    лежит позади текста (виден сквозь прозрачный фон). Перерисовка — через `paintDeps`.
    Глубина строки = ведущие пробелы/табы (таб = `indentWidth` колонок) / `indentWidth`.
    Активная скобка (`matchPair`) дополнительно рисует вертикаль **акцентом** (`Theme.accent`,
    2px) от **начала текста** строки открывающей скобки (x = `positionToRectangle` первого
    непробельного символа: одиночная скобка → от неё, скобка после текста → от текста),
    от низа её строки до верха строки закрывающей.
  - *Каретка* — свой `cursorDelegate` (2px, мигание по таймеру, сброс в «видимое» при
    перемещении): дефолтная иногда не прорисовывалась до первого ввода.
  - *Переключение вкладок*: `reload()` после установки текста зовёт `ta.forceActiveFocus()` —
    показывает каретку и форсирует перерисовку (иначе текст новой вкладки иногда не
    прорисовывался до взаимодействия).
  - *Висячий отступ переноса* (при word-wrap) — в C++ (`JsonHighlighter`, обёртка): на
    `QTextDocument::contentsChange` затронутые блоки помечаются и обрабатываются **отложенно**
    (таймер 0мс, `scheduleIndent`/`flushIndent`) — правка формата прямо в обработчике идёт во
    время установки текста TextArea и ломает обновление сцены. Блокам ставится `QTextBlockFormat` с
    `leftMargin = ведущие_колонки*ширина_пробела` и `textIndent = -leftMargin`
    (минус гасит сдвиг первой визуальной строки, перенос — висит ровно на уровне строки).
    **Текст в файле не меняется** — только раскладка. Защита от рекурсии — флаг
    `m_applyingIndent` + сверка формата (вручную, не `qFuzzyCompare` — он ненадёжен при нуле).
    `tabWidth` биндится из `Docs.indentWidth`; при смене `codeFontSize` QML зовёт
    `jsonHl.refreshIndent()` (через `Qt.callLater` — после применения нового шрифта).
  - *Цвета подсветки* настраиваемы: `JsonHighlighter` имеет `keyColor/stringColor/numberColor/
    keywordColor/punctColor` (биндятся из `Docs.color*`, хранятся в QSettings `editor/color*`),
    сеттер зовёт `setColors()` подсветчика + `rehighlight()`. Меню «Внешний вид» → блок
    «Внешний вид кода» (палитра `ColorDialog` из `QtQuick.Dialogs`; нужен `Qt6::QuickDialogs2`).
  - *Прокрутка колесом* — свой `WheelHandler` на `flick` (`wheelLines` строк за щелчок, дефолт 4;
    встроенная прокрутка Flickable ощутимо медленнее).
  - *Каретка не теряется* — `ta.onCursorRectangleChanged → root.ensureCursorVisible()` подвигает
    вьюпорт, когда каретку уводят стрелками за край (пропускается при `suppressEdit`).
  - **Инвариант:** `gutterWidth` считается по `lineStarts.length` (ЛОГИЧЕСКИЕ строки), НЕ по
    `ta.lineCount` — иначе цикл биндингов `gutterWidth ↔ lineCount ↔ ta.width` (висячий отступ
    меняет точки переноса и замыкает его).
  - *Защита от больших файлов* — `root.richEnabled` (`ta.length <= richLimitChars`, 200k).
    Выше порога `analysis`, оверлеи и направляющие выключаются (O(n)/правку), редактор остаётся
    рабочим (подсветка, нумерация, текущая строка). Запас на будущий рефакторинг.
  - *Авто-отступ* (`insertNewline`) и *Tab* (`insertTab`) перехватываются в `Keys.onPressed`
    (Return/Enter/Tab), правят через `ta.insert/remove` (сохраняют undo). Раскрытие пары
    `{}`/`[]` — двумя строками. Тип отступа — `Docs.indentUseTabs`, ширина — `Docs.indentWidth`.
  - *«Форматировать отступы»* (кнопка в шапке, `headerRight`) — `reindentText()` перевыставляет
    отступ каждой строки по глубине скобок (string-aware), затем `ta.text = ...` (правка идёт
    через дебаунс записи как обычная). Строка, начинающаяся с `}`/`]`, печатается на уровень левее.
- **Структура → код**: `StructurePanel` парсит `"elementName"` регэкспом с позициями; клик
  шлёт `objectActivated(offset)` → `codeEditor.gotoOffset()` (скроллит объект к верху).
  Подсветка «пройденных» завязана на `codeEditor.topOffset`.

## Темы оформления (светлая / тёмная)

- `qml/theme/Theme.qml` — синглтон с **реактивными** цветами: `property string id` ("light"|"dark"),
  `readonly property bool dark`. Каждый цвет = тернарник `dark ? <тёмн> : <светл>`. **Имена токенов
  одинаковы в обеих темах**, поэтому весь UI перекрашивается сам (компоненты читают `Theme.xxx`).
- `id` выставляется владельцем: в `Main.qml` — `Binding { target: Theme; property: "id"; value: Docs.themeId }`.
  Синглтон-`Theme` **не видит** контекст-свойства (`Docs`) сам — поэтому связывает Main, а не Theme.
- Хранится в `Docs.themeId` (QSettings `appearance/theme`). Переключатель — в тулбаре справа.
  Под новые темы: добавить ветку в тернарники Theme + карточку в «Настройки тем» (MenuOverlay).
- При добавлении цвета в UI — **класть его токеном в Theme** (с обоими значениями), а не хардкодить,
  иначе тёмная тема сломается на этом месте. Новые токены: `accentSoft/accentRing/hover/hoverStrong/
  editorSelection/treeFolder/canvasDot`.
- Цвета подсветки кода (`Docs.color*`) — **общие для обеих тем** (пользовательские), не тема-зависимые.

## Профиль и статус-бар

- `Docs.userName/userEmail/avatarPath` (QSettings `user/*`) — раздел «Пользователь» в меню (верхний).
  Аватар выбирается `FileDialog`, путь хранится как `file://`-URL; в статус-баре — `Image` или кружок
  с инициалом.
- Счётчики статус-бара **живые**: `CodeEditor` отдаёт `liveLines/liveChars/liveTokens` (токены ≈
  символы/4), `Main` прокидывает их в `StatusBar`. Не хардкодить значения в StatusBar.

## Настройки (QSettings)

Бэкенд — реестр `HKCU\Software\DSLRay\DSLRay` (org/app = DSLRay/DSLRay). Ключи:
`session/projectPath`, `session/openFiles`, `session/activePath`,
`editor/safeMode`, `editor/wordWrap`, `editor/codeFontSize`, `editor/indentWidth` (1…8),
`editor/indentUseTabs`, `editor/color*` (5 цветов подсветки),
`appearance/theme`, `user/name`, `user/email`, `user/avatar`, `project/confirmDelete`.
Сессия (проект + вкладки) восстанавливается в `main.cpp::restoreSession` после загрузки QML.

## Дизайн

- Хэндоффы лежат вне репозитория: `C:\Qt\APPS\DSLRay\design_handoff_*\README.md`
  (например `design_handoff_file_tree`). HTML/JS внутри — **только референс**, реализовывать
  средствами Qt. Дерево уже сделано по `design_handoff_file_tree` (иконки — `QtQuick.Shapes`).
- Цвета/отступы/типографика — `qml/theme/Theme.qml`. Дерево использует свои токены из хэндоффа
  (accent `#4b5bd6`), остальной UI — `Theme.accent` (`#4c6ef5`).
- `samples/demo.json` — тестовый JSON с `elementName` для проверки «Структуры».

## Не сделано / отложено

- Кнопки «Сохранить» (есть только Ctrl+S) и «Запуск» в тулбаре; разделы меню кроме
  «Редактор кода» — заглушки.
- `BoardPanel` (визуальный канвас) и `PropertiesPanel` — заглушки.
- Позиции сплиттеров не сохраняются между запусками.
