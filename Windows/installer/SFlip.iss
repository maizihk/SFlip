; Build with build-installer.ps1. No signing, system settings, or app launch actions.
#ifndef DistDir
  #error DistDir is required
#endif
#ifndef RuntimeInstaller
  #error RuntimeInstaller is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#define AppVersion GetVersionNumbersString(DistDir + "\runtime\DisplaySwitcher.Windows.exe")

[Setup]
AppId={{AE3D56F2-6790-4E14-AC64-F109C402D06B}
AppName=SFlip
AppVersion={#AppVersion}
AppVerName=SFlip {#AppVersion} (unsigned test build)
AppPublisher=maizihk
AppPublisherURL=https://github.com/maizihk/SFlip
AppSupportURL=https://github.com/maizihk/SFlip/issues
DefaultDirName={localappdata}\Programs\SFlip
DefaultGroupName=SFlip
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.17763
OutputDir={#OutputDir}
OutputBaseFilename=SFlip-Setup-x64-unsigned
SetupIconFile=..\DisplaySwitcher.Native\AppIcon.ico
UninstallDisplayIcon={app}\SFlip.exe
LicenseFile=..\..\LICENSE
InfoBeforeFile=install-info.txt
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
CloseApplications=no
RestartApplications=no
AppMutex=Local\SFlip.Installation
SetupMutex=Local\SFlip.Setup
Uninstallable=yes
UsePreviousAppDir=yes

[Tasks]
Name: desktopicon; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#RuntimeInstaller}"; DestName: "WindowsAppRuntimeInstall-x64.exe"; Flags: dontcopy

[Icons]
Name: "{group}\SFlip"; Filename: "{app}\SFlip.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\SFlip"; Filename: "{app}\SFlip.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Code]
var
  RuntimeReady: Boolean;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ExitCode: Integer;
  ExistingVersion, InstallerVersion: Int64;
begin
  Result := '';
  { Never downgrade binaries underneath settings produced by a newer version. }
  StrToVersion('{#AppVersion}', InstallerVersion);
  if GetPackedVersion(ExpandConstant('{app}\runtime\DisplaySwitcher.Windows.exe'), ExistingVersion) then
    if ComparePackedVersion(ExistingVersion, InstallerVersion) > 0 then
    begin
      Result := 'A newer SFlip version is installed. Use the same or a newer installer.';
      Exit;
    end;
  if RuntimeReady then Exit;
  WizardForm.StatusLabel.Caption := 'Checking and installing Microsoft Windows App Runtime...';
  ExtractTemporaryFile('WindowsAppRuntimeInstall-x64.exe');
  { Microsoft checks package family, architecture, version and health. No --force. }
  if not Exec(ExpandConstant('{tmp}\WindowsAppRuntimeInstall-x64.exe'), '--quiet',
    '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
    Result := 'Could not start Microsoft Windows App Runtime setup. No SFlip files were installed.'
  else if ExitCode <> 0 then
    Result := Format('Microsoft Windows App Runtime setup failed (code %d). No SFlip files were installed. Check Windows installation policy and retry.', [ExitCode])
  else
    RuntimeReady := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  StartupCommand: String;
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  { Preserve a portable copy's startup entry. Never touch application settings. }
  if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run',
    'DisplaySwitcher.Windows', StartupCommand) then
    if (CompareText(Trim(StartupCommand), '"' + ExpandConstant('{app}\SFlip.exe') + '"') = 0) or
       (CompareText(Trim(StartupCommand), '"' + ExpandConstant('{app}\runtime\DisplaySwitcher.Windows.exe') + '"') = 0) then
      RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'DisplaySwitcher.Windows');
end;
