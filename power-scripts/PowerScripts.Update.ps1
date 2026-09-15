<#
.SYNOPSIS
    Update-checking helpers for astronaut-symphony/power-scripts.

.DESCRIPTION
    Dot-source this from your PowerShell profile so Test-PowerScriptsUpdate is
    available in every session, e.g. add this near the bottom of
    Microsoft.PowerShell_profile.ps1:

        . (Join-Path $PSScriptRoot 'power-scripts\PowerScripts.Update.ps1')
        Test-PowerScriptsUpdate -Silent

    That gives you an automatic check on every new shell (throttled — see
    below — so it won't slow down startup or spam you), plus a command you
    can run yourself any time: Test-PowerScriptsUpdate -Force
#>

$script:PowerScriptsRoot    = Split-Path $PSScriptRoot -Parent          # Documents\PowerShell
$script:PowerScriptsRepo    = 'astronaut-symphony/power-scripts'
$script:VersionFile         = Join-Path $script:PowerScriptsRoot 'version.txt'
$script:UpdateCheckCache    = Join-Path $script:PowerScriptsRoot '.update-check-cache'
$script:UpdateSnoozeFile    = Join-Path $script:PowerScriptsRoot '.update-snooze-cache'
$script:UpdateCheckEveryHrs = 24

function Get-PowerScriptsLocalVersion {
    if (Test-Path $script:VersionFile) {
        return (Get-Content $script:VersionFile -Raw).Trim()
    }
    return $null
}

function Get-PowerScriptsRemoteVersion {
    try {
        $url = "https://raw.githubusercontent.com/$($script:PowerScriptsRepo)/main/version.txt"
        return (Invoke-RestMethod -Uri $url -TimeoutSec 5).ToString().Trim()
    } catch {
        return $null
    }
}

function Test-PowerScriptsUpdate {
    <#
    .SYNOPSIS
        Checks whether a newer version of power-scripts is available on GitHub.
    .PARAMETER Silent
        Only print something when an update IS available. Used for the automatic
        check at shell startup so an up-to-date system stays quiet.
    .PARAMETER Force
        Ignore the once-per-day throttle and check right now regardless of when
        it was last checked. Use this for a manual check.
    #>
    param(
        [switch]$Silent,
        [switch]$Force,
        [switch]$PassThru
    )

    if (-not $Force -and (Test-Path $script:UpdateSnoozeFile)) {
        try {
            $snoozedUntil = [datetime](Get-Content $script:UpdateSnoozeFile -Raw)
            if ((Get-Date) -lt $snoozedUntil) {
                return   # user snoozed the update prompt — stay quiet
            }
        } catch { }   # bad/corrupt snooze file — fall through and check now
    }

    if (-not $Force -and (Test-Path $script:UpdateCheckCache)) {
        try {
            $lastCheck = [datetime](Get-Content $script:UpdateCheckCache -Raw)
            if ((Get-Date) - $lastCheck -lt (New-TimeSpan -Hours $script:UpdateCheckEveryHrs)) {
                return   # checked recently enough — skip, keeps shell startup fast and offline-friendly
            }
        } catch { }   # bad/corrupt cache file — fall through and check now
    }

    $local  = Get-PowerScriptsLocalVersion
    $remote = Get-PowerScriptsRemoteVersion
    (Get-Date).ToString('o') | Set-Content $script:UpdateCheckCache

    if (-not $remote) {
        if (-not $Silent) { Write-Host "Couldn't check for power-scripts updates (offline or GitHub unreachable)." -ForegroundColor DarkGray }
        return
    }
    if (-not $local) {
        if (-not $Silent) { Write-Host "Local power-scripts version unknown (no version.txt found) — latest is $remote." -ForegroundColor Yellow }
        return
    }

    try {
        $isNewer = [version]$remote -gt [version]$local
    } catch {
        # version.txt isn't a clean x.y.z string — fall back to a plain inequality check
        $isNewer = $remote -ne $local
    }

    if ($isNewer) {
        Write-Host ""
        Write-Host "⚡ power-scripts update available: v$local -> v$remote" -ForegroundColor Yellow
        Write-Host "   Run this to update: irm https://raw.githubusercontent.com/$($script:PowerScriptsRepo)/main/install.ps1 | iex" -ForegroundColor DarkGray
        Write-Host ""
    }
    elseif (-not $Silent) {
        Write-Host "power-scripts is up to date (v$local)." -ForegroundColor Green
    }

    if ($PassThru) { return [bool]$isNewer }
}

# === One-click update (running this file directly, e.g. via "Run with PowerShell") ===

function Update-PowerScripts {
    <#
    .SYNOPSIS
        Downloads and applies the latest power-scripts install.ps1 from GitHub.
    #>
    try {
        Write-Host ""
        Write-Host "Downloading and installing power-scripts update..." -ForegroundColor Cyan
        $installScript = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/$($script:PowerScriptsRepo)/main/install.ps1" -TimeoutSec 30
        Invoke-Expression $installScript
    }
    catch {
        Write-Host "Update failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Try running this in a PowerShell window as Administrator." -ForegroundColor Yellow
    }
}

function Set-PowerScriptsSnooze {
    <#
    .SYNOPSIS
        Hides the update prompt for the given number of days.
    #>
    param([int]$Days = 7)

    if ($Days -lt 1) { $Days = 1 }
    $until = (Get-Date).AddDays($Days)
    $until.ToString('o') | Set-Content $script:UpdateSnoozeFile
    Write-Host "Update prompt dismissed for $Days day(s) (until $until)." -ForegroundColor DarkGray
}

function Update-PowerScriptsPrompt {
    <#
    .SYNOPSIS
        Checks (24h-throttled) for a newer power-scripts version. If one exists,
        prints the info and asks Y/N to install, or I to snooze for a few days.
        Ideal at the end of a script run.
    #>
    param([switch]$Force)

    # -Silent keeps the "up to date" line quiet; the update-available banner still prints.
    if (-not (Test-PowerScriptsUpdate -Silent -PassThru -Force:$Force)) {
        return
    }

    Write-Host ""
    $response = Read-Host "Install the update now? (Y/N, default N) or [I]gnore for 7 days "
    switch -Regex ($response) {
        '^[Yy]' {
            Update-PowerScripts
            break
        }
        '^[Ii]' {
            $days = Read-Host "Ignore for how many days? (default 7)"
            if ([int]::TryParse($days, [ref]$null)) {
                Set-PowerScriptsSnooze ([math]::Max(1, [int]$days))
            } else {
                Set-PowerScriptsSnooze
            }
            break
        }
        default {
            Write-Host "Update skipped." -ForegroundColor DarkGray
        }
    }
}

# === One-click update (running this file directly, e.g. via "Run with PowerShell") ===
if ($MyInvocation.InvocationName -ne '.') {
    Update-PowerScriptsPrompt -Force
}
