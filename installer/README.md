# Сборка и распространение DSLRay (Windows)

## Портативная папка

Из корня репозитория:

~~~powershell
powershell -ExecutionPolicy Bypass -File installer\package.ps1
~~~

Для уже используемой папки build-tabs:

~~~powershell
powershell -ExecutionPolicy Bypass -File installer\package.ps1 -BuildDir build-tabs
~~~

Пути к тулчейну можно переопределить параметрами QtRoot, MinGWBin, CMake и NinjaBin.
Скрипт проверяет ошибки CMake и собирает Release-цель portable. Qt 6.11.1 MinGW
проверен; пакет предназначен для Windows 10/11 x64.

В корне dist\DSLRay остаётся только appDSLRay.exe. Он запускает основной бинарь
из bin; все Qt/MinGW DLL находятся там же. Плагины, QML и переводы размещаются
в plugins, qml и translations, пути описаны в bin\qt.conf.

Запускайте dist\DSLRay\appDSLRay.exe. Для переноса или отправки упакуйте всю папку
DSLRay целиком. Qt и MinGW на целевом компьютере устанавливать не нужно.

Проверка запуска выполняется автоматически с очищенным от Qt PATH и временными
настройками. Служебные логи остаются в build\package-logs (или в выбранной папке
сборки). Пользовательские настройки и черновики приложение хранит как раньше.

При успешной упаковке прежнее содержимое папки целиком сохраняется в
dist\DSLRay-backup-<дата>-<идентификатор>. Остальное содержимое dist не затрагивается.

## Установщик Inno Setup

Существующий DSLRay.iss совместим с этой структурой: он копирует dist\DSLRay
рекурсивно и создаёт ярлыки на корневой appDSLRay.exe. Сначала выполните упаковку,
затем откройте DSLRay.iss в Inno Setup и нажмите Build.

Результат — installer\out\DSLRay-0.3.0-setup.exe. Не меняйте AppId существующего
установщика: он определяет обновление прежней установки. Настройки приложения
не зависят от установки; по умолчанию они находятся в HKCU\Software\DSLRay\DSLRay.
