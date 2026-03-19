param (
    [Parameter(Mandatory = $false)]
    [string]$Contains,    # Text that filename must contain

    [Parameter(Mandatory = $false)]
    [switch]$Export,      # If specified, writes log file

    [switch]$Help         # Show help
)

if ($Help) {
    Write-Host @"
    
Count Files in Current Directory (v.1.0.0)
------------------------------------------
Counts files recursively in the current directory (excluding this script file) 
whose names contain the specified string (case-insensitive).

Usage:
  count-files.ps1 [Options]

Options:
  -Contains   Only count files whose names contain this string.
  -Export     If specified, exports grouped file counts to 'count-files-<date>.log'.
  -Help       Show this help message.
"@
    return
}

# Get current timestamp for file naming
$timestamp = Get-Date -Format "yyMMddHHmm"
$logFile = "count-files-$timestamp.log"
$groupedCounts = @{}

# Get all files recursively
$files = Get-ChildItem -Recurse -File | Where-Object { $_.Name -notlike '*.ps1' }

# Filter files by -Contains if specified
if ($Contains) {
    $files = $files | Where-Object { $_.Name -like "*$Contains*" }
}

foreach ($file in $files) {
    $dir = $file.DirectoryName
    if (-not $groupedCounts.ContainsKey($dir)) {
        $groupedCounts[$dir] = 0
    }
    $groupedCounts[$dir]++
}

$totalCount = ($files).Count

if ($Export) {
    $summary = if ($Contains) { "Contains: '$Contains'" } else { "Contains: (none)" }
    Add-Content -Path $logFile -Value $summary

    $groupedCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $dirPath = $_.Key
        Add-Content -Path $logFile -Value "`n[$dirPath]"
        $filesInDir = $files | Where-Object { $_.DirectoryName -eq $dirPath }
        foreach ($f in $filesInDir) {
            Add-Content -Path $logFile -Value $f.Name
        }
    }

    Write-Host "Log exported to: $logFile"
}
else {
    $groupedCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $countText = "$($_.Value) file(s)"
        Write-Host "$($_.Key)  " -NoNewline
        Write-Host "$($_.Value) file(s)" -ForegroundColor Green
    }
}

Write-Host "`nFound " -NoNewline
Write-Host "$totalCount file(s)" -NoNewline -ForegroundColor Green
Write-Host " containing " -NoNewline
Write-Host "'$Contains'" -NoNewline -ForegroundColor Cyan