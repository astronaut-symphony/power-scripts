<#
.SYNOPSIS
    PowerDiff - Deteksi perubahan file dalam sebuah folder (Added/Deleted/Modified/Moved)
    berdasarkan snapshot sebelumnya (JSON), lalu export report .txt jika ada perubahan.

.DESCRIPTION
    Algoritma:
      1. Scan folder
      2. Load snapshot lama (JSON)
      3. Cari Added / Deleted / Modified
      4. Cari pasangan Added+Deleted dengan hash sama -> Moved
      5. Export report (PowerDiff.txt) jika ada perubahan
      6. Simpan snapshot baru (JSON)

.PARAMETER Path
    Folder yang akan di-scan. Default: folder tempat script dijalankan.

.PARAMETER SnapshotPath
    Lokasi file snapshot JSON. Default: PowerDiff.snapshot.json di folder Path.

.PARAMETER ReportPath
    Lokasi file report .txt. Default: PowerDiff.txt di folder Path.

.EXAMPLE
    .\PowerDiff.ps1 -Path "D:\Project"
#>

[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [string]$SnapshotPath,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path)) {
    throw "Folder tidak ditemukan: $Path"
}
$Path = (Resolve-Path -LiteralPath $Path).Path

if (-not $SnapshotPath) { $SnapshotPath = Join-Path $Path 'PowerDiff.snapshot.json' }
if (-not $ReportPath)   { $ReportPath   = Join-Path $Path 'PowerDiff.txt' }

# Nama file snapshot & report sendiri dikecualikan dari scan supaya tidak ikut terdeteksi.
$excludeNames = @(
    (Split-Path -Leaf $SnapshotPath),
    (Split-Path -Leaf $ReportPath)
)

# ---------------------------------------------------------------------------
# 1. Scan folder -> hasilkan hashtable [relative path] = hash
# ---------------------------------------------------------------------------
function Get-FolderSnapshot {
    param([string]$RootPath, [string[]]$ExcludeNames)

    $result = @{}

    $files = Get-ChildItem -LiteralPath $RootPath -Recurse -File -Force |
        Where-Object { $ExcludeNames -notcontains $_.Name }

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($RootPath.Length).TrimStart('\', '/')
        $relativePath = $relativePath -replace '\\', '/'

        try {
            $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        } catch {
            Write-Warning "Gagal hash file: $relativePath ($_)"
            continue
        }

        $result[$relativePath] = $hash
    }

    return $result
}

# ---------------------------------------------------------------------------
# 2. Load snapshot lama
# ---------------------------------------------------------------------------
function Load-Snapshot {
    param([string]$SnapshotFile)

    if (-not (Test-Path -LiteralPath $SnapshotFile)) {
        return @{}
    }

    $json = Get-Content -LiteralPath $SnapshotFile -Raw | ConvertFrom-Json

    $old = @{}
    foreach ($prop in $json.PSObject.Properties) {
        $old[$prop.Name] = $prop.Value
    }
    return $old
}

# ---------------------------------------------------------------------------
# 3-4. Bandingkan snapshot lama vs baru -> Added / Deleted / Modified / Moved
# ---------------------------------------------------------------------------
function Compare-Snapshots {
    param([hashtable]$Old, [hashtable]$New)

    $added    = [System.Collections.Generic.List[string]]::new()
    $deleted  = [System.Collections.Generic.List[string]]::new()
    $modified = [System.Collections.Generic.List[string]]::new()
    $moved    = [System.Collections.Generic.List[object]]::new()

    foreach ($path in $New.Keys) {
        if (-not $Old.ContainsKey($path)) {
            $added.Add($path)
        }
        elseif ($Old[$path] -ne $New[$path]) {
            $modified.Add($path)
        }
    }

    foreach ($path in $Old.Keys) {
        if (-not $New.ContainsKey($path)) {
            $deleted.Add($path)
        }
    }

    # Cari pasangan Added + Deleted dengan hash sama -> Moved
    $addedRemove   = [System.Collections.Generic.List[string]]::new()
    $deletedRemove = [System.Collections.Generic.List[string]]::new()

    foreach ($newPath in $added) {
        $newHash = $New[$newPath]
        $match = $deleted | Where-Object { $Old[$_] -eq $newHash -and -not $deletedRemove.Contains($_) } | Select-Object -First 1

        if ($match) {
            $moved.Add([pscustomobject]@{ From = $match; To = $newPath })
            $addedRemove.Add($newPath)
            $deletedRemove.Add($match)
        }
    }

    foreach ($p in $addedRemove)   { [void]$added.Remove($p) }
    foreach ($p in $deletedRemove) { [void]$deleted.Remove($p) }

    return [pscustomobject]@{
        Added    = $added    | Sort-Object
        Deleted  = $deleted  | Sort-Object
        Modified = $modified | Sort-Object
        Moved    = $moved    | Sort-Object From
    }
}

# ---------------------------------------------------------------------------
# 5. Format report .txt
# ---------------------------------------------------------------------------
function Build-Report {
    param($Diff, [string]$ReportFileName)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add($ReportFileName)
    $lines.Add('=' * 40)
    $lines.Add('Power Get Diff')
    $lines.Add("Generated : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add('=' * 40)

    if ($Diff.Added.Count -gt 0) {
        $lines.Add("Added ($($Diff.Added.Count))")
        foreach ($p in $Diff.Added) { $lines.Add($p) }
        $lines.Add('-' * 40)
    }

    if ($Diff.Modified.Count -gt 0) {
        $lines.Add("Modified ($($Diff.Modified.Count))")
        foreach ($p in $Diff.Modified) { $lines.Add($p) }
        $lines.Add('-' * 40)
    }

    if ($Diff.Moved.Count -gt 0) {
        $lines.Add("Moved ($($Diff.Moved.Count))")
        foreach ($m in $Diff.Moved) {
            $lines.Add($m.From)
            $lines.Add(" -> $($m.To)")
        }
        $lines.Add('-' * 40)
    }

    if ($Diff.Deleted.Count -gt 0) {
        $lines.Add("Deleted ($($Diff.Deleted.Count))")
        foreach ($p in $Diff.Deleted) { $lines.Add($p) }
    }

    # Buang separator terakhir kalau kebetulan Deleted kosong tapi ada trailing '-'
    while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq ('-' * 40)) {
        $lines.RemoveAt($lines.Count - 1)
    }

    return ($lines -join [Environment]::NewLine)
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
Write-Host "Scanning..."

$newSnapshot = Get-FolderSnapshot -RootPath $Path -ExcludeNames $excludeNames
$oldSnapshot = Load-Snapshot -SnapshotFile $SnapshotPath

$diff = Compare-Snapshots -Old $oldSnapshot -New $newSnapshot

$hasChanges = ($diff.Added.Count + $diff.Deleted.Count + $diff.Modified.Count + $diff.Moved.Count) -gt 0

Write-Host ("Added      : {0}" -f $diff.Added.Count)
Write-Host ("Modified   : {0}" -f $diff.Modified.Count)
Write-Host ("Moved      : {0}" -f $diff.Moved.Count)
Write-Host ("Deleted    : {0}" -f $diff.Deleted.Count)

if ($hasChanges) {
    Write-Host "Changes detected."

    $reportFileName = Split-Path -Leaf $ReportPath
    $reportText = Build-Report -Diff $diff -ReportFileName $reportFileName
    Set-Content -LiteralPath $ReportPath -Value $reportText -Encoding UTF8

    Write-Host "Report exported to $reportFileName"
} else {
    Write-Host "No changes detected."
}

# ---------------------------------------------------------------------------
# 6. Simpan snapshot baru sebagai JSON
# ---------------------------------------------------------------------------
$newSnapshot | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $SnapshotPath -Encoding UTF8

Write-Host "Snapshot updated."