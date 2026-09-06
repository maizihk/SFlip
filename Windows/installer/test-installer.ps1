# Runs only on an ephemeral GitHub runner; never starts SFlip or hardware services.
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Installer lifecycle tests require an ephemeral GitHub Actions runner.' }
$windows = Split-Path $PSScriptRoot -Parent
$iscc = Join-Path $windows '.build\installer-tools\inno-7.1.0\ISCC.exe'
$work = Join-Path $env:RUNNER_TEMP ('sflip-installer-' + [guid]::NewGuid())
$installed = Join-Path $work 'Installed'
$configDir = Join-Path $env:LOCALAPPDATA 'DisplaySwitcher'
$config = Join-Path $configDir 'settings.json'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'DisplaySwitcher.Windows'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{AE3D56F2-6790-4E14-AC64-F109C402D06B}_is1'
function Get-StartupCommand {
    $key = Get-Item -LiteralPath $runKey -ErrorAction SilentlyContinue
    if ($null -eq $key) { return $null }
    return $key.GetValue($runName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
}
$shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'SFlip\SFlip.lnk'
if ((Test-Path $configDir) -or (Test-Path $uninstallKey) -or (Test-Path $shortcut) -or
    (Get-StartupCommand)) {
    throw 'Tests require a clean SFlip user profile; refusing to replace existing data.'
}
New-Item -ItemType Directory -Force $work, $configDir | Out-Null
$sentinel = '{"installerTest":"preserve exactly"}'
Set-Content $config $sentinel -NoNewline
$checks = 0
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Invoke-Setup([string]$Exe, [bool]$Success, [string]$Language = 'zh_CN') {
    $log = Join-Path $work ('setup-' + [guid]::NewGuid() + '.log')
    Write-Host "Testing $([IO.Path]::GetFileName($Exe)); expected success=$Success"
    # Inno uninstall hands off to a temporary child process. Wait for the entire tree.
    $process = Start-Process $Exe -Wait -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LANG=$Language", "/DIR=`"$installed`"", "/LOG=`"$log`"") -PassThru
    if (($process.ExitCode -eq 0) -ne $Success) {
        Get-Content $log -ErrorAction SilentlyContinue | Select-Object -Last 30 | Write-Host
        throw "Unexpected installer exit code: $($process.ExitCode)"
    }
    $script:checks++
    $script:lastLog = Get-Content $log -Raw
    if ($Success -and [IO.Path]::GetFileName($Exe) -eq 'SFlip-Setup-x64-unsigned.exe') {
        $script:uninstaller = (Get-ItemPropertyValue $uninstallKey 'UninstallString').Trim('"')
        Assert (Test-Path -LiteralPath $script:uninstaller) 'Registered uninstaller does not exist.'
        $displayName = Get-ItemPropertyValue $uninstallKey 'DisplayName'
        Assert ($displayName.Contains($(if ($Language -eq 'zh_CN') { '未签名测试版' } else { 'unsigned test build' }))) 'Installer product name was not localized.'
    }
    Assert ((Get-Content $config -Raw) -ceq $sentinel) 'User configuration was changed.'
}
try {
    # Replace only the bootstrap DLL in the test package. Never start the real application.
    # No runtime bypass flag is exposed by the shipped installer.
    $source = Join-Path $work 'MockBootstrap.cpp'
    @'
#include <windows.h>
#include <cwchar>
extern "C" __declspec(dllexport) HRESULT WINAPI MddBootstrapInitialize2(
    UINT32 majorMinor, PCWSTR tag, UINT64 minimum, UINT32 options) {
    // Validate the real x64 ABI and exact SDK requirements supplied by Pascal Script.
    if (majorMinor != 0x00020004) return HRESULT_FROM_WIN32(ERROR_BAD_ARGUMENTS);
    // Windows accepts both null and an empty string for the stable channel.
    if (tag && *tag) return HRESULT_FROM_WIN32(ERROR_INVALID_NAME);
    if (minimum != 0x0002000400000000ULL) return HRESULT_FROM_WIN32(ERROR_OLD_WIN_VERSION);
    if (options != 0) return E_INVALIDARG;
    wchar_t failure[8]{};
    GetEnvironmentVariableW(L"SFLIP_TEST_RUNTIME_FAILURE", failure, 8);
    if (failure[0] == L'1') return HRESULT_FROM_WIN32(ERROR_INSTALL_RESOLVE_DEPENDENCY_FAILED);
    if (failure[0] == L'2') return E_FAIL;
    return S_OK;
}
extern "C" __declspec(dllexport) void WINAPI MddBootstrapShutdown() {}
'@ | Set-Content $source
    $mock = Join-Path $work 'MockBootstrap.dll'
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $vs = & $vswhere -latest -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw 'C++ toolchain missing for bootstrap fixture.' }
    $vcvars = Join-Path ($vs | Select-Object -First 1) 'VC\Auxiliary\Build\vcvars64.bat'
    $command = Join-Path $work 'build-mock.cmd'
    @"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b 1
cl /nologo /LD /MT /EHsc /Fo"$work\MockBootstrap.obj" /Fe"$mock" "$source" /link /IMPLIB:"$work\MockBootstrap.lib"
"@ | Set-Content $command -Encoding ascii
    & cmd.exe /d /c $command
    if ($LASTEXITCODE -ne 0) { throw 'Mock bootstrap compilation failed.' }
    & $iscc "/DDistDir=$(Join-Path $windows 'dist')" "/DBootstrapDLL=$mock" "/DOutputDir=$work" (Join-Path $PSScriptRoot 'SFlip.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Test installer compilation failed.' }
    $setup = Join-Path $work 'SFlip-Setup-x64-unsigned.exe'
    $uninstaller = $null
    $env:SFLIP_TEST_RUNTIME_FAILURE = '1'
    Invoke-Setup $setup $false
    Assert (-not (Test-Path (Join-Path $installed 'SFlip.exe'))) 'Runtime failure copied application files.'
    Assert ($lastLog.Contains('当前用户无法加载所需的')) 'Missing Chinese dependency guidance.'
    Assert ($lastLog.Contains('https://aka.ms/windowsappsdk/2.4/2.4.0/windowsappruntimeinstall-x64.exe')) 'Missing official x64 download link.'
    Invoke-Setup $setup $false 'en'
    Assert ($lastLog.Contains('The current user cannot load')) 'Missing English dependency guidance.'
    $env:SFLIP_TEST_RUNTIME_FAILURE = '2'
    Invoke-Setup $setup $false
    Assert (-not (Test-Path (Join-Path $installed 'SFlip.exe'))) 'Unexpected probe failure was accepted.'
    Remove-Item Env:SFLIP_TEST_RUNTIME_FAILURE
    Invoke-Setup $setup $true
    Assert (Test-Path $uninstallKey) 'Missing uninstall registration.'
    Assert (Test-Path $shortcut) 'Missing Start menu shortcut.'
    foreach ($file in Get-ChildItem (Join-Path $windows 'dist') -File -Recurse) {
        $relative = [IO.Path]::GetRelativePath((Join-Path $windows 'dist'), $file.FullName)
        Assert ((Get-FileHash $file.FullName).Hash -eq (Get-FileHash (Join-Path $installed $relative)).Hash) "Installed file differs: $relative"
    }
    Invoke-Setup $setup $true # Same-version upgrade/reinstall.
    $env:SFLIP_TEST_RUNTIME_FAILURE = '1'
    Invoke-Setup $setup $false
    Assert (Test-Path $uninstaller) 'Failed upgrade removed the existing installation.'
    Remove-Item Env:SFLIP_TEST_RUNTIME_FAILURE
    # Give the installed binary a newer version without running it.
    $newerSource = Join-Path $work 'NewerVersion.cs'
    '[assembly: System.Reflection.AssemblyFileVersion("99.0.0.0")] class NewerVersion { static void Main() {} }' | Set-Content $newerSource
    $installedRuntime = Join-Path $installed 'runtime\DisplaySwitcher.Windows.exe'
    & "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe "/out:$installedRuntime" $newerSource
    if ($LASTEXITCODE -ne 0) { throw 'Newer-version fixture compilation failed.' }
    $newerHash = (Get-FileHash $installedRuntime).Hash
    Invoke-Setup $setup $false
    Assert ((Get-FileHash $installedRuntime).Hash -eq $newerHash) 'Downgrade replaced a newer binary.'
    Copy-Item (Join-Path $windows 'dist\runtime\DisplaySwitcher.Windows.exe') $installedRuntime -Force
    $mutex = [Threading.Mutex]::new($false, 'Local\SFlip.Installation')
    try {
        Invoke-Setup $setup $false
        Invoke-Setup $uninstaller $false
        Assert (Test-Path (Join-Path $installed 'SFlip.exe')) 'Running-instance protection removed app files.'
    } finally { $mutex.Dispose() }
    if (-not (Test-Path $runKey)) { New-Item $runKey | Out-Null }
    $portableCommand = '"C:\SFlip-test-portable\SFlip.exe"'
    New-ItemProperty $runKey $runName -Value $portableCommand -PropertyType String -Force | Out-Null
    Invoke-Setup $uninstaller $true
    Assert ((Get-StartupCommand) -eq $portableCommand) 'Uninstall removed another copy startup entry.'
    Assert (-not (Test-Path $shortcut)) 'Uninstall left Start menu shortcut.'
    Assert (-not (Test-Path $uninstallKey)) 'Uninstall left registration.'
    foreach ($entry in @('SFlip.exe', 'runtime\DisplaySwitcher.Windows.exe')) {
        Invoke-Setup $setup $true
        Set-ItemProperty $runKey $runName ('"' + (Join-Path $installed $entry) + '"')
        Invoke-Setup $uninstaller $true
        Assert (-not (Get-StartupCommand)) 'Uninstall retained its own startup entry.'
    }
    Assert (-not (Get-Process -Name 'DisplaySwitcher.Windows' -ErrorAction SilentlyContinue)) 'Installer launched SFlip.'
    Write-Host "Installer lifecycle: $checks checks passed (simulated bootstrap; Chinese/English; no app launch)."
} finally {
    Remove-Item Env:SFLIP_TEST_RUNTIME_FAILURE -ErrorAction SilentlyContinue
    Remove-ItemProperty $runKey $runName -ErrorAction SilentlyContinue
    Remove-Item $configDir -Recurse -Force -ErrorAction SilentlyContinue
    # Retain failure logs in the ephemeral runner for diagnosis; never upload user data.
}
