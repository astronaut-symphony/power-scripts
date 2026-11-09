#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstaller for astronaut-symphony/power-scripts (per-user, no admin needed).

.DESCRIPTION
    Reverses the changes made by install.ps1:
      1. Removes the power-scripts folder from the user PATH
      2. Removes the right-click menu entries
      3. Deletes the power-scripts folder (and its power-scripts_backup) after confirmation
      4. Optionally restores execution policy to Restricted

    NOT removed: PowerShell 7 (a general tool you may still want) and your
    PowerShell profile / other files in Documents\PowerShell.

.USAGE
    irm https://raw.githubusercontent.com/astronaut-symphony/power-scripts/main/power-scripts/uninstall.ps1 | iex
#>

$ErrorActionPreference = 'Stop'
$TargetFolder = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell' }
$ScriptsPath  = Join-Path $TargetFolder 'power-scripts'
$BackupPath   = Join-Path $TargetFolder 'power-scripts_backup'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    !  $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# Confirm before proceeding
# ---------------------------------------------------------------------------
Write-Host "`nThis will uninstall astronaut-symphony/power-scripts:" -ForegroundColor Yellow
Write-Host "  - Remove power-scripts from PATH" -ForegroundColor Yellow
Write-Host "  - Remove the right-click menu entries" -ForegroundColor Yellow
Write-Host "  - Delete $ScriptsPath" -ForegroundColor Yellow
Write-Host "  - Optionally reset execution policy to Restricted" -ForegroundColor Yellow
Write-Host "  (PowerShell 7 and your profile will NOT be removed)" -ForegroundColor DarkGray
$confirm = Read-Host "`nProceed with uninstall? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Aborted." -ForegroundColor Red
    return
}

# ---------------------------------------------------------------------------
# 1. Remove power-scripts folder from user PATH
# ---------------------------------------------------------------------------
Write-Step "Removing power-scripts folder from PATH..."
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if (($currentPath -split ';') -contains $ScriptsPath) {
    $newPath = ($currentPath -split ';' | Where-Object { $_ -and $_ -ne $ScriptsPath }) -join ';'
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Ok "Removed $ScriptsPath from PATH. Restart your terminal to apply."
} else {
    Write-Ok "power-scripts folder not on PATH - nothing to remove."
}

# ---------------------------------------------------------------------------
# 2. Remove right-click menu entries (per-user registry, nothing else left behind)
# ---------------------------------------------------------------------------
Write-Step "Removing right-click menu entries..."
foreach ($k in 'HKCU:\Software\Classes\Directory\shell\PowerScripts', 'HKCU:\Software\Classes\Directory\Background\shell\PowerScripts') {
    if (Test-Path $k) { Remove-Item $k -Recurse -Force; Write-Ok "Removed $k" }
}
# File-type entries (e.g. .pdf) registered with -Target File
foreach ($k in Get-ChildItem 'HKCU:\Software\Classes' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like '.*' }) {
    $p = Join-Path $k.PSPath 'shell\PowerScripts'
    if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed $p" }
}

# ---------------------------------------------------------------------------
# 3. Delete the scripts folder (with confirmation) - only our own folders,
#    never the whole Documents\PowerShell
# ---------------------------------------------------------------------------
Write-Step "Removing scripts folder..."
if (Test-Path (Join-Path $TargetFolder '.git')) {
    Write-Warn2 "'$TargetFolder' is a git checkout (development copy) - leaving the files in place."
} elseif (Test-Path $ScriptsPath) {
    $confirm = Read-Host "    Delete '$ScriptsPath'? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Remove-Item -Path $ScriptsPath, $BackupPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "Deleted $ScriptsPath."
    } else {
        Write-Warn2 "Skipped. Folder left in place."
    }
} else {
    Write-Ok "Folder doesn't exist - nothing to remove."
}

# ---------------------------------------------------------------------------
# 4. Optionally restore execution policy
# ---------------------------------------------------------------------------
Write-Step "Checking execution policy..."
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -ne 'Restricted' -and $currentPolicy -ne 'Undefined') {
    $revert = Read-Host "    Reset execution policy back to Restricted? (y/N)"
    if ($revert -eq 'y' -or $revert -eq 'Y') {
        Set-ExecutionPolicy -Scope CurrentUser Restricted -Force
        Write-Ok "Execution policy reset to Restricted."
    } else {
        Write-Ok "Left as $currentPolicy."
    }
} else {
    Write-Ok "Already Restricted - no change needed."
}

Write-Host "`nUninstall complete! Restart your terminal for PATH changes to take effect.`n" -ForegroundColor Green
