[CmdletBinding()]
param(
    [switch]$PrepareOnly,
    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$OfficialUrl = 'https://dlcdnets.asus.com/pub/ASUS/Accessory/Keyboard_Mouse/ROG_GLADIUS_III_WIRELESS_AIMPOINT/P711_FirmwareAutoUpdate_1.0.0.20.zip?model=ROG%20GLADIUS%20III%20WIRELESS%20AIMPOINT'
$ExpectedZipSha256 = '88B2F60DBD56553B5407AA65176669A09DBCCE5A1C8D4CBB7C5E72BCFDCD962C'
$ExpectedFirmwareSha256 = '051FD11B4383B59FA10C273A692912FA750F3157068DD45CE38EAB7135C1FD12'
$ExpectedToolHashes = @{
    'peripheral_fwu_pro.exe' = 'A83095716101C818D855ACED38385CEE2D5E1134A72CB4800B8319C81AB18841'
    'HidInterruptHandle.dll' = '30BA2F150ABACCFC8C4A85210BF098680A57181DF432963477D9FA3D409ED188'
    'InterruptTransfer.dll' = '9BB8F484D337BF81DEAE97D4A19B709C8C83463E8F946CE5849A82AFEF4FA33C'
}
$PackageName = 'P711_FirmwareAutoUpdate_1.0.0.20.zip'
$ExtractedFolderName = 'P711_FirmwareAutoUpdate_1.0.0.20'

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Write-Status {
    param([string]$Message)
    Write-Host "[patchB setup] $Message"
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$vendorRoot = Join-Path $repoRoot '.vendor'
$archivePath = Join-Path $vendorRoot $PackageName
$extractRoot = Join-Path $vendorRoot 'extracted'
$firmwareDir = Join-Path (Join-Path $extractRoot $ExtractedFolderName) 'Firmware'
$stockFirmwarePath = Join-Path $firmwareDir 'P711_MOUSE_V03_00_10.bin'
$flasherPath = Join-Path $firmwareDir 'peripheral_fwu_pro.exe'
$installerPath = Join-Path $repoRoot 'install-patchB.ps1'

if (-not (Test-Path -LiteralPath $vendorRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $vendorRoot | Out-Null
}

$needDownload = $true
if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
    $cachedHash = Get-Sha256 -Path $archivePath
    if ($cachedHash -eq $ExpectedZipSha256) {
        Write-Status 'Verified cached ASUS package.'
        $needDownload = $false
    }
    else {
        throw "Cached ASUS package has an unexpected SHA-256: $cachedHash`nDelete this file and retry: $archivePath"
    }
}

if ($needDownload) {
    $temporaryDownload = Join-Path $vendorRoot ($PackageName + '.' + [Guid]::NewGuid().ToString('N') + '.partial')
    Write-Status 'Downloading the official ASUS V1.0.0.20 updater package...'

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $OfficialUrl -OutFile $temporaryDownload -UseBasicParsing

        $downloadedHash = Get-Sha256 -Path $temporaryDownload
        if ($downloadedHash -ne $ExpectedZipSha256) {
            throw "Downloaded package SHA-256 mismatch: $downloadedHash"
        }

        Move-Item -LiteralPath $temporaryDownload -Destination $archivePath
        Write-Status "Verified official package: $downloadedHash"
    }
    finally {
        if (Test-Path -LiteralPath $temporaryDownload -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryDownload -Force
        }
    }
}

$firmwareReady = $false
if ((Test-Path -LiteralPath $stockFirmwarePath -PathType Leaf) -and (Test-Path -LiteralPath $flasherPath -PathType Leaf)) {
    if ((Get-Sha256 -Path $stockFirmwarePath) -eq $ExpectedFirmwareSha256) {
        $firmwareReady = $true
        foreach ($toolName in $ExpectedToolHashes.Keys) {
            $toolPath = Join-Path $firmwareDir $toolName
            if ((-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) -or ((Get-Sha256 -Path $toolPath) -ne $ExpectedToolHashes[$toolName])) {
                $firmwareReady = $false
                break
            }
        }
    }
}

if (-not $firmwareReady) {
    Write-Status 'Extracting the verified ASUS package...'
    if (-not (Test-Path -LiteralPath $extractRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $extractRoot | Out-Null
    }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
}

if (-not (Test-Path -LiteralPath $stockFirmwarePath -PathType Leaf)) {
    throw "The verified package did not contain the expected firmware: $stockFirmwarePath"
}
if (-not (Test-Path -LiteralPath $flasherPath -PathType Leaf)) {
    throw "The verified package did not contain the official flasher: $flasherPath"
}

$stockHash = Get-Sha256 -Path $stockFirmwarePath
if ($stockHash -ne $ExpectedFirmwareSha256) {
    throw "Extracted stock firmware SHA-256 mismatch: $stockHash"
}

foreach ($toolName in $ExpectedToolHashes.Keys) {
    $toolPath = Join-Path $firmwareDir $toolName
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
        throw "The verified package did not contain the required ASUS component: $toolName"
    }
    $toolHash = Get-Sha256 -Path $toolPath
    if ($toolHash -ne $ExpectedToolHashes[$toolName]) {
        throw "ASUS component SHA-256 mismatch for $toolName`: $toolHash"
    }
}

Write-Status 'Verified the stock firmware, official flasher, and runtime DLLs.'
Write-Status "Official Firmware directory is ready: $firmwareDir"

if ($PrepareOnly) {
    Write-Status 'Preparation test complete; no patch was generated and nothing was flashed.'
    exit 0
}

$installerArguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $installerPath,
    '-FirmwareDirectory', $firmwareDir,
    '-Install'
)
if ($Yes) {
    $installerArguments += '-Yes'
}

& powershell.exe @installerArguments
exit $LASTEXITCODE
