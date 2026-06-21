# DSL Studio (DSLRay) — шаг 1: каркас приложения

Десктоп-IDE для собственного DSL описания интерфейсов. Qt 6 / QML, Windows 10/11.

## Что сделано на шаге 1

- CMake-проект под Qt 6.7+
- Главное окно 1400×900 (мин. 1100×700)
- Раскладка по макету `DSL_Studio_dc.html`:
  - **Toolbar** (53px): меню, Сохранить, ▶ Запуск, undo/redo, индикатор автосинхронизации
  - **FileTabs** (38px): две статичные вкладки + «+»
  - **Левая колонка** (236px): ПРОЕКТ (44%) над СТРУКТУРОЙ (56%), gap 13px
  - **Центр**: ДОСКА (58%) → ручка сплиттера (13px) → КОД
  - **Правая колонка** (314px): СВОЙСТВА
  - **StatusBar** (29px) с захардкоженными значениями
- `Theme.qml` — синглтон со всеми токенами из §4 брифа

Все панели — заглушки правильных размеров и цветов. Сплиттер «доска/код» **не** перетаскивается (это шаг 2). Кнопки тулбара **не** реагируют (это шаг 3).

## Сборка

### Через Qt Creator

1. Открыть `CMakeLists.txt` через **File → Open File or Project**
2. Выбрать кит **Desktop Qt 6.7+ MinGW 64-bit**
3. **Build → Run** (`Ctrl+R`)

### Из командной строки (MinGW, среда Qt 6.7+)

```bat
cd <папка с проектом>
cmake -S . -B build -G "MinGW Makefiles" ^
    -DCMAKE_PREFIX_PATH=C:\Qt\6.7.0\mingw_64
cmake --build build --config Release
build\appDSLStudio.exe
```

## Структура файлов

```
DSLStudio/
├── CMakeLists.txt
├── src/
│   └── main.cpp
└── qml/
    ├── Main.qml
    ├── theme/
    │   └── Theme.qml          ← синглтон с дизайн-токенами
    └── components/
        ├── PanelFrame.qml     ← базовая «карточка»-панель
        ├── Toolbar.qml
        ├── FileTabs.qml
        ├── StatusBar.qml
        ├── FilesPanel.qml     ← ПРОЕКТ
        ├── StructurePanel.qml ← СТРУКТУРА
        ├── BoardPanel.qml     ← ДОСКА (с сеткой точек на канвасе)
        ├── CodeEditor.qml     ← КОД
        └── PropertiesPanel.qml← СВОЙСТВА
```

## Решения, принятые сейчас

| Что | Как | Почему |
|---|---|---|
| QML-модуль | один URI `DSLStudio` для всего | проще импорты: `import DSLStudio` — и сразу доступны `Theme`, `Toolbar`, `PanelFrame` и т.д. |
| Стиль Controls | `Basic` | весь UI рисуем сами, нативный стиль мешает |
| Шрифт | `"Segoe UI"` / `"Consolas"` через `Theme` | системные шрифты Windows, без бандла |
| Скругление шапок панелей | `topLeftRadius`/`topRightRadius` на Rectangle | требует Qt 6.7+ — оттуда и нижняя планка версии |
| Сплиттер на шаге 1 | статичный 58/42 через `Layout.preferredHeight: parent.height * 0.58` | перетаскивание и `QSettings` — шаг 2 |
| Цвет gutter между панелями | `bgWorkspace = #f1f3f6` | в §4 брифа не назван, добавил в `Theme.qml` отдельным токеном |

## Что дальше — шаг 2

- Заменить центральный `ColumnLayout` на `SplitView` (вертикальный)
- Сохранять позицию ручки через `Settings { ... }` (QML-биндинг к QSettings)
- Кастомизировать `handleDelegate`, чтобы выглядел как сейчас (плашка 46×5)
