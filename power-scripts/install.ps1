#Requires -Version 5.1
<#
.SYNOPSIS
    Installer AND updater for astronaut-symphony/power-scripts (per-user, no admin needed).

.DESCRIPTION
    One command does everything - run it again any time to update:

      1. Downloads the latest GitHub release (no git needed)
      2. Checks for PowerShell 7 (installs it via winget --scope user if missing,
         falling back to the portable ZIP when winget isn't available)
      3. Installs/updates Documents\PowerShell\power-scripts - the previous
         version is kept as power-scripts_backup (one step of rollback)
      4. Offers to use the bundled PowerShell profile (never overwrites yours
         without asking)
      5. Adds the power-scripts folder to the user PATH
      6. Sets the execution policy to RemoteSigned for the current user
      7. Sets up (or refreshes) the right-click context menu

    Safe to re-run - every step checks current state before changing anything.
    If Documents\PowerShell is a git checkout (a developer's working copy) the
    installer stops without touching anything - use `git pull` there.

.USAGE
    irm https://raw.githubusercontent.com/astronaut-symphony/power-scripts/main/power-scripts/install.ps1 | iex
#>

$ErrorActionPreference = 'Stop'
$Repo         = 'astronaut-symphony/power-scripts'
# Real Documents folder (follows OneDrive redirection); pwsh 7 looks for its profile here
$TargetFolder = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell' }
$ScriptsPath  = Join-Path $TargetFolder 'power-scripts'   # only this subfolder goes on PATH

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    !  $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# Guard: never touch a developer's git working copy
# ---------------------------------------------------------------------------
if (Test-Path (Join-Path $TargetFolder '.git')) {
    Write-Host "`n'$TargetFolder' is a git checkout (development copy), so the installer will not touch it." -ForegroundColor Yellow
    Write-Host "  - To update it, run: git -C `"$TargetFolder`" pull" -ForegroundColor Yellow
    Write-Host "  - If this is NOT a development copy, delete its .git folder and run the installer again." -ForegroundColor Yellow
    return
}

# ---------------------------------------------------------------------------
# Confirm before proceeding (skipped when the update prompt already asked)
# ---------------------------------------------------------------------------
if (-not $PowerScriptsAssumeYes) {
    Write-Host "`nThis will install/update astronaut-symphony/power-scripts in $TargetFolder" -ForegroundColor Yellow
    Write-Host "  - Download the latest release" -ForegroundColor Yellow
    Write-Host "  - Install PowerShell 7 for your user (if missing)" -ForegroundColor Yellow
    Write-Host "  - Add power-scripts to your PATH" -ForegroundColor Yellow
    Write-Host "  - Set execution policy to RemoteSigned (current user)" -ForegroundColor Yellow
    $confirm = Read-Host "`nProceed? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Aborted." -ForegroundColor Red
        return
    }
}

# ---------------------------------------------------------------------------
# 1. Download the latest release first, so a network problem stops us before
#    anything on this machine has changed
# ---------------------------------------------------------------------------
Write-Step "Downloading the latest release..."
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$headers = @{ 'User-Agent' = 'power-scripts-installer' }
$zipPath = $null; $tmpDir = $null
try {
    $tag = (Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers -TimeoutSec 30).tag_name
    $zipPath = Join-Path $env:TEMP "power-scripts-$tag.zip"
    $tmpDir  = Join-Path $env:TEMP "power-scripts-extract-$(Get-Random)"
    Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/tags/$tag.zip" -OutFile $zipPath -Headers $headers -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force
    $srcRoot    = (Get-ChildItem $tmpDir -Directory | Select-Object -First 1).FullName
    $newScripts = Join-Path $srcRoot 'power-scripts'
    if (-not (Test-Path (Join-Path $newScripts 'install.ps1'))) { throw "Unexpected release layout." }
    Write-Ok "Downloaded release $tag."
} catch {
    Write-Host "    Download failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Check your internet connection and try again. Nothing was changed." -ForegroundColor Yellow
    if ($zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
    if ($tmpDir)  { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
    return
}

# ---------------------------------------------------------------------------
# 2. Ensure PowerShell 7 is installed (per user, no admin rights needed)
#
#    winget with --scope user is the primary method. If winget is missing or
#    fails, fall back to the portable ZIP unpacked into %LOCALAPPDATA%.
# ---------------------------------------------------------------------------

# Looks for pwsh on PATH first, then in the usual install locations (a fresh
# install isn't on this session's PATH yet).
function Find-Pwsh {
    $onPath = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'PowerShell\7\pwsh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\PowerShell\7\pwsh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerShell\7\pwsh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

# winget writes the new PATH to the registry; pick it up without a restart.
function Update-SessionPath {
    $parts = @(
        [Environment]::GetEnvironmentVariable('PATH', 'Machine'),
        [Environment]::GetEnvironmentVariable('PATH', 'User')
    ) | Where-Object { $_ }
    $env:PATH = ($parts -join ';')
}

function Install-PwshWithWinget {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Warn2 "winget not found - skipping."
        return $false
    }

    # Always per-user (the package is an MSIX): no admin rights or password prompt, even if this window is elevated.
    Write-Host "    Installing PowerShell 7 via winget (user scope, no admin needed)..."
    $wingetArgs = @(
        'install', '--id', 'Microsoft.PowerShell', '--exact', '--source', 'winget', '--scope', 'user',
        '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity'
    )

    & $winget.Source @wingetArgs
    $code = $LASTEXITCODE
    Update-SessionPath
    if (Find-Pwsh) { return $true }
    Write-Warn2 "winget didn't produce pwsh (exit code $code)."
    return $false
}

function Install-PwshWithZip {
    $dest = Join-Path $env:LOCALAPPDATA 'Programs\PowerShell\7'
    try {
        Write-Warn2 "Falling back to the portable ZIP (installs to $dest)..."
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -Headers $headers
        $asset   = $release.assets | Where-Object { $_.name -like '*-win-x64.zip' } | Select-Object -First 1
        $zip     = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $dest -Force
        Remove-Item $zip -Force
        $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        if (-not (($userPath -split ';') -contains $dest)) {
            [Environment]::SetEnvironmentVariable('PATH', (($userPath, $dest | Where-Object { $_ }) -join ';'), 'User')
        }
        Update-SessionPath
        return [bool](Find-Pwsh)
    } catch {
        Write-Warn2 "Portable install failed: $($_.Exception.Message)"
        return $false
    }
}

Write-Step "Checking for PowerShell 7..."
$pwshExe = Find-Pwsh
if ($pwshExe) {
    Write-Ok "PowerShell 7 already installed ($pwshExe)."
} else {
    if (Install-PwshWithWinget) {
        Write-Ok "PowerShell 7 installed via winget."
    } elseif (Install-PwshWithZip) {
        Write-Ok "PowerShell 7 installed (portable ZIP)."
    }

    $pwshExe = Find-Pwsh
    if ($pwshExe) {
        Write-Host "    Location: $pwshExe"
    } else {
        Write-Warn2 "Could not install PowerShell 7 automatically."
        Write-Warn2 "Install it with: winget install --id Microsoft.PowerShell -e --scope user"
        Write-Warn2 "or download it from https://github.com/PowerShell/PowerShell/releases/latest"
    }
}

# ---------------------------------------------------------------------------
# 3. Install/update the power-scripts folder
#
#    Files are copied over the existing folder (no folder rename, so it still
#    works while a terminal is sitting inside it). The previous version is kept
#    as power-scripts_backup. Files removed from the release are removed here
#    too, except dotfile caches and your local config\ folder.
# ---------------------------------------------------------------------------
Write-Step "Installing power-scripts $tag into $ScriptsPath ..."
if (Test-Path $ScriptsPath) {
    $backup = Join-Path $TargetFolder 'power-scripts_backup'
    if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
    Copy-Item $ScriptsPath $backup -Recurse
    Get-ChildItem $ScriptsPath -Recurse -File |
        Where-Object { $_.Name -notlike '.*' } |
        ForEach-Object {
            $rel = $_.FullName.Substring($ScriptsPath.Length).TrimStart('\')
            if ($rel -notlike 'config\*' -and -not (Test-Path (Join-Path $newScripts $rel))) {
                Remove-Item $_.FullName -Force
            }
        }
    Write-Ok "Previous version kept in '$backup'."
} else {
    New-Item -ItemType Directory -Path $ScriptsPath -Force | Out-Null
}
Copy-Item (Join-Path $newScripts '*') $ScriptsPath -Recurse -Force
# Keep the local version in step with the release tag, so the update check can't loop on a forgotten bump
Set-Content -Path (Join-Path $ScriptsPath 'version.txt') -Value $tag.TrimStart('v') -NoNewline
Write-Ok "Installed release $tag."

# ---------------------------------------------------------------------------
# 4. PowerShell profile - never overwritten without asking
#    (asked again only when the release ships a different profile than the
#    one you last answered about)
# ---------------------------------------------------------------------------
$srcProfile = Join-Path $srcRoot 'Microsoft.PowerShell_profile.ps1'
$dstProfile = Join-Path $TargetFolder 'Microsoft.PowerShell_profile.ps1'
if (Test-Path $srcProfile) {
    Write-Step "Checking PowerShell profile..."
    $srcHash  = (Get-FileHash $srcProfile).Hash
    $seenFile = Join-Path $ScriptsPath '.profile-seen'
    if (-not (Test-Path $dstProfile)) {
        Copy-Item $srcProfile $dstProfile
        Write-Ok "Profile installed."
    } elseif ((Get-FileHash $dstProfile).Hash -eq $srcHash) {
        Write-Ok "Profile already up to date."
    } elseif ((Test-Path $seenFile) -and ((Get-Content $seenFile -Raw).Trim() -eq $srcHash)) {
        Write-Ok "Keeping your own profile."
    } else {
        Write-Warn2 "You already have a PowerShell profile that differs from the one shipped with power-scripts."
        $use = Read-Host "    Use the power-scripts profile instead? Yours is saved as a .bak copy. (y/N)"
        if ($use -eq 'y' -or $use -eq 'Y') {
            Copy-Item $dstProfile "$dstProfile.bak" -Force
            Copy-Item $srcProfile $dstProfile -Force
            Write-Ok "Profile replaced (old one saved as Microsoft.PowerShell_profile.ps1.bak)."
        } else {
            Write-Ok "Keeping your own profile."
        }
        Set-Content -Path $seenFile -Value $srcHash -NoNewline
    }
}

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# 5. Add power-scripts folder to user PATH
# ---------------------------------------------------------------------------
Write-Step "Adding power-scripts folder to PATH..."
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if (-not (($currentPath -split ';') -contains $ScriptsPath)) {
    [Environment]::SetEnvironmentVariable('PATH', (($currentPath, $ScriptsPath | Where-Object { $_ }) -join ';'), 'User')
    Write-Ok "Added $ScriptsPath to PATH. Restart your terminal to pick it up."
} else {
    Write-Ok "Already on PATH."
}

# ---------------------------------------------------------------------------
# 6. Set execution policy so scripts can run
# ---------------------------------------------------------------------------
Write-Step "Setting execution policy..."
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined' -or $currentPolicy -eq 'AllSigned') {
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Write-Ok "Execution policy set to RemoteSigned for CurrentUser."
} else {
    Write-Ok "Execution policy already permissive ($currentPolicy)."
}

# ---------------------------------------------------------------------------
# 7. Right-click menu: refresh what's already registered, or offer to set it up
# ---------------------------------------------------------------------------
Write-Step "Right-click menu..."
$setupMenu = Join-Path $ScriptsPath 'setup-context-menu.ps1'
$hadMenu   = (Test-Path 'HKCU:\Software\Classes\Directory\Background\shell\PowerScripts') -or
             (Test-Path 'HKCU:\Software\Classes\Directory\shell\PowerScripts')
if ($hadMenu) {
    & $setupMenu -Refresh
} else {
    $answer = Read-Host "    Set up the right-click menu now? (y/N)"
    if ($answer -eq 'y' -or $answer -eq 'Y') {
        & $setupMenu
    } else {
        Write-Host "    Skipped. Run setup-context-menu.ps1 any time to set it up." -ForegroundColor DarkGray
    }
}

Write-Host "`nDone! Restart your terminal, then open PowerShell 7 and start using the scripts.`n" -ForegroundColor Green
