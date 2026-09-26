[CmdletBinding()]
param(
    [string]$Destination
)

$ErrorActionPreference = 'Stop'
$Source = Join-Path $PSScriptRoot 'CivVITrainer'

if (-not (Test-Path (Join-Path $Source 'CivVITrainer.modinfo') -PathType Leaf)) {
    throw "CivVITrainer.modinfo was not found beside this installer. Extract the complete release ZIP before running it."
}

if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    if ([string]::IsNullOrWhiteSpace($Documents)) {
        throw 'Windows did not report a Documents folder. Pass -Destination with the full Civ VI Mods path.'
    }
    $ModsDirectory = Join-Path $Documents 'My Games\Sid Meier''s Civilization VI\Mods'
    $Destination = Join-Path $ModsDirectory 'CivVITrainer'
}

$Destination = [System.IO.Path]::GetFullPath($Destination)
$DestinationParent = Split-Path -Parent $Destination
New-Item -ItemType Directory -Path $DestinationParent -Force | Out-Null
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$DestinationUI = Join-Path $Destination 'UI'
New-Item -ItemType Directory -Path $DestinationUI -Force | Out-Null

Copy-Item -Path (Join-Path $Source 'CivVITrainer.modinfo') -Destination $Destination -Force
Copy-Item -Path (Join-Path $Source 'UI\*') -Destination $DestinationUI -Recurse -Force

$InstalledManifest = Join-Path $Destination 'CivVITrainer.modinfo'
if (-not (Test-Path $InstalledManifest -PathType Leaf)) {
    throw "Installation verification failed: $InstalledManifest is missing."
}

Write-Host ''
Write-Host 'Civ VI Strategic Advisor installed successfully.' -ForegroundColor Green
Write-Host "Location: $Destination"
Write-Host ''
Write-Host 'Restart Civilization VI, then enable it under Additional Content > Mods.'
