#Requires -Version 5.1
<#
.SYNOPSIS
    One-click installer for astronaut-symphony/power-scripts.

.DESCRIPTION
    Automates the manual setup steps from the README:
      1. Checks for PowerShell 7 (installs it if missing)
      2. Sets up the repo in Documents\PowerShell — if that folder already
         exists and isn't this repo, it's backed up as a whole (renamed to
         Documents\PowerShell_backup_<timestamp>) before a clean clone,
         nothing is deleted
      3. Adds the power-scripts folder to the user PATH
      4. Sets the execution policy so the scripts can run

    (Right-click context menu integration is optional — answer Y when asked
    and the installer registers the scripts via Register-ContextMenuScript.ps1.)

    Safe to re-run — every step checks current state before changing anything.

.USAGE
    Double-click install.bat (recommended, handles elevation automatically), or run:
        irm https://raw.githubusercontent.com/astronaut-symphony/power-scripts/main/power-scripts/install.ps1 | iex
#>

$ErrorActionPreference = 'Stop'
$RepoUrl      = 'https://github.com/astronaut-symphony/power-scripts'
$TargetFolder = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { Join-Path $HOME 'Documents\PowerShell' }
$ScriptsPath  = Join-Path $TargetFolder 'power-scripts'   # only this subfolder goes on PATH; power-config does not

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    !  $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# Confirm before proceeding
# ---------------------------------------------------------------------------
Write-Host "`nThis will install astronaut-symphony/power-scripts to $TargetFolder" -ForegroundColor Yellow
Write-Host "  - Install PowerShell 7 (if missing)" -ForegroundColor Yellow
Write-Host "  - Clone/pull the repo" -ForegroundColor Yellow
Write-Host "  - Add power-scripts to PATH" -ForegroundColor Yellow
Write-Host "  - Set execution policy to RemoteSigned" -ForegroundColor Yellow
$confirm = Read-Host "`nProceed with install? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Aborted." -ForegroundColor Red
    exit
}

# ---------------------------------------------------------------------------
# 1. Ensure PowerShell 7 is installed
# ---------------------------------------------------------------------------
Write-Step "Checking for PowerShell 7..."
$pwsh7 = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwsh7) {
    Write-Warn2 "PowerShell 7 not found. Downloading and installing..."
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
        $asset   = $release.assets | Where-Object { $_.name -like '*win-x64.msi' } | Select-Object -First 1
        $msiPath = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msiPath
        Write-Host "    Installing PowerShell 7 (this may prompt a UAC dialog)..."
        Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart" -Wait
        Remove-Item $msiPath -Force
        Write-Ok "PowerShell 7 installed."
    } catch {
        Write-Warn2 "Automatic install failed: $($_.Exception.Message)"
        Write-Warn2 "Download it manually from https://github.com/PowerShell/PowerShell/releases/latest"
    }
} else {
    Write-Ok "PowerShell 7 already installed ($($pwsh7.Source))."
}

# ---------------------------------------------------------------------------
# 2. Set up the repo in Documents\PowerShell without clobbering user files
#
#    - If it's already this repo (has .git): just git pull. Uncommitted local
#      changes get auto-stashed first (recoverable with 'git stash pop').
#    - Otherwise, if the folder exists but isn't this repo (e.g. your own
#      profile/scripts live there), the whole folder is renamed aside as a
#      backup (Documents\PowerShell_backup_<timestamp>) and a clean clone is
#      done in its place. Nothing is deleted — copy anything you need back
#      out of the backup folder afterward.
# ---------------------------------------------------------------------------
Write-Step "Setting up repository in $TargetFolder ..."
$git = Get-Command git -ErrorAction SilentlyContinue

if (Test-Path (Join-Path $TargetFolder '.git')) {
    Write-Warn2 "Existing power-scripts repo detected here — pulling latest changes."
    Push-Location $TargetFolder
    $dirty = git status --porcelain 2>$null
    if ($dirty) {
        Write-Warn2 "You have uncommitted local changes — stashing them first (restore later with 'git stash pop')."
        git stash push -u -m "auto-stash before install.ps1 update" | Out-Null
    }
    try { git pull } catch { Write-Warn2 "git pull failed: $($_.Exception.Message)" }
    Pop-Location
    Write-Ok "Repo updated in place."
}
else {
    if (Test-Path $TargetFolder) {
        Write-Warn2 "'$TargetFolder' exists but isn't this repo."
        $choice = Read-Host "    (B)ackup old folder, or (R)eplace directly? (B/R)"
        if ($choice -match '^[Rr]$') {
            Remove-Item -Path $TargetFolder -Recurse -Force
            Write-Ok "Old folder removed."
        } else {
            $backupName = "PowerShell_backup_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            $backupPath = Join-Path (Split-Path $TargetFolder -Parent) $backupName
            Rename-Item -Path $TargetFolder -NewName $backupName
            Write-Ok "Backed up to '$backupPath'. Nothing was deleted."
        }
    }

    if ($git) {
        git clone --quiet $RepoUrl $TargetFolder
        Write-Ok "Cloned via git."
    } else {
        Write-Warn2 "git not found — downloading zip instead."
        $zipPath = Join-Path $env:TEMP 'power-scripts.zip'
        $tmpDir  = Join-Path $env:TEMP "power-scripts-extract-$(Get-Random)"
        Invoke-WebRequest -Uri "$RepoUrl/archive/refs/heads/main.zip" -OutFile $zipPath
        Expand-Archive $zipPath $tmpDir -Force
        $inner = Get-ChildItem $tmpDir -Directory | Select-Object -First 1
        Move-Item $inner.FullName $TargetFolder
        Remove-Item $zipPath, $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "Downloaded and extracted."
    }
}

# ---------------------------------------------------------------------------
# 3. Add power-scripts folder to user PATH
# ---------------------------------------------------------------------------
Write-Step "Adding power-scripts folder to PATH..."
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($currentPath -notlike "*$ScriptsPath*") {
    [Environment]::SetEnvironmentVariable('PATH', "$currentPath;$ScriptsPath", 'User')
    Write-Ok "Added $ScriptsPath to PATH. Restart your terminal to pick it up."
} else {
    Write-Ok "Already on PATH."
}

# ---------------------------------------------------------------------------
# 4. Set execution policy so scripts can run
# ---------------------------------------------------------------------------
Write-Step "Setting execution policy..."
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined' -or $currentPolicy -eq 'AllSigned') {
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Write-Ok "Execution policy set to RemoteSigned for CurrentUser."
} else {
    Write-Ok "Execution policy already permissive ($currentPolicy)."
}

Write-Host "`n🎉 Setup complete! Restart your terminal, then open PowerShell 7 and start using the scripts.`n" -ForegroundColor Green
Write-Host "    (Want the right-click context menu? Run setup-context-menu.ps1 to pick which scripts to register.)`n" -ForegroundColor DarkGray