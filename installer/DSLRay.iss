; Inno Setup script for DSLRay.
; Собирает установщик из портативной папки ..\dist\DSLRay (см. installer/README.md).
; Компиляция: открыть этот файл в Inno Setup и нажать Build, либо ISCC.exe DSLRay.iss

#define AppName "DSLRay"
#define AppVersion "0.3.0"
#define AppPublisher "DSLRay"
#define AppExe "appDSLRay.exe"

[Setup]
; AppId уникален для приложения и НЕ должен меняться между версиями
; (по нему обновление находит прошлую установку). Не трогать.
AppId={{8F3A1C90-2B4D-4E6F-9A1B-7C2E5D9F0A13}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
; Установка без прав администратора (в профиль пользователя). При желании
; пользователь может выбрать установку для всех в диалоге.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=out
OutputBaseFilename=DSLRay-{#AppVersion}-setup
SetupIconFile=..\resources\icons\dslray_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Вся развёрнутая папка (exe + Qt DLL + qml + плагины) кладётся в {app}.
Source: "..\dist\DSLRay\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Удалить {#AppName}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
