param([string]$IsccPath)
$ErrorActionPreference = 'Stop'
$dist = Join-Path $PSScriptRoot 'dist'
$output = Join-Path $PSScriptRoot 'outputs'
$cache = Join-Path $PSScriptRoot '.build\installer-tools'
New-Item -ItemType Directory -Force $cache, $output | Out-Null

function Get-VerifiedDownload([string]$Url, [string]$Path, [string]$Sha256) {
    if (-not (Test-Path -LiteralPath $Path)) {
        $temporary = "$Path.download"
        try {
            Invoke-WebRequest -Uri $Url -OutFile $temporary
            if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $Sha256) {
                throw 'Downloaded installer checksum does not match the pinned release.'
            }
            Move-Item -LiteralPath $temporary -Destination $Path -Force
        } finally {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
        }
    }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Sha256) {
        throw "Cached installer checksum mismatch: $([IO.Path]::GetFileName($Path))"
    }
}

# Versions are pinned to official releases; update hashes only after upstream verification.
$runtimeVersion = '2.4.0'
[xml]$project = Get-Content (Join-Path $PSScriptRoot 'DisplaySwitcher.Native\DisplaySwitcher.Native.vcxproj') -Raw
$runtimeReference = $project.SelectSingleNode("//*[local-name()='PackageReference' and @Include='Microsoft.WindowsAppSDK.Runtime']")
if ($runtimeReference.Version -ne $runtimeVersion) { throw 'Update the installer runtime pin to match the application.' }
$runtimeInstaller = Join-Path $cache 'WindowsAppRuntimeInstall-2.4.0-x64.exe'
Get-VerifiedDownload 'https://aka.ms/windowsappsdk/2.4/2.4.0/windowsappruntimeinstall-x64.exe' $runtimeInstaller `
    '851c35b0b0a59ce4c55f9171f601193322fc3413143b0dc3390ea11e14cfa7fc'
$signature = Get-AuthenticodeSignature -LiteralPath $runtimeInstaller
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)') {
    throw 'Microsoft runtime installer signature validation failed.'
}
if (-not $IsccPath) {
    $compilerSetup = Join-Path $cache 'innosetup-7.1.0-x64.exe'
    Get-VerifiedDownload 'https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe' $compilerSetup `
        '0362a383ed217d4c4239b5933866dd96d3eb2102737da92f80f6057a4b40df2f'
    $compilerDir = Join-Path $cache 'inno-7.1.0'
    $IsccPath = Join-Path $compilerDir 'ISCC.exe'
    if (-not (Test-Path -LiteralPath $IsccPath)) {
        $process = Start-Process -FilePath $compilerSetup -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', "/DIR=`"$compilerDir`"") -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw 'Inno Setup compiler installation failed.' }
    }
}
$required = @('SFlip.exe', 'runtime\DisplaySwitcher.Windows.exe', 'runtime\DisplaySwitcher.Windows.pri',
    'runtime\DisplaySwitcher.Native.winmd', 'runtime\Microsoft.WindowsAppRuntime.Bootstrap.dll',
    'runtime\App.xbf', 'runtime\SettingsWindow.xbf', 'runtime\AppIcon.ico', 'runtime\AppIcon-256.png')
foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $dist $file))) { throw "Build the portable distribution first; missing $file" }
}
$installer = Join-Path $output 'SFlip-Setup-x64-unsigned.exe'
if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer }
& $IsccPath "/DDistDir=$dist" "/DRuntimeInstaller=$runtimeInstaller" "/DOutputDir=$output" (Join-Path $PSScriptRoot 'installer\SFlip.iss')
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $installer)) { throw 'SFlip installer compilation failed.' }
$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($installer))" | Set-Content (Join-Path $output 'SFlip-Setup-x64-unsigned.sha256') -Encoding ascii
Write-Host "Installer built: $installer"
