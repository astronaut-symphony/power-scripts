param (
    [string]$List = ".\list.txt",
    [string]$Extension = "",
    [string[]]$Include = @(),
    [string[]]$Exclude = @(),
    [switch]$Reverse,
    [switch]$SetDefaultExclude,
    [switch]$Help
)

if ($Help) {
    Write-Host @"

Rename Files Script (v.1.0.0)
-----------------------------
A flexible PowerShell script to batch rename files based on a mapping list, with folder inclusion/exclusion support.

Usage:
  rename-files.ps1 [options]

Options:
  -List                Input list file (default: list.txt).
                       Format: oldname,newname (one pair per line).
  -Extension           Filter by file extension (e.g., .pdf).
  -Include             Include only these top folders (comma-separated).
  -Exclude             Exclude specific top folders (comma-separated).
  -Reverse             Swap old and new names from the list.
  -SetDefaultExclude   Edit persistent default exclude folders.
  -Help                Show this help.

Examples: 
  rename-files.ps1
  rename-files.ps1 -List "myList.txt"
  rename-files.ps1 -Extension ".pdf"
  rename-files.ps1 -Include @("FolderA","FolderB")
  rename-files.ps1 -Exclude @("FolderX","FolderY")
  reanme-files.ps1 -Extension ".pdf" -Include @("FolderA","FolderB")
  reanme-files.ps1 -Reverse
  rename-files.ps1 -Include @("FolderA","FolderB") -Reverse
  reanme-files.ps1 -SetDefaultExclude

Notes:
- This script always excludes 'rename-files-logs' and folders set in:
  $HOME\Documents\PowerShell\config\rename-files-exclude.txt
- Logs in 'rename-files-logs\'.
"@
    exit 0
}

# Config directory and default exclude config file
$configDir = "$HOME\Documents\PowerShell\config"
$defaultExcludeFile = "$configDir\rename-files-exclude.txt"

# Setup config directory if needed
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir | Out-Null
}

# Handle SetDefaultExclude mode
if ($SetDefaultExclude) {
    Write-Host "Editing default exclude list. Current list:" -ForegroundColor Cyan
    if (Test-Path $defaultExcludeFile) {
        Get-Content $defaultExcludeFile | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "(none)" -ForegroundColor Yellow
    }
    Write-Host "Enter new exclude patterns (comma-separated):"
    $newInput = Read-Host "New Patterns (example: _print,collecting,temp)"
    $newPatterns = $newInput -split ",\s*"
    $newPatterns | Out-File -FilePath $defaultExcludeFile -Encoding UTF8
    Write-Host "Default exclude patterns saved to $defaultExcludeFile" -ForegroundColor Green
    exit 0
}

# Always exclude 'rename-files-logs' folder
$alwaysExclude = @("rename-files-logs")

# Load default exclude list if exists
$defaultExcludes = @()
if (Test-Path $defaultExcludeFile) {
    $defaultExcludes = Get-Content $defaultExcludeFile | Where-Object { $_.Trim() -ne "" }
    Write-Host "Loaded default exclude patterns: $($defaultExcludes -join ", ")" -ForegroundColor Cyan
}

# Combine always-exclude with default excludes
$totalExcludes = $alwaysExclude + $defaultExcludes

# Log files inside log folder
$logDir = ".\rename-files-logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Timestamp for log file names
$timestamp = (Get-Date).ToString("yyMMddHHmm")
$logFile = "$logDir\${timestamp}_rename_log.csv"
$notFoundFile = "$logDir\${timestamp}_missing_files.log"

# Initialize in-memory log storage
$renameLog = @()
$missingLog = @()

# Normalize extension
if ($Extension -and -not $Extension.StartsWith(".")) {
    $Extension = ".$Extension"
}

# Base path for relative references
$basePath = (Get-Location).Path

# Process mappings
Get-Content $List | ForEach-Object {
    $parts = $_ -split "\s*,\s*"

    if ($parts.Length -ne 2) {
        Write-Warning "Invalid line: $_"
        return
    }

    $oldName = $parts[0].Trim()
    $newName = $parts[1].Trim()

    # Swap if Reverse is enabled
    if ($Reverse) {
        $temp = $oldName
        $oldName = $newName
        $newName = $temp
    }

    # Gather matching files
    $files = Get-ChildItem -Path . -Recurse -File | Where-Object {
        $excludeRegex = '\\(' + ($totalExcludes -join "|") + ')\\'
        $_.FullName -notmatch $excludeRegex
    }

    if ($Extension) {
        $files = $files | Where-Object { $_.Extension -ieq $Extension }
    }

    $files = $files | Where-Object {
        $_.BaseName -eq $oldName
    }

    # Apply folder filters
    $filteredFiles = @()

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($basePath.Length + 1)
        $topFolder = $relativePath.Split([IO.Path]::DirectorySeparatorChar)[0]

        $includeCheck = ($Include.Count -eq 0 -or $Include -contains $topFolder)
        $excludeCheck = ($Exclude -contains $topFolder)

        if ($includeCheck -and -not $excludeCheck) {
            $filteredFiles += $file
        }
    }

    if ($filteredFiles.Count -eq 0) {
        $missingLog += $oldName
        Write-Host "Not found: $oldName"
        return
    }

    foreach ($file in $filteredFiles) {
        $newFileName = "$newName$($file.Extension)"
        $newPath = Join-Path -Path $file.DirectoryName -ChildPath $newFileName

        try {
            Rename-Item -Path $file.FullName -NewName $newPath -ErrorAction Stop

            $relativeOld = $file.FullName.Substring($basePath.Length + 1)
            $relativeNew = $newPath.Substring($basePath.Length + 1)

            Write-Host "Renamed '$relativeOld' → '$relativeNew'"
            $renameLog += "$relativeOld,$relativeNew,$([DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss"))"
        }
        catch {
            Write-Warning "Failed to rename '$($file.FullName)': $_"
        }
    }
}

# Write logs only if there are entries
if ($renameLog.Count -gt 0) {
    "OldFilePath,NewFilePath,Timestamp" | Out-File -FilePath $logFile -Encoding UTF8
    $renameLog | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Host "Rename log saved to: $logFile" -ForegroundColor Green
}

if ($missingLog.Count -gt 0) {
    $missingLog | Out-File -FilePath $notFoundFile -Encoding UTF8
    Write-Host "Missing file log saved to: $notFoundFile" -ForegroundColor Yellow
}
