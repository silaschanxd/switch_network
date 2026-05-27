; Inno Setup 脚本
; 需要安装 Inno Setup: https://jrsoftware.org/isdl.php
; 使用: 右键 setup.iss -> "Compile" 或运行:
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss

#define MyAppName "网络配置切换"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Switch Network"
#define MyAppURL ""
#define MyAppExeName "switch_network.exe"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
OutputDir=.\output
OutputBaseFilename=网络配置切换_Setup_v{#MyAppVersion}
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
DisableProgramGroupPage=yes

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "快捷方式："; Flags: checkedonce

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "运行 {#MyAppName}"; Flags: postinstall nowait skipifsilent shellexec
