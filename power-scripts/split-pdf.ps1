param(
    [Parameter(Position = 0)]
    [string]$FilePath
)

# === Interactive file picker if no FilePath provided ===
if (-not $FilePath) {
    Add-Type -AssemblyName System.Windows.Forms

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select PDF to Split"
    $dialog.Filter = "PDF files (*.pdf)|*.pdf|All files (*.*)|*.*"
    $dialog.InitialDirectory = (Get-Location).Path

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "No file selected. Exiting." -ForegroundColor Red
        exit 0
    }

    $FilePath = $dialog.FileName
}

# === Validate input file ===
if (-not (Test-Path $FilePath)) {
    Write-Host "File not found: $FilePath" -ForegroundColor Red
    exit 1
}

# Ensure it's a PDF
if ([System.IO.Path]::GetExtension($FilePath).ToLower() -ne '.pdf') {
    Write-Host "Selected file is not a PDF: $FilePath" -ForegroundColor Red
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
try {
    Import-Module PSWritePDF -ErrorAction Stop
}
catch {
    Write-Host "PSWritePDF is present but could not be loaded (incompatible version or corrupted installation)." -ForegroundColor Yellow

    $response = Read-Host "Reinstall it now? (Y/N)"
    if ($response -match '^[Yy]$') {
        try {
            Write-Host "Reinstalling PSWritePDF..." -ForegroundColor Cyan
            Uninstall-Module PSWritePDF -Force -ErrorAction SilentlyContinue
            Install-Module PSWritePDF -Scope CurrentUser -Force -ErrorAction Stop
            Import-Module PSWritePDF -ErrorAction Stop
            Write-Host "PSWritePDF successfully reinstalled." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to reinstall PSWritePDF. Please check your internet connection or PowerShell Gallery access." -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "PSWritePDF is required. Exiting..." -ForegroundColor Red
        exit 1
    }
}

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

$job = Start-Job -ScriptBlock {
    param($Path, $OutDir)
    Import-Module PSWritePDF -ErrorAction Stop
    Split-PDF -FilePath $Path -OutputFolder $OutDir -Verbose:$false
} -ArgumentList $FilePath, $outputDir

$spinner = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
$idx = 0
while ($job.State -eq 'Running') {
    Write-Host "`r  $($spinner[$idx % $spinner.Count]) Processing..." -NoNewline -ForegroundColor Cyan
    $idx++
    Start-Sleep -Milliseconds 100
}
Write-Host "`r                                    `r" -NoNewline

if ($job.State -eq 'Failed') {
    Write-Host "Split failed: $($job.ChildJobs[0].JobStateInfo.Reason.Message)" -ForegroundColor Red
    Remove-Job $job -Force
    exit 1
}

Receive-Job $job
Remove-Job $job

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

# === Check for power-scripts update ===
. (Join-Path $PSScriptRoot 'PowerScripts.Update.ps1')
Update-PowerScriptsPrompt
