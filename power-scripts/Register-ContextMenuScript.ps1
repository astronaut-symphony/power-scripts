<#
.SYNOPSIS
    Add or remove a script inside a "Power Script" right-click submenu in Explorer.

.DESCRIPTION
    Registers the entry under the current user's registry hive
    (HKCU:\Software\Classes\Directory), so no Administrator rights are needed
    and it only affects your own account.

    Instead of one entry per script cluttering the top-level right-click menu,
    every script registered through this tool is grouped under a single
    cascading submenu (default label: "Power Script"). Right-click a folder ->
    "Power Script" -> pick the specific script from the list that flies out.

    Two menu locations are supported via -Target:
      - Folder      : right-click a folder's icon             (Directory\shell)
      - Background  : right-click empty space inside a folder (Directory\Background\shell)
      - Both        : add to both locations (default)
      - File        : right-click a file with -FileExtension (e.g. .pdf); the
                      script is called as `script -FilePath '%1'`

    The script runs with its working directory set to the folder you
    right-clicked, so scripts using relative paths (like Path "." in
    export-file-list.ps1) behave exactly as if you'd cd'd there yourself.
    When it finishes, the window shows "Press any key to exit..." and closes
    on a single keypress — no need to hit Enter.

.PARAMETER Name
    Internal registry key name for this entry, no spaces (e.g. "GetFileList").
    Used to add/remove this specific entry later.

.PARAMETER Label
    Text shown for this entry inside the submenu (e.g. "Export File List").
    Defaults to -Name if not given.

.PARAMETER ScriptPath
    Full path to the .ps1 script to run. Required unless -Remove is used.

.PARAMETER Arguments
    Extra arguments passed to the script, as one string (e.g. "-WithExtension -Extension ps1").

.PARAMETER Target
    Folder, Background, Both (default), or File (uses -FileExtension).

.PARAMETER FileExtension
    Which file extension to target when -Target File (e.g. ".pdf").

.PARAMETER Icon
    Optional path to an .ico file, or "some.exe,0" / "some.dll,-1" style icon reference,
    used for this specific entry inside the submenu.

.PARAMETER GroupName
    Internal registry key name for the submenu itself. Defaults to "PowerScripts".
    Only change this if you want a second, separate submenu group.

.PARAMETER GroupLabel
    Text shown for the submenu itself (e.g. "Power Script"). Defaults to "Power Script".

.PARAMETER GroupIcon
    Optional icon for the submenu heading itself.

.PARAMETER Remove
    Removes this entry (matched by -Name). If it was the last entry in the
    group, the now-empty submenu is removed too.

.PARAMETER Help
    Show this help and exit.

.EXAMPLE
    .\Register-ContextMenuScript.ps1 -Name GetFileList -Label "Export File List" `
        -ScriptPath "$HOME\Documents\PowerShell\power-scripts\export-file-list.ps1" -Arguments "-WithExtension"

.EXAMPLE
    .\Register-ContextMenuScript.ps1 -Name DupeCheck -Label "Check Duplicates" `
        -ScriptPath "$HOME\Documents\PowerShell\power-scripts\duplicate-check.ps1"

.EXAMPLE
    .\Register-ContextMenuScript.ps1 -Name GetFileList -Remove
#>

param(
    [string]$Name,
    [string]$Label,
    [string]$ScriptPath,
    [string]$Arguments = "",
    [ValidateSet('Folder', 'Background', 'Both', 'File')]
    [string]$Target = 'Both',
    [string]$FileExtension = '.pdf',
    [string]$Icon,
    [string]$GroupName = 'PowerScripts',
    [string]$GroupLabel = 'Power Script',
    [string]$GroupIcon,
    [switch]$Remove,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage:
    .\Register-ContextMenuScript.ps1 -Name <id> -Label <text> -ScriptPath <path> [-Arguments <args>] [-Target Folder|Background|Both|File] [-FileExtension <ext>] [-Icon <path>] [-GroupLabel <text>]
    .\Register-ContextMenuScript.ps1 -Name <id> -Remove

Every entry added is nested under a single "Power Script" (or -GroupLabel) submenu
instead of cluttering the top-level right-click menu.

Options:
    -Name            Internal registry key name for this entry, no spaces (required).
    -Label           Text shown for this entry in the submenu. Defaults to -Name.
    -ScriptPath      Full path to the .ps1 script to run (required unless -Remove).
    -Arguments       Extra arguments passed to the script, as one string.
    -Target          Folder, Background, Both (default), or File.
    -FileExtension   Extension used when -Target File (e.g. ".pdf"). Script is called with -FilePath '%1'.
    -Icon            Optional icon for this entry, e.g. "shell32.dll,-16".
    -GroupName       Internal registry key name for the submenu. Default: PowerScripts.
    -GroupLabel      Text shown for the submenu itself. Default: "Power Script".
    -GroupIcon       Optional icon for the submenu heading.
    -Remove          Remove this entry instead of adding it.
    -Help            Show this help and exit.

Examples:
    .\Register-ContextMenuScript.ps1 -Name GetFileList -Label "Export File List" -ScriptPath "$HOME\Documents\PowerShell\power-scripts\export-file-list.ps1" -Arguments "-WithExtension"
    .\Register-ContextMenuScript.ps1 -Name SplitPDF -Label "Split PDF to Folder" -ScriptPath "$HOME\Documents\PowerShell\power-scripts\split-pdf.ps1" -Target File -FileExtension ".pdf"
    .\Register-ContextMenuScript.ps1 -Name DupeCheck -Label "Check Duplicates" -ScriptPath "$HOME\Documents\PowerShell\power-scripts\duplicate-file-check.ps1"
    .\Register-ContextMenuScript.ps1 -Name GetFileList -Remove
"@
    return
}

if (-not $Name) {
    Write-Error "Missing -Name. Run with -Help for usage."
    return
}
if (-not $Remove) {
    if (-not $ScriptPath -or -not (Test-Path $ScriptPath)) {
        Write-Error "ScriptPath not found: '$ScriptPath'. Run with -Help for usage."
        return
    }
    if (-not $Label) { $Label = $Name }
}

function Get-PwshExe {
    $pwsh7 = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh7) { return $pwsh7.Source }
    return (Get-Command powershell).Source
}

# Ensures the cascading "Power Script" submenu key exists under $BasePath,
# using the registry's "subcommands" trick so Explorer treats it as a flyout
# menu populated by the child keys under its own \shell\ subkey.
function Set-ContextMenuGroup([string]$BasePath) {
    $groupPath = Join-Path $BasePath "shell\$GroupName"
    New-Item -Path $groupPath -Force | Out-Null
    Set-ItemProperty -Path $groupPath -Name 'MUIVerb' -Value $GroupLabel
    Set-ItemProperty -Path $groupPath -Name 'subcommands' -Value ''
    if ($GroupIcon) {
        Set-ItemProperty -Path $groupPath -Name 'Icon' -Value $GroupIcon
    }
    return $groupPath
}

function Set-ContextMenuEntry([string]$BasePath, [switch]$IsFile) {
    $groupPath = Set-ContextMenuGroup $BasePath
    $keyPath   = Join-Path $groupPath "shell\$Name"

    if ($Remove) {
        if (Test-Path $keyPath) {
            Remove-Item $keyPath -Recurse -Force
            Write-Host "Removed: $keyPath"
        }
        $groupShellPath = Join-Path $groupPath 'shell'
        $remaining = Get-ChildItem $groupShellPath -ErrorAction SilentlyContinue
        if (-not $remaining) {
            Remove-Item $groupPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed now-empty submenu: $groupPath"
        }
        return
    }

    New-Item -Path $keyPath -Force | Out-Null
    Set-ItemProperty -Path $keyPath -Name '(default)' -Value $Label
    if ($Icon) {
        Set-ItemProperty -Path $keyPath -Name 'Icon' -Value $Icon
    }

    $cmdKeyPath = Join-Path $keyPath 'command'
    New-Item -Path $cmdKeyPath -Force | Out-Null

    $pwshExe = Get-PwshExe
    if ($IsFile) {
        # %1 expands to the right-clicked file; the script receives it as -FilePath
        $inner = "Set-Location -LiteralPath (Split-Path -Parent '%1'); & '$ScriptPath' -FilePath '%1' $Arguments; Write-Host ''; Write-Host 'Press any key to exit...' -NoNewline; `$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')"
    } else {
        # %V expands to the target folder for both Directory\shell and Directory\Background\shell.
        # Everything after it runs with that folder as the working directory, then waits for a
        # single keypress (no Enter needed) before the console window closes.
        $inner = "Set-Location -LiteralPath '%V'; & '$ScriptPath' $Arguments; Write-Host ''; Write-Host 'Press any key to exit...' -NoNewline; `$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')"
    }
    $commandLine = "`"$pwshExe`" -NoProfile -ExecutionPolicy Bypass -Command `"$inner`""
    Set-ItemProperty -Path $cmdKeyPath -Name '(default)' -Value $commandLine

    Write-Host "Added: $keyPath -> `"$Label`" (under `"$GroupLabel`" submenu)"
}

$bases = @()
if ($Target -in 'Folder', 'Both')     { $bases += 'HKCU:\Software\Classes\Directory' }
if ($Target -in 'Background', 'Both') { $bases += 'HKCU:\Software\Classes\Directory\Background' }
if ($Target -eq 'File')               { $bases += "HKCU:\Software\Classes\$FileExtension" }

foreach ($base in $bases) {
    Set-ContextMenuEntry $base -IsFile:($Target -eq 'File')
}

# === Check for power-scripts update ===
. (Join-Path $PSScriptRoot 'PowerScripts.Update.ps1')
Update-PowerScriptsPrompt