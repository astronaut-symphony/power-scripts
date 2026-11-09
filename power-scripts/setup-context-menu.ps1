<#
.SYNOPSIS
    Interactive setup for the "Power Script" right-click context menu.

.DESCRIPTION
    Lets you pick which power-scripts get registered into the Explorer
    right-click menu ("Power Script" submenu, shown when you right-click empty
    space inside a folder). Nothing is registered unless you select it.

    Pick a number to toggle that entry (register if missing, remove if
    registered), 'A' to register everything, 'R' to remove everything that is
    registered, and '0'/Enter to exit. Re-running is always safe.

    -Refresh (used by the installer after an update): no questions asked —
    re-registers every entry that is already registered so it points at the
    current pwsh and script paths, and drops entries that no longer exist.
#>

param([switch]$Refresh)

$root      = $PSScriptRoot
$register  = Join-Path $root 'Register-ContextMenuScript.ps1'

$entries = @(
    @{ Name = 'DupeCheck';   Label = 'Check Duplicates'; Script = 'duplicate-file-check.ps1'; Target = 'Background' }
    @{ Name = 'GetFileList'; Label = 'Get File List';    Script = 'get-file-list.ps1';        Target = 'Background' }
    @{ Name = 'SplitPDF';    Label = 'Split PDF';        Script = 'split-pdf.ps1';            Target = 'Background' }
    @{ Name = 'Excel2PDF';   Label = 'Excel to PDF';     Script = 'excel-to-pdf.ps1';         Target = 'Background' }
)

function Test-ContextMenuEntry([hashtable]$Entry) {
    if ($Entry.Target -eq 'File') {
        return (Test-Path "HKCU:\Software\Classes\$($Entry.FileExtension)\shell\PowerScripts\shell\$($Entry.Name)")
    }
    return (Test-Path "HKCU:\Software\Classes\Directory\Background\shell\PowerScripts\shell\$($Entry.Name)")
}

function Add-Entry([hashtable]$Entry) {
    $scriptPath = Join-Path $root $Entry.Script
    if ($Entry.Target -eq 'File') {
        & $register -Name $Entry.Name -Label $Entry.Label -ScriptPath $scriptPath -Target File -FileExtension $Entry.FileExtension
    } else {
        & $register -Name $Entry.Name -Label $Entry.Label -ScriptPath $scriptPath -Target $Entry.Target
    }
}

function Remove-Entry([hashtable]$Entry) {
    if ($Entry.Target -eq 'File') {
        $null = & $register -Name $Entry.Name -Remove -Target File -FileExtension $Entry.FileExtension
    } else {
        $null = & $register -Name $Entry.Name -Remove -Target $Entry.Target
    }
}

if (-not (Test-Path $register)) {
    Write-Host "Register-ContextMenuScript.ps1 not found next to this script." -ForegroundColor Red
    exit 1
}

if ($Refresh) {
    $registered = @($entries | Where-Object { Test-ContextMenuEntry $_ })
    # The folder-icon menu is no longer offered, and entries not in $entries are gone
    Remove-Item 'HKCU:\Software\Classes\Directory\shell\PowerScripts' -Recurse -Force -ErrorAction SilentlyContinue
    $names = $entries | ForEach-Object { $_.Name }
    Get-ChildItem 'HKCU:\Software\Classes\Directory\Background\shell\PowerScripts\shell' -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -notin $names } |
        ForEach-Object { Remove-Item $_.PSPath -Recurse -Force }
    foreach ($e in $registered) { Add-Entry $e }
    return
}

while ($true) {
    Write-Host ""
    Write-Host "Right-click menu setup - 'Power Script' submenu" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan

    for ($i = 0; $i -lt $entries.Count; $i++) {
        $e    = $entries[$i]
        $mark = if (Test-ContextMenuEntry $e) { "[x]" } else { "[ ]" }
        Write-Host ("{0}. {1} {2}" -f ($i + 1), $mark, $e.Label)
    }

    Write-Host ""
    Write-Host "A. Register all"
    Write-Host "R. Remove all registered"
    Write-Host "0. Exit"
    $selection = Read-Host "Pick a number to toggle (e.g. 1,3 or A) "
    $selection = $selection.Trim()

    if (-not $selection -or $selection -eq '0') {
        break
    }

    if ($selection -match '^[Aa]$') {
        foreach ($e in $entries) {
            if (-not (Test-ContextMenuEntry $e)) { Add-Entry $e }
        }
        continue
    }

    if ($selection -match '^[Rr]$') {
        foreach ($e in $entries) {
            if (Test-ContextMenuEntry $e) { Remove-Entry $e }
        }
        continue
    }

    foreach ($part in ($selection -split '[,;\s]+')) {
        if (-not $part) { continue }
        if ($part -match '^\d+$' -and [int]$part -ge 1 -and [int]$part -le $entries.Count) {
            $e = $entries[[int]$part - 1]
            if (Test-ContextMenuEntry $e) {
                Remove-Entry $e
            } else {
                Add-Entry $e
            }
        } else {
            Write-Host "Unknown option: $part" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Done. Right-click empty space in a folder -> 'Power Script' to run registered scripts." -ForegroundColor Green