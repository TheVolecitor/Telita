[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
AppId={{2A9559F0-555D-41D7-8A7B-9ED53A9EE12D}
AppName=Telita
AppVersion=1.0.0
AppPublisher=Telita
DefaultDirName={autopf}\Telita
DisableProgramGroupPage=yes
; Install for all users (requires admin privileges). To install for current user only, uncomment the next line:
; PrivilegesRequired=lowest
OutputDir=.\build\windows\installer
OutputBaseFilename=Telita_Setup
SetupIconFile=.\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkablealone

[Files]
; Main executable
Source: ".\build\windows\x64\runner\Release\telita_flutter.exe"; DestDir: "{app}"; Flags: ignoreversion
; Core backend
Source: ".\build\windows\x64\runner\Release\libcore.exe"; DestDir: "{app}"; Flags: ignoreversion
; All DLLs
Source: ".\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Flutter Data and Assets
Source: ".\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Telita"; Filename: "{app}\telita_flutter.exe"
; Desktop shortcut is checked by default because of the Tasks definition above
Name: "{autodesktop}\Telita"; Filename: "{app}\telita_flutter.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\telita_flutter.exe"; Description: "{cm:LaunchProgram,Telita}"; Flags: nowait postinstall skipifsilent
