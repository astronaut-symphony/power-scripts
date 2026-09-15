param(
    [switch]$landscape,
    [string]$paperSize = "A4"
)

Add-Type -AssemblyName System.Drawing

# Set up the paper size options
$paperSizes = @{
    'A3' = [System.Drawing.Printing.PaperSize]::A3
    'A4' = [System.Drawing.Printing.PaperSize]::A4
    'A5' = [System.Drawing.Printing.PaperSize]::A5
}

# Define the output directory (PDF folder)
$outputDir = Join-Path (Get-Location) "PDF"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Get all image files in the current directory (including hidden files and handling spaces)
$imageFiles = Get-ChildItem -Path (Get-Location) -File | Where-Object { $_.Extension -match "\.(jpg|jpeg|png|bmp|gif)$" }

# Print the total number of images found
Write-Host "$($imageFiles.Count) images found."

# Validate that there are images to process
if ($imageFiles.Count -eq 0) {
    Write-Host "No image files found in the current directory!" -ForegroundColor Red
    exit
}

# Iterate through each image file and create a single-page PDF
foreach ($imageFile in $imageFiles) {
    $outputPDF = Join-Path $outputDir ($imageFile.BaseName + ".pdf")

    # Load the image
    $image = [System.Drawing.Image]::FromFile($imageFile.FullName)

    # Set up the PrintDocument
    $printDoc = New-Object System.Drawing.Printing.PrintDocument
    $printDoc.PrinterSettings.PrinterName = "Microsoft Print to PDF"
    $printDoc.PrinterSettings.PrintFileName = $outputPDF
    $printDoc.PrinterSettings.PrintToFile = $true

    # Handle paper size and orientation based on input parameter
    $paperSizeObj = $paperSizes[$paperSize]
    $printDoc.DefaultPageSettings.PaperSize = $paperSizeObj

    # Set orientation based on the -landscape parameter
    if ($landscape) {
        $printDoc.DefaultPageSettings.Landscape = $true
    } else {
        $printDoc.DefaultPageSettings.Landscape = $false
    }

    # Fit image to paper size if it's too large (maintaining aspect ratio)
    $maxWidth = $printDoc.DefaultPageSettings.PaperSize.Width
    $maxHeight = $printDoc.DefaultPageSettings.PaperSize.Height

    # Swap width and height if landscape
    if ($landscape) {
        $temp = $maxWidth
        $maxWidth = $maxHeight
        $maxHeight = $temp
    }

    # Scale the image to fit the paper size (maintaining aspect ratio)
    $scaleWidth = $maxWidth / $image.Width
    $scaleHeight = $maxHeight / $image.Height
    $scale = [math]::Min($scaleWidth, $scaleHeight)

    $scaledWidth = $image.Width * $scale
    $scaledHeight = $image.Height * $scale

    # Define the print action
    $printDoc.add_PrintPage({
        param($sender, $e)
        # Set margins if needed, for better fit
        $margins = New-Object System.Drawing.Printing.Margins(0, 0, 0, 0)
        $e.PageSettings.Margins = $margins

        # Draw the image with scaling, centered on the page
        $x = ($maxWidth - $scaledWidth) / 2
        $y = ($maxHeight - $scaledHeight) / 2
        $e.Graphics.DrawImage($image, $x, $y, $scaledWidth, $scaledHeight)
    })

    # Print the PDF
    # Write-Host "Converting '$($imageFile.Name)' to PDF ..."
    
    # Print and dispose
    $printDoc.Print()
    $image.Dispose()

    Write-Host "$($imageFile.Name) converted to PDF"
}

Write-Host "Conversion complete. PDFs saved to $outputDir."
