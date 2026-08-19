#Requires -Version 5.1
<#
.SYNOPSIS
    One-click installer for astronaut-symphony/power-scripts.

.DESCRIPTION
    Automates the manual setup steps from the README:
      1. Checks for PowerShell 7 (installs it if missing)
      2. Clones/updates the repo into Documents\PowerShell
      3. Adds the Scripts folder to the user PATH
      4. Sets the execution policy so the scripts can run

    (Right-click context menu integration is left out on purpose — run
    pwsh-context-menu.ps1 -Enable yourself if you want that.)

    Safe to re-run — every step checks current state before changing anything.

.USAGE
    Double-click install.bat (recommended, handles elevation automatically), or run:
        irm https://raw.githubusercontent.com/astronaut-symphony/power-scripts/main/install.ps1 | iex
#>

$ErrorActionPreference = 'Stop'
$RepoUrl      = 'https://github.com/astronaut-symphony/power-scripts'
$TargetFolder = Join-Path $HOME 'Documents\PowerShell'
$ScriptsPath  = Join-Path $TargetFolder 'Scripts'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    !  $msg" -ForegroundColor Yellow }

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
# 2. Clone or update the repo into Documents\PowerShell
# ---------------------------------------------------------------------------
Write-Step "Setting up repository in $TargetFolder ..."
$git = Get-Command git -ErrorAction SilentlyContinue

if (Test-Path (Join-Path $TargetFolder '.git')) {
    Write-Warn2 "Repo already exists here — pulling latest changes."
    Push-Location $TargetFolder
    try { git pull } catch { Write-Warn2 "git pull failed: $($_.Exception.Message)" }
    Pop-Location
}
elseif ($git) {
    git clone $RepoUrl $TargetFolder
    Write-Ok "Cloned via git."
}
else {
    Write-Warn2 "git not found — downloading zip instead."
    $zipPath = Join-Path $env:TEMP 'power-scripts.zip'
    $tmpDir  = Join-Path $env:TEMP 'power-scripts-extract'
    Invoke-WebRequest -Uri "$RepoUrl/archive/refs/heads/main.zip" -OutFile $zipPath
    Expand-Archive $zipPath $tmpDir -Force
    New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
    Copy-Item "$tmpDir\power-scripts-main\*" $TargetFolder -Recurse -Force
    Remove-Item $zipPath, $tmpDir -Recurse -Force
    Write-Ok "Downloaded and extracted."
}

# ---------------------------------------------------------------------------
# 3. Add Scripts folder to user PATH
# ---------------------------------------------------------------------------
Write-Step "Adding Scripts folder to PATH..."
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
Write-Host "    (Want the right-click context menu too? Run pwsh-context-menu.ps1 -Enable from an elevated PowerShell.)`n" -ForegroundColor DarkGray