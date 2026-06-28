# DSLRay — icon handoff package

Этот пакет можно отдать Claude Code, Codex или разработчику Qt-приложения как готовые иконки приложения.

## Что внутри

- `resources/icons/dslray_icon_source_generated.png` — исходная сгенерированная иконка.
- `resources/icons/dslray_icon_16.png` … `dslray_icon_1024.png` — PNG-набор размеров.
- `resources/icons/dslray_icon.ico` — Windows executable icon.
- `resources/icons/dslray_icon.icns` — macOS bundle icon.
- `resources/icons/dslray_icon.iconset/` — fallback-набор для сборки `.icns` через `iconutil`.
- `resources/icons/dslray_icon.svg` — схематичная векторная версия для редактирования.
- `resources/dslray_icons.qrc` — Qt resource-файл.
- `platform/windows/dslray.rc` — Windows resource script.
- `qt/snippets/` — фрагменты для CMake, qmake и `main.cpp`.

## Основная иконка

Используй как runtime icon:

```cpp
app.setWindowIcon(QIcon(":/icons/dslray_icon.png"));
```

Если есть `QMainWindow`:

```cpp
window.setWindowIcon(QIcon(":/icons/dslray_icon.png"));
```

## Инструкция для Claude Code / Codex

Задача: подключить иконку DSLRay к Qt-приложению.

1. Скопировать папки `resources/`, `platform/` и `qt/snippets/` в корень проекта или адаптировать пути.
2. Подключить `resources/dslray_icons.qrc` к сборке.
3. В `main.cpp` добавить `QIcon(":/icons/dslray_icon.png")` для `QApplication` и главного окна.
4. Для Windows добавить `platform/windows/dslray.rc` в target sources или использовать `RC_ICONS`.
5. Для macOS добавить `resources/icons/dslray_icon.icns` в bundle resources и прописать `MACOSX_BUNDLE_ICON_FILE`.
6. Не менять сам смысл иконки: тёмный фон, схематичная RGB-призма/луч, левый белый источник и три расходящиеся RGB-полосы.

## Комментарий по читаемости

Вариант специально увеличен и утолщён относительно первого эскиза, чтобы лучше читаться в маленьких размерах на панели задач, Dock и в списке приложений.
