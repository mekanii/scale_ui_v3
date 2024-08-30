; Inno Setup Script for ScaleUI
[Setup]
AppName=scale_ui_v3
AppVersion=1.0
DefaultDirName={pf}\scale_ui_v3
DefaultGroupName=scale_ui_v3
OutputDir=.
OutputBaseFilename=scale_ui_v3Installer
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "dependencies\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Flags: waituntilterminated