# Merge-PDF-FromList.ps1
#
# Struktur folder:
#   Folder\
#   ├── list.txt
#   ├── PGNT-TDOSSS3D000-ELE-GAR-PHR-2001-00.pdf
#   ├── PGNT-TDOSSS4D000-ELE-GAR-PHR-2001-00.pdf
#   ├── ...
#   └── Merge-PDF-FromList.ps1
#
# Output:
#   merged.pdf
#   merge-report.txt
#
# ==========================================
# PERBAIKAN DARI VERSI SEBELUMNYA
# ==========================================
# 1. Parsing list.txt sekarang mendukung DUA format:
#    a) Baris polos, satu nama file per baris (tanpa pipe), contoh:
#         PGNT-TDOSSS3D000-ELE-GAR-PHR-2001-00
#    b) Tabel markdown dengan pipe, mis. "| No | Nama File |" -> ambil
#       kolom paling kanan yang terlihat seperti nama file, header/nomor
#       urut otomatis diabaikan.
#    Versi sebelumnya HANYA mendukung format (b) dengan pipe, jadi kalau
#    list.txt berisi baris polos seperti punya Anda, semua baris malah
#    dilewati -> "Tidak ada nama PDF yang ditemukan".
# 2. Get-Content list.txt sekarang eksplisit -Encoding UTF8 supaya nama
#    file dengan karakter non-ASCII tidak rusak.
# 3. Exit code (qpdf/pdftk) sekarang dicek. Kalau merger gagal di tengah
#    proses, versi lama tetap lanjut dan cuma cek "apakah merged.pdf ada",
#    padahal bisa saja file kepenuhan dari proses sebelumnya (stale file)
#    atau setengah jadi.
# 4. merged.pdf lama sudah dihapus SEBELUM proses merge (sudah ada di versi
#    lama), tapi sekarang ukuran hasil akhir juga divalidasi (> 0 byte).
# ==========================================

$ErrorActionPreference = "Stop"

# ==========================================
# CONFIG
# ==========================================

$folder = (Get-Location).Path

$listFile = Join-Path $folder "list.txt"
$outputFile = Join-Path $folder "merged.pdf"
$reportFile = Join-Path $folder "merge-report.txt"

# ==========================================
# HEADER
# ==========================================

Clear-Host

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       PDF MERGE FROM LIST.TXT"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ==========================================
# CHECK LIST.TXT
# ==========================================

if (-not (Test-Path $listFile)) {
    Write-Host "ERROR: list.txt tidak ditemukan." -ForegroundColor Red
    Write-Host "Folder: $folder"
    exit 1
}

# ==========================================
# FIND PDF MERGER
# ==========================================

$merger = $null

# Coba qpdf
$qpdf = Get-Command qpdf -ErrorAction SilentlyContinue

if ($qpdf) {
    $merger = "qpdf"
}

# Kalau qpdf tidak ada, coba pdftk
if (-not $merger) {
    $pdftk = Get-Command pdftk -ErrorAction SilentlyContinue

    if ($pdftk) {
        $merger = "pdftk"
    }
}

if (-not $merger) {
    Write-Host "ERROR: Tidak ditemukan qpdf atau pdftk." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install salah satu:"
    Write-Host "  qpdf  -> https://qpdf.sourceforge.io/"
    Write-Host "  pdftk -> https://www.pdflabs.com/tools/pdftk-server/"
    Write-Host ""
    exit 1
}

Write-Host "PDF merger : $merger" -ForegroundColor Green
Write-Host ""

# ==========================================
# READ LIST.TXT
# ==========================================

$lines = Get-Content $listFile -Encoding UTF8

$pdfNames = @()

# Kata-kata umum di header tabel yang harus diabaikan walau
# kebetulan tidak mengandung spasi (jaga-jaga)
$headerKeywords = @("no", "nomor", "nama", "namafile", "file", "filename", "dokumen", "keterangan")

function Test-IsFileNameCandidate {
    param([string]$candidate)

    if ([string]::IsNullOrWhiteSpace($candidate)) { return $false }

    # Baris pemisah markdown, mis. "------"
    if ($candidate -match '^-+$') { return $false }

    # Kolom nomor urut murni, mis. "1", "12"
    if ($candidate -match '^\d+$') { return $false }

    # Header kolom, mis. "No", "Nama File"
    if ($script:headerKeywords -contains ($candidate.ToLower() -replace '\s', '')) { return $false }

    # Nama file yang valid tidak mengandung spasi (kode dokumen
    # seperti PGNT-TDOSSS3D000-ELE-GAR-PHR-2001-00)
    if ($candidate -match '^[A-Za-z0-9._-]+$' -and $candidate.Length -gt 3) { return $true }

    return $false
}

foreach ($rawLine in $lines) {

    $line = $rawLine.Trim()

    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    $name = $null

    if ($line -match '\|') {

        # Format tabel markdown: pecah berdasarkan pipe, buang sel kosong
        $cells = $line -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

        # Cari kandidat nama file: telusuri dari kolom PALING KANAN
        for ($i = $cells.Count - 1; $i -ge 0; $i--) {
            if (Test-IsFileNameCandidate $cells[$i]) {
                $name = $cells[$i]
                break
            }
        }
    }
    else {

        # Format baris polos: satu nama file per baris
        if (Test-IsFileNameCandidate $line) {
            $name = $line
        }
    }

    if (-not $name) {
        continue
    }

    # Tambahkan .pdf jika belum ada
    if (-not $name.ToLower().EndsWith(".pdf")) {
        $name = "$name.pdf"
    }

    $pdfNames += $name
}

# ==========================================
# CHECK LIST
# ==========================================

if ($pdfNames.Count -eq 0) {
    Write-Host "ERROR: Tidak ada nama PDF yang ditemukan di list.txt." -ForegroundColor Red
    exit 1
}

Write-Host "Jumlah file dalam list : $($pdfNames.Count)"
Write-Host ""

# ==========================================
# BUILD FILE LIST
# ==========================================

$existingFiles = @()
$missingFiles = @()

$index = 0

foreach ($pdfName in $pdfNames) {

    $index++

    $pdfPath = Join-Path $folder $pdfName

    if (Test-Path $pdfPath -PathType Leaf) {

        $existingFiles += (Resolve-Path $pdfPath).Path

        Write-Host ("[{0}/{1}] OK       {2}" -f $index, $pdfNames.Count, $pdfName) `
            -ForegroundColor Green
    }
    else {

        $missingFiles += $pdfName

        Write-Host ("[{0}/{1}] MISSING  {2}" -f $index, $pdfNames.Count, $pdfName) `
            -ForegroundColor Red
    }
}

Write-Host ""

# ==========================================
# STOP IF FILE MISSING
# ==========================================

if ($missingFiles.Count -gt 0) {

    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host "ADA FILE YANG TIDAK DITEMUKAN" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host ""

    foreach ($file in $missingFiles) {
        Write-Host "  $file" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "PDF tidak akan di-merge supaya urutan tetap aman." -ForegroundColor Yellow

    # Report
    @"
PDF MERGE REPORT
================

Folder:
$folder

Total dalam list : $($pdfNames.Count)
Ditemukan        : $($existingFiles.Count)
Tidak ditemukan  : $($missingFiles.Count)

MISSING FILES
-------------

$($missingFiles -join "`r`n")
"@ | Set-Content $reportFile -Encoding UTF8

    Write-Host ""
    Write-Host "Report disimpan:"
    Write-Host "$reportFile"
    Write-Host ""

    exit 1
}

# ==========================================
# REMOVE OLD OUTPUT
# ==========================================

if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force
}

# ==========================================
# MERGE PDF
# ==========================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MERGING PDF..."
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if ($merger -eq "qpdf") {

    # qpdf:
    # qpdf --empty --pages file1.pdf file2.pdf ... -- merged.pdf

    $arguments = @(
        "--empty",
        "--pages"
    )

    foreach ($file in $existingFiles) {
        $arguments += $file
    }

    $arguments += "--"
    $arguments += $outputFile

    & qpdf @arguments

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: qpdf gagal (exit code $LASTEXITCODE)." -ForegroundColor Red
        exit 1
    }
}

elseif ($merger -eq "pdftk") {

    # pdftk:
    # pdftk file1.pdf file2.pdf ... cat output merged.pdf

    $arguments = @()

    foreach ($file in $existingFiles) {
        $arguments += $file
    }

    $arguments += "cat"
    $arguments += "output"
    $arguments += $outputFile

    & pdftk @arguments

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: pdftk gagal (exit code $LASTEXITCODE)." -ForegroundColor Red
        exit 1
    }
}

# ==========================================
# CHECK RESULT
# ==========================================

if (-not (Test-Path $outputFile)) {
    Write-Host ""
    Write-Host "ERROR: Merge gagal, merged.pdf tidak dibuat." -ForegroundColor Red
    exit 1
}

$outputInfo = Get-Item $outputFile

if ($outputInfo.Length -eq 0) {
    Write-Host ""
    Write-Host "ERROR: merged.pdf dibuat tapi ukurannya 0 byte." -ForegroundColor Red
    exit 1
}

# ==========================================
# REPORT
# ==========================================

@"
PDF MERGE REPORT
================

Folder:
$folder

Output:
$outputFile

Total PDF:
$($existingFiles.Count)

Status:
SUCCESS

ORDER
-----

$(
    for ($i = 0; $i -lt $pdfNames.Count; $i++) {
        "{0}. {1}" -f ($i + 1), $pdfNames[$i]
    }
)
"@ | Set-Content $reportFile -Encoding UTF8

# ==========================================
# DONE
# ==========================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "           MERGE BERHASIL"
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Input PDF : $($existingFiles.Count)"
Write-Host "Output    : $outputFile"
Write-Host "Size      : $([math]::Round($outputInfo.Length / 1MB, 2)) MB"
Write-Host ""
Write-Host "Urutan mengikuti list.txt." -ForegroundColor Green
Write-Host ""