param (
    [string]$List = "list.txt",
    [string]$Output,
    [string[]]$Extension,
    [switch]$Zip,
    [switch]$Help
)

# === Help Section ===
if ($Help) {
    Write-Host @"

File Collector Script (v.1.2.0)
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

    -Output     (optional) Output name.
                             Normal mode: destination folder name (under 'collecting').
                             Zip mode: zip file base name.
    -Extension  (optional) Only collect files with these extensions
                             Example: -Extension pdf,txt
                                                -Extension .jpg,.png
                                                -Extension "pdf,txt"
    -Zip        (optional) Create a .zip archive in the current directory.
                             When used, files are not copied to the collecting folder.
                   If -Output is not provided, you will be prompted for ZIP name.
  -Help       Show this help.

Example:
    collect-files.ps1 -List "myfiles.txt" -Output "backup_250714" -Extension pdf,txt -Zip

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

# === Prepare Destination (Folder Mode / ZIP Mode) ===
$collectingDir = "collecting"

$isZipOnlyMode = $Zip.IsPresent

# Auto output name based on mode
if ($isZipOnlyMode) {
    if (-not $Output) {
        $defaultZipName = (Get-Date).ToString("yyMMddHHmm")
        $zipNameInput = Read-Host "Enter ZIP file name (without .zip) [default: $defaultZipName]"
        if ([string]::IsNullOrWhiteSpace($zipNameInput)) {
            $Output = $defaultZipName
        } else {
            $Output = $zipNameInput.Trim()
        }

        if ($Output.ToLower().EndsWith(".zip")) {
            $Output = [System.IO.Path]::GetFileNameWithoutExtension($Output)
        }
    }
} elseif (-not $Output) {
    $Output = (Get-Date).ToString("yyMMddHHmm")
}

$cleanupStagingDir = $false

if ($isZipOnlyMode) {
    $destinationDir = Join-Path ([System.IO.Path]::GetTempPath()) ("collect-files-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $destinationDir | Out-Null
    $cleanupStagingDir = $true
    Write-Host "ZIP mode enabled. Using temporary staging: $destinationDir" -ForegroundColor Green
} else {
    if (-not (Test-Path $collectingDir)) {
        New-Item -ItemType Directory -Path $collectingDir | Out-Null
        Write-Host "Created base collecting directory: $collectingDir" -ForegroundColor Green
    }

    $baseDestinationDir = Join-Path $collectingDir $Output

    # === Check if Output Exists, Add Increment ===
    $counter = 1
    $destinationDir = $baseDestinationDir
    while (Test-Path $destinationDir) {
        $destinationDir = "$baseDestinationDir-$counter"
        $counter++
    }

    New-Item -ItemType Directory -Path $destinationDir | Out-Null
    Write-Host "Destination directory created: $destinationDir" -ForegroundColor Green
}

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
    $extensionFilters = $Extension |
        ForEach-Object { $_.Split(',') } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        ForEach-Object {
            if ($_ -notmatch "^\.") { ".$($_)" } else { $_ }
        }

    if ($extensionFilters.Count -eq 0) {
        Write-Host "No valid extension values found in -Extension." -ForegroundColor Red
        exit 1
    }

    $extensionSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($ext in $extensionFilters) {
        [void]$extensionSet.Add($ext)
    }

    $foundFiles = $foundFiles | Where-Object { $extensionSet.Contains($_.Extension) }
    $filterText = ($extensionSet | Sort-Object) -join ", "
    Write-Host "Filtering only extensions: $filterText" -ForegroundColor Yellow
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
if ($collectedEntries.Count -gt 0 -and -not $isZipOnlyMode) {
    $collectedEntries | Out-File $collectedLogFile -Encoding utf8
    Write-Host "Collected files logged at: $collectedLogFile" -ForegroundColor Cyan
} elseif ($collectedEntries.Count -gt 0 -and $isZipOnlyMode) {
    Write-Host "Collected files log skipped in ZIP mode." -ForegroundColor DarkYellow
}

Write-Host ""

# === Summary ===
$folderFileCount.GetEnumerator() | ForEach-Object {
    Write-Host "$($_.Value) files collected from $($_.Key)" -ForegroundColor Cyan
}

# === Optional ZIP Export ===
if ($Zip) {
    $zipBaseName = $Output
    $zipPath = Join-Path (Get-Location).Path "$zipBaseName.zip"

    $zipCounter = 1
    while (Test-Path $zipPath) {
        $zipPath = Join-Path (Get-Location).Path "$zipBaseName-$zipCounter.zip"
        $zipCounter++
    }

    try {
        $zipSource = Join-Path $destinationDir "*"
        Compress-Archive -Path $zipSource -DestinationPath $zipPath -Force
        Write-Host "ZIP archive created: $zipPath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to create ZIP archive: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        if ($cleanupStagingDir -and (Test-Path $destinationDir)) {
            Remove-Item -Path $destinationDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
