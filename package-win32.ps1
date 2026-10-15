[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceDir,
    [Parameter(Mandatory)][string]$AssetDir,
    [string]$BinaryPath = "$PSScriptRoot/out/bin/shandalar.exe",
    [string]$OutputDirectory = "$PSScriptRoot/out"
)

$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
$assetRoot = (Resolve-Path -LiteralPath $AssetDir).Path
$binary = (Resolve-Path -LiteralPath $BinaryPath).Path
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
foreach ($asset in @('cards.dat', 'AdvStrings.txt', 'DuelArt/Duel.dat')) {
    if (!(Test-Path -LiteralPath (Join-Path $assetRoot $asset) -PathType Leaf)) {
        throw "Missing game asset: $asset"
    }
}
$sourceSha = git -C $sourceRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not read the source commit' }
$sevenZip = Get-Command 7z -ErrorAction SilentlyContinue
if ($sevenZip) {
    $sevenZipPath = $sevenZip.Source
} else {
    $sevenZipPath = "$env:ProgramFiles/7-Zip/7z.exe"
    if (!(Test-Path -LiteralPath $sevenZipPath)) { throw '7-Zip is required' }
}

# A fresh directory prevents files from earlier packages leaking into a rebuild.
$stageParent = Join-Path $outputRoot "staging/$([guid]::NewGuid().ToString('N'))"
$stage = Join-Path $stageParent 'Shandalar'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Get-ChildItem -LiteralPath $assetRoot -Force |
    Copy-Item -Destination $stage -Recurse -Force
# Copy the new binary after the assets, which may contain an original executable.
Copy-Item -LiteralPath $binary -Destination "$stage/shandalar.exe" -Force
Copy-Item -LiteralPath "$sourceRoot/LICENSE" -Destination "$stage/LICENSE-shandalar-sdl3.txt"
@'
Shandalar SDL3 (32-bit Windows)

Extract the entire Shandalar folder, then double-click shandalar.exe.
Game data is included alongside the executable. Keep these files together.
When launching from a terminal, use this folder as the current directory,
or pass its absolute path as the first argument to shandalar.exe.

Save files and settings are written into the game folder. Extract to a location
you can write to, such as your user folder.
'@ | Set-Content -LiteralPath "$stage/README-win32.txt" -Encoding utf8
@{
    source_repository = 'rlerrr/shandalar-sdl3'
    source_sha = $sourceSha
    asset_bucket = 'shandalar-dotp'
    architecture = 'x86'
} | ConvertTo-Json | Set-Content -LiteralPath "$stage/build-info.json" -Encoding utf8

$archive = Join-Path $outputRoot 'shandalar-win32.zip'
if (Test-Path -LiteralPath $archive -PathType Leaf) { Remove-Item -LiteralPath $archive }
Push-Location $stageParent
try {
    & $sevenZipPath a -tzip -mx=5 $archive Shandalar
    if ($LASTEXITCODE -ne 0) { throw "7-Zip failed with exit code $LASTEXITCODE" }
    & $sevenZipPath t $archive
    if ($LASTEXITCODE -ne 0) { throw 'ZIP integrity check failed' }
} finally {
    Pop-Location
}
Write-Output "Created $archive from source commit $sourceSha"

