param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FilePath
)

# === Validate input file ===
if (-not (Test-Path $FilePath)) {
    Write-Host "File not found: $FilePath" -ForegroundColor Red
    exit 1
}

# === Check for PSWritePDF ===
if (-not (Get-Module -ListAvailable -Name PSWritePDF)) {
    Write-Host "PSWritePDF module is not installed." -ForegroundColor Yellow

    $response = Read-Host "Do you want to install it now? (Y/N)"
    if ($response -match '^[Yy]$') {
        try {
            Write-Host "Installing PSWritePDF..." -ForegroundColor Cyan
            Install-Module PSWritePDF -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "PSWritePDF successfully installed." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to install PSWritePDF. Please check your internet connection or PowerShell Gallery access." -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "PSWritePDF is required. Exiting..." -ForegroundColor Red
        exit 1
    }
}

# === Import module ===
Import-Module PSWritePDF -ErrorAction Stop

# === Prepare output folder ===
$sourceDir = Split-Path $FilePath
$baseName  = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
$outputDir = Join-Path $sourceDir $baseName

if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
} else {
    Write-Host "Output folder '$baseName' already exists." -ForegroundColor Yellow
    $response = Read-Host "Overwrite existing files? (Y/N)"
    if ($response -notmatch '^[Yy]$') {
        Write-Host "Operation cancelled." -ForegroundColor Red
        exit 0
    }
}

# === Split PDF ===
Write-Host "Splitting '$baseName.pdf'..." -ForegroundColor Cyan
Split-PDF -FilePath $FilePath -OutputFolder $outputDir -Verbose:$false

# === Rename results with numeric order ===
Write-Host "Renaming output files..." -ForegroundColor Cyan
$i = 1
Get-ChildItem -Path $outputDir -Filter '*.pdf' |
    Sort-Object { 
        # extract number from filename and sort numerically
        if ($_ -match '(\d+)(?=\.pdf$)') { 
            [int]$matches[1] 
        } else { 
            0 
        } 
    } |
    ForEach-Object {
        $newName = "$i.pdf"
        Rename-Item -Path $_.FullName -NewName $newName -Force
        $i++
    }

Write-Host ""
Write-Host "Split completed successfully." -ForegroundColor Green
Write-Host "Output folder: $outputDir" -ForegroundColor Green
