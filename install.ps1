#Requires -Version 5.1
<#
.SYNOPSIS
    One-click installer for astronaut-symphony/power-scripts.

.DESCRIPTION
    Automates the manual setup steps from the README:
      1. Checks for PowerShell 7 (installs it if missing)
      2. Fetches the repo into Documents\PowerShell, merging file-by-file if
         that folder already has your own profile/scripts — anything that
         would be overwritten is backed up first, nothing is deleted
      3. Adds the power-scripts folder to the user PATH
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
$ScriptsPath  = Join-Path $TargetFolder 'power-scripts'   # only this subfolder goes on PATH; power-config does not

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
# 2. Set up the repo in Documents\PowerShell without clobbering user files
#
#    - If it's already this repo (has .git): just git pull. Uncommitted local
#      changes get auto-stashed first (recoverable with 'git stash pop').
#    - Otherwise the folder may already contain the user's own profile/scripts,
#      so we fetch the repo to a temp folder and merge it in file-by-file:
#      new files are added, files identical to the repo are left alone, and
#      files that differ get renamed in place (e.g. profile.ps1 becomes
#      profile_backup.ps1, right next to where it already was) before the
#      repo version is copied in. Files the user has that the repo doesn't
#      ship (e.g. their own custom scripts) are never touched.
# ---------------------------------------------------------------------------
Write-Step "Setting up repository in $TargetFolder ..."
$git = Get-Command git -ErrorAction SilentlyContinue

# Files that are repo metadata, not something a user hand-edits — always update
# these quietly instead of renaming them aside like a real conflict.
$NoBackupFiles = @('version.txt', 'install.ps1', 'install.bat', 'README.md', 'LICENSE', '.gitignore')

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
    Write-Warn2 "No existing power-scripts repo here — fetching a fresh copy and merging it in safely."
    $TempSrc = Join-Path $env:TEMP "power-scripts-src-$(Get-Random)"

    if ($git) {
        git clone --quiet $RepoUrl $TempSrc
    } else {
        $zipPath = Join-Path $env:TEMP 'power-scripts.zip'
        Invoke-WebRequest -Uri "$RepoUrl/archive/refs/heads/main.zip" -OutFile $zipPath
        Expand-Archive $zipPath $TempSrc -Force
        $inner   = Get-ChildItem $TempSrc -Directory | Select-Object -First 1
        $TempSrc = $inner.FullName
        Remove-Item $zipPath -Force
    }

    New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
    $sourceFiles = Get-ChildItem $TempSrc -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' }
    $added = 0; $updated = 0; $skipped = 0
    $backedUpFiles = @()

    foreach ($file in $sourceFiles) {
        $relPath  = $file.FullName.Substring($TempSrc.Length).TrimStart('\')
        $destPath = Join-Path $TargetFolder $relPath

        if (-not (Test-Path $destPath)) {
            New-Item -ItemType Directory -Path (Split-Path $destPath) -Force | Out-Null
            Copy-Item $file.FullName $destPath
            $added++
        }
        else {
            $same = (Get-FileHash $file.FullName).Hash -eq (Get-FileHash $destPath).Hash
            if ($same) {
                $skipped++
            }
            elseif ($NoBackupFiles -contains $file.Name) {
                Copy-Item $file.FullName $destPath -Force
                $updated++
            }
            else {
                $dir  = Split-Path $destPath
                $stem = [System.IO.Path]::GetFileNameWithoutExtension($destPath)
                $ext  = [System.IO.Path]::GetExtension($destPath)
                $backupPath = Join-Path $dir "${stem}_backup${ext}"
                if (Test-Path $backupPath) {
                    # a backup from an earlier run already exists — don't clobber that one either
                    $backupPath = Join-Path $dir "${stem}_backup_$(Get-Date -Format 'yyyyMMdd-HHmmss')${ext}"
                }
                Rename-Item $destPath (Split-Path $backupPath -Leaf)
                Copy-Item $file.FullName $destPath -Force
                $updated++
                $backedUpFiles += $backupPath
                Write-Warn2 "'$relPath' already existed and differed — kept as '$(Split-Path $backupPath -Leaf)', repo version installed."
            }
        }
    }

    # Bring .git along too (if we had it) so future runs can just 'git pull' instead of merging again
    if ($git -and (Test-Path (Join-Path $TempSrc '.git'))) {
        Copy-Item (Join-Path $TempSrc '.git') (Join-Path $TargetFolder '.git') -Recurse -Force
    }
    Remove-Item $TempSrc -Recurse -Force -ErrorAction SilentlyContinue

    Write-Ok "$added file(s) added, $updated updated, $skipped already up to date."
    if ($backedUpFiles.Count -gt 0) {
        Write-Warn2 "Your previous versions were kept alongside the new ones as:"
        $backedUpFiles | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }
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
Write-Host "    (Want the right-click context menu too? Run pwsh-context-menu.ps1 -Enable from an elevated PowerShell.)`n" -ForegroundColor DarkGray
