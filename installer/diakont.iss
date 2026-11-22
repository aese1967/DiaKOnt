; Instalador de Windows para DiaKont by SouthDevs (Inno Setup 6).
; Lo compila GitHub Actions; localmente: iscc /DAppVersion=1.0.0 installer\diakont.iss

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6B1E4C2A-8F3D-4D7A-9C51-D1A0C0FFEE01}
AppName=DiaKont
AppVersion={#AppVersion}
AppVerName=DiaKont {#AppVersion}
AppPublisher=SouthDevs
DefaultDirName={autopf}\DiaKont
DefaultGroupName=DiaKont
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=DiaKont-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\diakont.exe

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DiaKont"; Filename: "{app}\diakont.exe"
Name: "{autodesktop}\DiaKont"; Filename: "{app}\diakont.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\diakont.exe"; Description: "{cm:LaunchProgram,DiaKont}"; Flags: nowait postinstall skipifsilent
