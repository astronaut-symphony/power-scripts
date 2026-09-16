#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstaller for astronaut-symphony/power-scripts.

.DESCRIPTION
    Reverses the changes made by install.ps1:
      1. Removes the power-scripts folder from the user PATH
      2. Deletes the repo folder (Documents\PowerShell) after confirmation
      3. Optionally restores execution policy to Restricted

    PowerShell 7 is NOT uninstalled — it's a general tool you may still want.

.USAGE
    irm https://raw.githubusercontent.com/astronaut-symphony/power-scripts/main/power-scripts/uninstall.ps1 | iex
#>

$ErrorActionPreference = 'Stop'
$TargetFolder = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { Join-Path $HOME 'Documents\PowerShell' }
$ScriptsPath  = Join-Path $TargetFolder 'power-scripts'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    !  $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# Confirm before proceeding
# ---------------------------------------------------------------------------
Write-Host "`nThis will uninstall astronaut-symphony/power-scripts:" -ForegroundColor Yellow
Write-Host "  - Remove power-scripts from PATH" -ForegroundColor Yellow
Write-Host "  - Delete $TargetFolder" -ForegroundColor Yellow
Write-Host "  - Optionally reset execution policy to Restricted" -ForegroundColor Yellow
Write-Host "  (PowerShell 7 will NOT be uninstalled)" -ForegroundColor DarkGray
$confirm = Read-Host "`nProceed with uninstall? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Aborted." -ForegroundColor Red
    exit
}

# ---------------------------------------------------------------------------
# 1. Remove power-scripts folder from user PATH
# ---------------------------------------------------------------------------
Write-Step "Removing power-scripts folder from PATH..."
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($currentPath -like "*$ScriptsPath*") {
    $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $ScriptsPath }) -join ';'
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Ok "Removed $ScriptsPath from PATH. Restart your terminal to apply."
} else {
    Write-Ok "power-scripts folder not on PATH — nothing to remove."
}

# ---------------------------------------------------------------------------
# 2. Delete the repo folder (with confirmation)
# ---------------------------------------------------------------------------
Write-Step "Removing repo folder..."
if (Test-Path $TargetFolder) {
    $confirm = Read-Host "    Delete '$TargetFolder'? This removes all scripts. (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Remove-Item -Path $TargetFolder -Recurse -Force
        Write-Ok "Deleted $TargetFolder."
    } else {
        Write-Warn2 "Skipped. Folder left in place."
    }
} else {
    Write-Ok "Folder doesn't exist — nothing to remove."
}

# ---------------------------------------------------------------------------
# 3. Optionally restore execution policy
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
    Write-Ok "Already Restricted — no change needed."
}

Write-Host "`nUninstall complete! Restart your terminal for PATH changes to take effect.`n" -ForegroundColor Green
