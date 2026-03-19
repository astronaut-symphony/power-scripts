param (
    [string]$List = "list.txt",
    [string]$Output,
    [string]$Extension,   # NEW PARAM
    [switch]$Help
)

# === Help Section ===
if ($Help) {
    Write-Host @"

File Collector Script (v.1.1.0)
-------------------------------
A PowerShell tool to collect files from current and subdirectories into a single organized folder.

Usage:
  collect-files.ps1 [options]

Options:
  -List       (optional) List file to read filenames from (default: list.txt).
               Use extension for specific file
               Create 'list.txt' like:

                 Document.docx
                 Report
                 IMG_250714

  -Output     (optional) Destination folder (under 'collecting').
  -Extension  (optional) Only collect files with this extension
               Example: -Extension ".jpg"
  -Help       Show this help.

Example:
  collect-files.ps1 -List "myfiles.txt" -Output "backup_250714" -Extension ".jpg"

Notes:
- Collects files from the current directory and all subfolders (excluding the 'collecting' folder).
- Automatically renames duplicates with a numerical suffix (e.g., file-1.jpg).
- Logs collected files (final filenames) and missing files.
- Generates timestamped logs (e.g., 2507141424_collected_files.log).
"@
    exit 0
}

# === Check List File First ===
if (-not (Test-Path $List)) {
    Write-Host "List file '$List' not found." -ForegroundColor Red
    exit 1
}

$Files = Get-Content -Path $List | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

if (-not $Files.Count) {
    Write-Host "List file '$List' is empty." -ForegroundColor Red
    exit 1
}

Write-Host "Loaded $($Files.Count) file(s) from '$List'" -ForegroundColor Cyan

# === Prepare Output Folder ===
$collectingDir = "collecting"

if (-not (Test-Path $collectingDir)) {
    New-Item -ItemType Directory -Path $collectingDir | Out-Null
    Write-Host "Created base collecting directory: $collectingDir" -ForegroundColor Green
}

# Auto output name based on timestamp
if (-not $Output) {
    $Output = (Get-Date).ToString("yyMMddHHmm")
}

$destinationDir = Join-Path $collectingDir $Output

# === Check if Output Exists, Add Increment ===
$counter = 1
$finalDest = $destinationDir
while (Test-Path $finalDest) {
    $finalDest = "$destinationDir-$counter"
    $counter++
}

$destinationDir = $finalDest
New-Item -ItemType Directory -Path $destinationDir | Out-Null
Write-Host "Destination directory created: $destinationDir" -ForegroundColor Green

# === Main Collecting Process ===
$folderFileCount = @{}
$rootPath = [regex]::Escape((Get-Location).Path)
$missingLogFile = "$destinationDir/missing_files.log"
$collectedLogFile = "$destinationDir/collected_files.log"

if (Test-Path $missingLogFile) { Clear-Content $missingLogFile }
if (Test-Path $collectedLogFile) { Clear-Content $collectedLogFile }

$foundFiles = Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch "collecting\\" }

# === Apply Extension Filter if Provided ===
if ($Extension) {
    if ($Extension -notmatch "^\.") {
        $Extension = ".$Extension"  # Ensure starts with dot
    }
    $foundFiles = $foundFiles | Where-Object { $_.Extension -ieq $Extension }
    Write-Host "Filtering only *$Extension files..." -ForegroundColor Yellow
}

$missingFiles = @()
$collectedEntries = @()

foreach ($file in $Files) {
    $matched = $foundFiles | Where-Object {
        $_.Name -eq $file -or [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $file
    }

    if ($matched) {
        foreach ($m in $matched) {
            $relative = $m.DirectoryName -replace "^$rootPath\\?", ""

            if (-not $folderFileCount.ContainsKey($relative)) { $folderFileCount[$relative] = 0 }
            $folderFileCount[$relative]++

            # === Handle Duplicate Filenames ===
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($m.Name)
            $extension = [System.IO.Path]::GetExtension($m.Name)
            $destFileName = $m.Name
            $suffix = 1
            while (Test-Path (Join-Path $destinationDir $destFileName)) {
                $destFileName = "$baseName-$suffix$extension"
                $suffix++
            }

            $dest = Join-Path $destinationDir $destFileName
            Copy-Item $m.FullName -Destination $dest -Force
            Write-Host "$relative\$($m.Name) collected as $destFileName" -ForegroundColor Green
            $collectedEntries += "$destFileName, $relative"
        }
    } else {
        Write-Host "'$file' not found." -ForegroundColor Yellow
        $missingFiles += $file
    }
}

# === Missing Files Log ===
if ($missingFiles.Count -gt 0) {
    $missingFiles | Out-File $missingLogFile -Encoding utf8
    Write-Host "Missing files logged at: $missingLogFile" -ForegroundColor Red
}

# === Collected Files Log ===
if ($collectedEntries.Count -gt 0) {
    $collectedEntries | Out-File $collectedLogFile -Encoding utf8
    Write-Host "Collected files logged at: $collectedLogFile" -ForegroundColor Cyan
}

Write-Host ""

# === Summary ===
$folderFileCount.GetEnumerator() | ForEach-Object {
    Write-Host "$($_.Value) files collected from $($_.Key)" -ForegroundColor Cyan
}
