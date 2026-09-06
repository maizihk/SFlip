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
$shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'SFlip\SFlip.lnk'
if ((Test-Path $configDir) -or (Test-Path $uninstallKey) -or (Test-Path $shortcut) -or
    (Get-ItemPropertyValue $runKey $runName -ErrorAction SilentlyContinue)) {
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
function Invoke-Setup([string]$Exe, [bool]$Success) {
    $log = Join-Path $work ('setup-' + [guid]::NewGuid() + '.log')
    $process = Start-Process $Exe -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$installed`"", "/LOG=`"$log`"") -PassThru
    if (-not $process.WaitForExit(120000)) { $process.Kill(); throw 'Installer exceeded test timeout.' }
    if (($process.ExitCode -eq 0) -ne $Success) {
        Get-Content $log -ErrorAction SilentlyContinue | Select-Object -Last 30 | Write-Host
        throw "Unexpected installer exit code: $($process.ExitCode)"
    }
    $script:checks++
    Assert ((Get-Content $config -Raw) -ceq $sentinel) 'User configuration was changed.'
}
try {
    # A tiny dependency fixture replaces only the bundled runtime in this test package.
    # The shipped installer has no runtime bypass switch.
    $source = Join-Path $work 'MockRuntime.cs'
    @'
using System;
class MockRuntime {
    static int Main() {
        return Environment.GetEnvironmentVariable("SFLIP_TEST_RUNTIME_FAILURE") == "1" ? 42 : 0;
    }
}
'@ | Set-Content $source
    $mock = Join-Path $work 'MockRuntime.exe'
    & "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe "/out:$mock" $source
    if ($LASTEXITCODE -ne 0) { throw 'Mock runtime compilation failed.' }
    & $iscc "/DDistDir=$(Join-Path $windows 'dist')" "/DRuntimeInstaller=$mock" "/DOutputDir=$work" (Join-Path $PSScriptRoot 'SFlip.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Test installer compilation failed.' }
    $setup = Join-Path $work 'SFlip-Setup-x64-unsigned.exe'
    $uninstaller = Join-Path $installed 'unins000.exe'
    $env:SFLIP_TEST_RUNTIME_FAILURE = '1'
    Invoke-Setup $setup $false
    Assert (-not (Test-Path (Join-Path $installed 'SFlip.exe'))) 'Runtime failure copied application files.'
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
    Assert ((Get-ItemPropertyValue $runKey $runName) -eq $portableCommand) 'Uninstall removed another copy startup entry.'
    Assert (-not (Test-Path $shortcut)) 'Uninstall left Start menu shortcut.'
    Assert (-not (Test-Path $uninstallKey)) 'Uninstall left registration.'
    foreach ($entry in @('SFlip.exe', 'runtime\DisplaySwitcher.Windows.exe')) {
        Invoke-Setup $setup $true
        Set-ItemProperty $runKey $runName ('"' + (Join-Path $installed $entry) + '"')
        Invoke-Setup $uninstaller $true
        Assert (-not (Get-ItemPropertyValue $runKey $runName -ErrorAction SilentlyContinue)) 'Uninstall retained its own startup entry.'
    }
    Assert (-not (Get-Process -Name 'DisplaySwitcher.Windows' -ErrorAction SilentlyContinue)) 'Installer launched SFlip.'
    Write-Host "Installer lifecycle: $checks checks passed (simulated runtime; no app launch)."
} finally {
    Remove-Item Env:SFLIP_TEST_RUNTIME_FAILURE -ErrorAction SilentlyContinue
    Remove-ItemProperty $runKey $runName -ErrorAction SilentlyContinue
    Remove-Item $configDir -Recurse -Force -ErrorAction SilentlyContinue
    # Retain failure logs in the ephemeral runner for diagnosis; never upload user data.
}
