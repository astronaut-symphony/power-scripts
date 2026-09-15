<#
.SYNOPSIS
    Interactive setup for the "Power Script" right-click context menu.

.DESCRIPTION
    Lets you pick which power-scripts get registered into the Explorer
    right-click menu ("Power Script" submenu). Nothing is registered unless
    you select it — install.ps1 does NOT touch the context menu anymore.

    Pick a number to toggle that entry (register if missing, remove if
    registered), 'A' to register everything, 'R' to remove everything that is
    registered, and '0'/Enter to exit. Re-running is always safe.
#>

$root      = $PSScriptRoot
$register  = Join-Path $root 'Register-ContextMenuScript.ps1'

$entries = @(
    @{ Name = 'DupeCheck';   Label = 'Check Duplicates';       Script = 'duplicate-file-check.ps1';     Target = 'Both' }
    @{ Name = 'GenReplace';  Label = 'Generate Replace LISP';  Script = 'generate-replace-autocad.ps1'; Target = 'Both' }
    @{ Name = 'GetFileList'; Label = 'Export File List';       Script = 'export-file-list.ps1';         Target = 'Both' }
    @{ Name = 'SplitPDF';    Label = 'Split PDF';              Script = 'split-pdf.ps1';                Target = 'Both' }
)

function Test-ContextMenuEntry([hashtable]$Entry) {
    if ($Entry.Target -eq 'File') {
        return (Test-Path "HKCU:\Software\Classes\$($Entry.FileExtension)\shell\PowerScripts\shell\$($Entry.Name)")
    }
    return ((Test-Path "HKCU:\Software\Classes\Directory\shell\PowerScripts\shell\$($Entry.Name)") -or
            (Test-Path "HKCU:\Software\Classes\Directory\Background\shell\PowerScripts\shell\$($Entry.Name)"))
}

function Add-Entry([hashtable]$Entry) {
    $scriptPath = Join-Path $root $Entry.Script
    if ($Entry.Target -eq 'File') {
        & $register -Name $Entry.Name -Label $Entry.Label -ScriptPath $scriptPath -Target File -FileExtension $Entry.FileExtension
    } else {
        & $register -Name $Entry.Name -Label $Entry.Label -ScriptPath $scriptPath -Target Both
    }
}

function Remove-Entry([hashtable]$Entry) {
    if ($Entry.Target -eq 'File') {
        $null = & $register -Name $Entry.Name -Remove -Target File -FileExtension $Entry.FileExtension
    } else {
        $null = & $register -Name $Entry.Name -Remove -Target Both
    }
}

if (-not (Test-Path $register)) {
    Write-Host "Register-ContextMenuScript.ps1 not found next to this script." -ForegroundColor Red
    exit 1
}

while ($true) {
    Write-Host ""
    Write-Host "Right-click menu setup - 'Power Script' submenu" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan

    for ($i = 0; $i -lt $entries.Count; $i++) {
        $e    = $entries[$i]
        $mark = if (Test-ContextMenuEntry $e) { "[x]" } else { "[ ]" }
        if ($e.Target -eq 'File') {
            $where = "right-click .$($e.FileExtension.TrimStart('.')) file"
        } else {
            $where = "right-click folder"
        }
        Write-Host ("{0}. {1} {2}  ({3})" -f ($i + 1), $mark, $e.Label, $where)
    }

    Write-Host ""
    Write-Host "A. Register all"
    Write-Host "R. Remove all registered"
    Write-Host "0. Exit"
    $selection = Read-Host "Pilih nomor untuk toggle (mis. 1,3 atau A) "
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
            Write-Host "Pilihan tidak dikenali: $part" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Selesai. Right-click a folder -> 'Power Script' untuk menjalankan script yang terdaftar." -ForegroundColor Green