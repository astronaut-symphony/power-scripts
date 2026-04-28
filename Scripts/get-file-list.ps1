param (
    [switch]$IncludeHidden,   # Include hidden/system files and folders
        [switch]$WithExtension,   # Keep file extensions in output
        [string[]]$Extension,     # Filter by one or more file extensions (e.g. ps1 or .ps1)
        [switch]$Help             # Show usage information
)

if ($Help) {
        Write-Host @"
Usage:
    .\get-file-list.ps1 [-IncludeHidden] [-WithExtension] [-Extension <ext1,ext2,...>] [-Help]

Options:
    -IncludeHidden   Include hidden/system files and folders.
    -WithExtension   Keep file extensions in output names.
    -Extension       Only include files matching one or more extensions.
                                     Accepts values with or without dot (example: ps1, .txt).
    -Help            Show this help and exit.

Examples:
    .\get-file-list.ps1
    .\get-file-list.ps1 -WithExtension
    .\get-file-list.ps1 -Extension ps1
    .\get-file-list.ps1 -Extension ps1,txt -IncludeHidden
"@
        return
}

# Define output file path
$outputFile = "FileList.txt"

# Clear the file if it exists
if (Test-Path $outputFile) {
    Clear-Content $outputFile
}

# Build Get-ChildItem parameters
$gciParams = @{
    Path    = "."
    Recurse = $true
    File    = $true
}
if ($IncludeHidden) {
    $gciParams.Force = $true
}

# Get all files recursively
$files = Get-ChildItem @gciParams |
    Where-Object {
        # Exclude dot-folders like .git, .vscode, .idea, etc.
        -not ($_.DirectoryName -match '\\\.[^\\]*')
    } |
    Where-Object {
        if (-not $Extension -or $Extension.Count -eq 0) {
            $true
        } else {
            $normalizedExtensions = $Extension | ForEach-Object {
                if ([string]::IsNullOrWhiteSpace($_)) {
                    $null
                } elseif ($_.StartsWith('.')) {
                    $_.ToLowerInvariant()
                } else {
                    ".{0}" -f $_.ToLowerInvariant()
                }
            } | Where-Object { $_ }

            $normalizedExtensions -contains $_.Extension.ToLowerInvariant()
        }
    } |
    Select-Object DirectoryName, @{
        Name       = "FileName"
        Expression = {
            if ($WithExtension) {
                $_.Name
            } else {
                [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            }
        }
    }

$total = $files.Count

if ($total -eq 0) {
    "No files matched the selected options." | Out-File -Encoding UTF8 $outputFile
    Write-Host "No matching files found. Created $outputFile with a note."
    return
}

$lastDir = ""
$counter = 0

# Write-Host "Exporting $total files to $outputFile..."
# Write-Host ""

# Loop through each file and write to output file
$files | ForEach-Object {
    $counter++

    # Progress bar
    $percent = [math]::Round(($counter / $total) * 100, 2)
    Write-Progress -Activity "Exporting files..." -Status "$counter of $total ($percent%)" -PercentComplete $percent

    # Write directory header if changed
    if ($_.DirectoryName -ne $lastDir) {
        "`n[$($_.DirectoryName)]" | Out-File -Append -Encoding UTF8 $outputFile
        $lastDir = $_.DirectoryName
    }

    # Write file name
    $_.FileName | Out-File -Append -Encoding UTF8 $outputFile
}

# Clear progress bar
Write-Progress -Activity "Exporting files..." -Completed

Write-Host "File list exported to $outputFile successfully!"
