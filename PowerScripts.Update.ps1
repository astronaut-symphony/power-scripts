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
        [switch]$Force
    )

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
}
