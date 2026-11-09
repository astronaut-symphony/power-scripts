<#
.SYNOPSIS
    Export one or many Excel files to PDF (all sheets -> one PDF per workbook).

.DESCRIPTION
    Pops up a file dialog to pick one or more Excel files, then a folder dialog
    to pick where the PDFs go. Each PDF is named after its workbook
    (Report.xlsx -> Report.pdf) and contains every visible sheet, first to last.
    Requires Microsoft Excel; if it is not installed the script stops before
    doing anything.

.PARAMETER Help
    Show usage and exit.

.EXAMPLE
    .\excel-to-pdf.ps1
#>

param(
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage:
    .\excel-to-pdf.ps1 [-Help]

Opens a file dialog to pick one or many Excel files, then a folder dialog to
pick where the PDFs are saved. Each workbook becomes one PDF (all visible
sheets, first to last) named after the Excel file, e.g. Report.xlsx -> Report.pdf.

Options:
    -Help    Show this help and exit.

Requires Microsoft Excel. Existing PDFs with the same name are overwritten.
"@
    return
}

# === Pre-flight: Excel must be installed ===
if (-not (Test-Path 'Registry::HKEY_CLASSES_ROOT\Excel.Application')) {
    Write-Host "Microsoft Excel is not installed (or not registered)." -ForegroundColor Red
    Write-Host "Please install Microsoft Excel first, then run this script again." -ForegroundColor Yellow
    Write-Host "Cancelled." -ForegroundColor Red
    return
}

Add-Type -AssemblyName System.Windows.Forms

# Hidden topmost owner so the dialogs don't open behind the console window
$owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }

$openDialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    Title            = 'Select Excel file(s) to export'
    Filter           = 'Excel files (*.xlsx;*.xlsm;*.xlsb;*.xls)|*.xlsx;*.xlsm;*.xlsb;*.xls'
    Multiselect      = $true
    InitialDirectory = (Get-Location).Path
}
if ($openDialog.ShowDialog($owner) -ne 'OK') {
    Write-Host "No file selected. Cancelled." -ForegroundColor Yellow
    return
}

$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    Description         = 'Select the folder to save the PDF(s) in'
    ShowNewFolderButton = $true
    SelectedPath        = (Get-Location).Path
}
if ($folderDialog.ShowDialog($owner) -ne 'OK') {
    Write-Host "No export folder selected. Cancelled." -ForegroundColor Yellow
    return
}
$outDir = $folderDialog.SelectedPath

$excel = $null
$ok = 0; $failed = 0
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    foreach ($file in $openDialog.FileNames) {
        $pdf = Join-Path $outDir ([IO.Path]::GetFileNameWithoutExtension($file) + '.pdf')
        $wb = $null
        try {
            # UpdateLinks=0, ReadOnly=true: don't touch the source file
            $wb = $excel.Workbooks.Open($file, 0, $true)
            # Type 0 = xlTypePDF; exporting the workbook includes all visible sheets
            $wb.ExportAsFixedFormat(0, $pdf)
            Write-Host "OK    $([IO.Path]::GetFileName($file)) -> $pdf" -ForegroundColor Green
            $ok++
        } catch {
            Write-Host "FAIL  $([IO.Path]::GetFileName($file)): $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        } finally {
            if ($wb) {
                $wb.Close($false)
                [void][Runtime.InteropServices.Marshal]::ReleaseComObject($wb)
            }
        }
    }
} finally {
    if ($excel) {
        $excel.Quit()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
    }
    $owner.Dispose()
}

Write-Host ""
Write-Host "Done. $ok exported, $failed failed. Output: $outDir" -ForegroundColor Cyan

# === Check for power-scripts update ===
. (Join-Path $PSScriptRoot 'PowerScripts.Update.ps1')
Update-PowerScriptsPrompt
