[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$FirmwareDirectory,

    [switch]$Install,

    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedOriginalSha256 = '051FD11B4383B59FA10C273A692912FA750F3157068DD45CE38EAB7135C1FD12'
$ExpectedPatchBSha256 = '8BB73F1132A149F5EC6B0FA34E6CC71D4A22BC36AFCE64CF00D8222A6ABE8DB0'
$ExpectedSize = 1044480
$PatchOffset = 0x38E98
$ChecksumOffset = 0x4DFFC
$ChecksumStart = 0x1C000
$OriginalByte = 0x0B
$PatchedByte = 0x0C

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-Sum32Le {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][int]$Start,
        [Parameter(Mandatory = $true)][int]$EndExclusive
    )

    if (($Start % 4) -ne 0 -or ($EndExclusive % 4) -ne 0) {
        throw 'Checksum boundaries must be four-byte aligned.'
    }

    [uint64]$sum = 0
    [uint64]$mask32 = [uint32]::MaxValue
    for ($offset = $Start; $offset -lt $EndExclusive; $offset += 4) {
        $word = [BitConverter]::ToUInt32($Bytes, $offset)
        $sum = ($sum + [uint64]$word) -band $mask32
    }
    return [uint32]$sum
}

function Write-Status {
    param([string]$Message)
    Write-Host "[patchB] $Message"
}

$FirmwareDirectory = $FirmwareDirectory.Trim().Trim('"')
$firmwareDir = (Resolve-Path -LiteralPath $FirmwareDirectory).Path
$inputPath = Join-Path $firmwareDir 'P711_MOUSE_V03_00_10.bin'
$outputPath = Join-Path $firmwareDir 'P711_MOUSE_V03_00_10_patchB.bin'
$flasherPath = Join-Path $firmwareDir 'peripheral_fwu_pro.exe'

if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
    throw "Official firmware not found: $inputPath"
}

$inputFile = Get-Item -LiteralPath $inputPath
if ($inputFile.Length -ne $ExpectedSize) {
    throw "Unexpected firmware size: $($inputFile.Length) bytes. Expected $ExpectedSize bytes."
}

$originalHash = Get-Sha256 -Path $inputPath
if ($originalHash -ne $ExpectedOriginalSha256) {
    throw "Unsupported firmware SHA-256: $originalHash`nExpected: $ExpectedOriginalSha256"
}
Write-Status "Verified stock firmware: $originalHash"

[byte[]]$original = [IO.File]::ReadAllBytes($inputPath)
if ($original[$PatchOffset] -ne $OriginalByte) {
    throw ('Unexpected byte at 0x{0:X}: 0x{1:X2}' -f $PatchOffset, $original[$PatchOffset])
}

$storedOriginalChecksum = [BitConverter]::ToUInt32($original, $ChecksumOffset)
$calculatedOriginalChecksum = Get-Sum32Le -Bytes $original -Start $ChecksumStart -EndExclusive $ChecksumOffset
if ($storedOriginalChecksum -ne $calculatedOriginalChecksum) {
    throw ('Stock checksum mismatch: stored 0x{0:X8}, calculated 0x{1:X8}' -f $storedOriginalChecksum, $calculatedOriginalChecksum)
}

$useExistingOutput = $false
if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
    $existingHash = Get-Sha256 -Path $outputPath
    if ($existingHash -ne $ExpectedPatchBSha256) {
        throw "Refusing to overwrite unexpected file: $outputPath`nSHA-256: $existingHash"
    }
    Write-Status 'Existing patchB image is valid; reusing it.'
    $useExistingOutput = $true
}

if (-not $useExistingOutput) {
    [byte[]]$patched = $original.Clone()
    $patched[$PatchOffset] = $PatchedByte

    $patchedChecksum = Get-Sum32Le -Bytes $patched -Start $ChecksumStart -EndExclusive $ChecksumOffset
    $checksumBytes = [BitConverter]::GetBytes([uint32]$patchedChecksum)
    [Array]::Copy($checksumBytes, 0, $patched, $ChecksumOffset, 4)

    [IO.File]::WriteAllBytes($outputPath, $patched)
    Write-Status ('Patched slot 5 at 0x{0:X}: 0x{1:X2} -> 0x{2:X2}' -f $PatchOffset, $OriginalByte, $PatchedByte)
    Write-Status ('Recomputed checksum: 0x{0:X8}' -f $patchedChecksum)
}

$patchedHash = Get-Sha256 -Path $outputPath
if ($patchedHash -ne $ExpectedPatchBSha256) {
    throw "Generated patchB SHA-256 mismatch: $patchedHash"
}

Write-Status "Verified patchB: $patchedHash"
Write-Status "Output: $outputPath"
Write-Warning 'patchB intentionally disables the physical DPI button. It does not repair the P1.11 electrical fault.'

if (-not $Install) {
    Write-Status 'Patch creation complete. Re-run with -Install to flash it.'
    exit 0
}

if (-not (Test-Path -LiteralPath $flasherPath -PathType Leaf)) {
    throw "Official flasher not found: $flasherPath"
}

if (-not $Yes) {
    Write-Host ''
    Write-Host 'Before flashing:' -ForegroundColor Yellow
    Write-Host '  1. Put the mouse in wired mode and connect its USB cable.'
    Write-Host '  2. Keep power connected until the updater finishes.'
    Write-Host '  3. Confirm this is a P711 running V03.00.10.'
    Write-Host '  4. Understand that the top DPI button will be disabled.'
    $confirmation = Read-Host 'Type PATCHB to continue'
    if ($confirmation -cne 'PATCHB') {
        Write-Status 'Flash cancelled. The generated patch file was kept.'
        exit 2
    }
}

Write-Status 'Starting the official firmware updater. Do not disconnect the mouse.'
Push-Location -LiteralPath $firmwareDir
try {
    & $flasherPath 'm' '1A70' '1A71' '112' '200' 'FF01' 'FF01' '4' $outputPath 'CVER:n'
    $flashExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($flashExitCode -ne 0) {
    throw "Firmware updater exited with code $flashExitCode. Keep the mouse connected and use the stock image to recover if it remains in Bootloader."
}

Write-Status 'Updater completed successfully. Power-cycle the mouse and verify buttons, wheel, movement, lighting, and connectivity.'
