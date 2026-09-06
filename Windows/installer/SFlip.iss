; Build with build-installer.ps1. No signing, system settings, or app launch actions.
#ifndef DistDir
  #error DistDir is required
#endif
#ifndef BootstrapDLL
  #define BootstrapDLL DistDir + "\runtime\Microsoft.WindowsAppRuntime.Bootstrap.dll"
#endif
; From Microsoft.WindowsAppSDK.Runtime 2.4.0/include/WindowsAppSDK-VersionInfo.h.
; build-installer.ps1 verifies this pin against the application project.
#define RuntimeNugetVersion "2.4.0"
#define RuntimeMajorMinor 0x00020004
#define RuntimeMinVersion 0x0002000400000000
#define RuntimeDownloadURL "https://aka.ms/windowsappsdk/2.4/2.4.0/windowsappruntimeinstall-x64.exe"
#ifndef OutputDir
  #error OutputDir is required
#endif
#define AppVersion GetVersionNumbersString(DistDir + "\runtime\DisplaySwitcher.Windows.exe")

[Setup]
AppId={{AE3D56F2-6790-4E14-AC64-F109C402D06B}
AppName=SFlip
AppVersion={#AppVersion}
AppVerName=SFlip {#AppVersion} ({cm:UnsignedBuild})
AppPublisher=maizihk
AppPublisherURL=https://github.com/maizihk/SFlip
AppSupportURL=https://github.com/maizihk/SFlip/issues
DefaultDirName={localappdata}\Programs\SFlip
DefaultGroupName=SFlip
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
SetupArchitecture=x64
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.17763
OutputDir={#OutputDir}
OutputBaseFilename=SFlip-Setup-x64-unsigned
SetupIconFile=..\DisplaySwitcher.Native\AppIcon.ico
UninstallDisplayIcon={app}\SFlip.exe
LicenseFile=..\..\LICENSE
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
CloseApplications=no
RestartApplications=no
AppMutex=Local\SFlip.Installation
SetupMutex=Local\SFlip.Setup
Uninstallable=yes
UsePreviousAppDir=yes
LanguageDetectionMethod=uilanguage
ShowLanguageDialog=yes
UsePreviousLanguage=no

[Languages]
Name: en; MessagesFile: "compiler:Default.isl"; InfoBeforeFile: "install-info.txt"
Name: zh_CN; MessagesFile: "compiler:Languages\ChineseSimplified.isl"; InfoBeforeFile: "install-info.zh-CN.txt"

[CustomMessages]
en.UnsignedBuild=unsigned test build
zh_CN.UnsignedBuild=未签名测试版
en.DesktopShortcut=Create a desktop shortcut
zh_CN.DesktopShortcut=创建桌面快捷方式
en.NewerInstalled=A newer SFlip version is installed. Use the same or a newer installer.
zh_CN.NewerInstalled=已安装更高版本的 SFlip，请使用相同或更新版本的安装包。
en.RuntimeMissing=The current user cannot load the required Windows App Runtime 2.4 x64 (missing, outdated, or unavailable).%n%nDownload and install it from Microsoft, then click Back followed by Install to check again. No SFlip files have been changed.%n%nDownload: {#RuntimeDownloadURL}
zh_CN.RuntimeMissing=当前用户无法加载所需的 Windows App Runtime 2.4 x64（未安装、版本过旧或不可用）。%n%n请先从微软官网下载并安装运行库，再点击“上一步”，然后点击“安装”重新检测。尚未修改 SFlip 程序文件。%n%n下载地址：{#RuntimeDownloadURL}
en.RuntimePrompt=The required Windows App Runtime 2.4 x64 is missing or unavailable.%n%nOpen the Microsoft download link in your browser? Install the runtime, then return here, click Back, and click Install to check again.
zh_CN.RuntimePrompt=未检测到可用的 Windows App Runtime 2.4 x64。%n%n是否用浏览器打开微软官方下载链接？安装运行库后，请回到此处点击“上一步”，然后点击“安装”重新检测。
en.BrowserFailed=Could not open the browser. Copy the download address shown below.
zh_CN.BrowserFailed=无法打开浏览器，请复制下方显示的下载地址。

[Tasks]
Name: desktopicon; Description: "{cm:DesktopShortcut}"; Flags: unchecked

[Files]
; This is the small loader already used by the app, not the Windows runtime packages.
Source: "{#BootstrapDLL}"; DestName: "SFlipBootstrapProbe.dll"; Flags: dontcopy
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SFlip"; Filename: "{app}\SFlip.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\SFlip"; Filename: "{app}\SFlip.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Code]
function BootstrapInitialize(MajorMinor: Cardinal; VersionTag: String;
  MinVersion: Int64; Options: Cardinal): Integer;
  external 'MddBootstrapInitialize2@files:SFlipBootstrapProbe.dll stdcall delayload setuponly';
procedure BootstrapShutdown;
  external 'MddBootstrapShutdown@files:SFlipBootstrapProbe.dll stdcall delayload setuponly';
function InitializeCOM(Reserved: INT_PTR; CoInit: Cardinal): Integer;
  external 'CoInitializeEx@ole32.dll stdcall';
procedure UninitializeCOM;
  external 'CoUninitialize@ole32.dll stdcall';

function RuntimeAvailable: Boolean;
var
  COMResult, RuntimeResult: Integer;
begin
  Result := False;
  { Balance our COM reference; an existing apartment with another mode is also usable. }
  COMResult := InitializeCOM(0, 2);
  if (COMResult < 0) and (COMResult <> -2147417850) then Exit;
  try
    try
      { No UI, download, deployment, app launch, or hardware operations. }
      RuntimeResult := BootstrapInitialize({#RuntimeMajorMinor}, '', {#RuntimeMinVersion}, 0);
      Log(Format('Runtime bootstrap result: 0x%x', [RuntimeResult]));
      if RuntimeResult >= 0 then
      begin
        BootstrapShutdown;
        Result := True;
      end;
    except
      Log('Runtime bootstrap could not be loaded or called.');
    end;
  finally
    if COMResult >= 0 then UninitializeCOM;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  BrowserError: Integer;
  ExistingVersion, InstallerVersion: Int64;
begin
  Result := '';
  StrToVersion('{#AppVersion}', InstallerVersion);
  if GetPackedVersion(ExpandConstant('{app}\runtime\DisplaySwitcher.Windows.exe'), ExistingVersion) then
    if ComparePackedVersion(ExistingVersion, InstallerVersion) > 0 then
    begin
      Result := CustomMessage('NewerInstalled');
      Exit;
    end;
  { Recheck every attempt, including after the user installs the dependency externally. }
  if RuntimeAvailable then Exit;
  Result := CustomMessage('RuntimeMissing');
  { Silent installs fail without opening a browser. Interactive users choose explicitly. }
  if not WizardSilent then
    if MsgBox(CustomMessage('RuntimePrompt'), mbConfirmation, MB_YESNO) = IDYES then
      if not ShellExec('open', '{#RuntimeDownloadURL}', '', '', SW_SHOWNORMAL,
        ewNoWait, BrowserError) then
        Result := CustomMessage('BrowserFailed') + #13#10#13#10 + Result;
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
