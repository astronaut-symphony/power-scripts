# Get all files in the current and subdirectories
$files = Get-ChildItem -Path . -Recurse -File

# Create a hashtable to track file names (without extensions)
$fileNames = @{}

# Loop through each file and check for duplicates
$files | ForEach-Object {
    # Get the file name without the extension
    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)

    # If the file name already exists in the hashtable, it's a duplicate
    If ($fileNames.ContainsKey($fileNameWithoutExtension)) {
        # Add the current file to the list of duplicates for this name
        $fileNames[$fileNameWithoutExtension] += $_.FullName
    }
    Else {
        # Otherwise, add the file name to the hashtable
        $fileNames[$fileNameWithoutExtension] = @($_.FullName)
    }
}

# Flag to track if any duplicates are found
$foundDuplicates = $false

# Output any duplicates found
$fileNames.GetEnumerator() | ForEach-Object {
    If ($_.Value.Count -gt 1) {
        Write-Host "Duplicate files found for '$($_.Key)':"
        $_.Value | ForEach-Object { Write-Host "  $_" }
        $foundDuplicates = $true
    }
}

# If no duplicates were found, print a summary message
If (-not $foundDuplicates) {
    Write-Host "No duplicate files found."
}
