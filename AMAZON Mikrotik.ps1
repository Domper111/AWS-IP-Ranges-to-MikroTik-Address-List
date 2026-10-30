param(
    [string]$AddressList,
    [string]$Comment,
    [string]$OutputDir,
    [string]$FilterRegion,
    [string]$FilterService,
    [switch]$ShowSyncInfo,
    [int]$MaxLinesPerFile = 2000
)

# Interactive input: address-list name
if (-not $AddressList) {
    $inputList = Read-Host "Enter address-list name (Enter = Madbaza)"
    if ([string]::IsNullOrWhiteSpace($inputList)) {
        $AddressList = "Madbaza"
    } else {
        $AddressList = $inputList.Trim()
    }
}

# Interactive input: comment
if (-not $Comment) {
    $inputComment = Read-Host "Enter comment (Enter = AMAZON)"
    if ([string]::IsNullOrWhiteSpace($inputComment)) {
        $Comment = "AMAZON"
    } else {
        $Comment = $inputComment.Trim()
    }
}

# Interactive input: output path
if (-not $OutputDir) {
    $inputPath = Read-Host "Enter output path (Enter = D:\AWS)"
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        $OutputDir = "D:\AWS"
    } else {
        $OutputDir = $inputPath.Trim().TrimEnd('\')
    }
}

Write-Host ""
Write-Host "Address-list: $AddressList" -ForegroundColor Cyan
Write-Host "Comment:      $Comment" -ForegroundColor Cyan
Write-Host "Output path:  $OutputDir" -ForegroundColor Cyan
Write-Host ""

# Download JSON
Write-Host "Downloading ip-ranges.amazonaws.com/ip-ranges.json ..." -ForegroundColor Cyan
try {
    $json = Invoke-RestMethod -Uri "https://ip-ranges.amazonaws.com/ip-ranges.json" -ErrorAction Stop
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    exit 1
}

# Sync info
if ($ShowSyncInfo) {
    Write-Host "syncToken: $($json.syncToken)" -ForegroundColor Yellow
    Write-Host "createDate: $($json.createDate)" -ForegroundColor Yellow
    Write-Host "Total prefixes: $($json.prefixes.Count)" -ForegroundColor Yellow
    Write-Host ""
}

# Filtering
$prefixes = $json.prefixes
if ($FilterRegion) {
    $prefixes = $prefixes | Where-Object { $_.region -eq $FilterRegion }
    Write-Host "Region filter: $FilterRegion (found $($prefixes.Count))" -ForegroundColor Cyan
}
if ($FilterService) {
    $prefixes = $prefixes | Where-Object { $_.service -eq $FilterService }
    Write-Host "Service filter: $FilterService (found $($prefixes.Count))" -ForegroundColor Cyan
}

if ($prefixes.Count -eq 0) {
    Write-Host "No prefixes to process." -ForegroundColor Red
    exit 1
}

# Deduplication
$prefixes = $prefixes | Sort-Object ip_prefix -Unique

# Generate commands
Write-Host "Generating commands for address-list '$AddressList' ..." -ForegroundColor Cyan

$lines = New-Object System.Collections.Generic.List[string]
foreach ($entry in $prefixes) {
    $ip = $entry.ip_prefix
    if ($ip) {
        $lines.Add("/ip firewall address-list add list=$AddressList address=$ip comment=`"$Comment`"")
    }
}

Write-Host "Total lines: $($lines.Count)" -ForegroundColor Cyan
Write-Host ""

# Create output folder if missing
if (-not (Test-Path -LiteralPath $OutputDir)) {
    try {
        New-Item -ItemType Directory -Path $OutputDir -Force -ErrorAction Stop | Out-Null
        Write-Host "Created folder: $OutputDir" -ForegroundColor Yellow
    } catch {
        Write-Host "Failed to create folder ${OutputDir}: $_" -ForegroundColor Red
        exit 1
    }
}

# Split into files (no BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$datePart = (Get-Date).ToString("dd-MM-yyyy")
$fileIndex = 0

for ($i = 0; $i -lt $lines.Count; $i += $MaxLinesPerFile) {
    $fileIndex++
    $chunk = @($lines[$i..([math]::Min($i + $MaxLinesPerFile - 1, $lines.Count - 1))])
    $fileName = "AWS-{0}-{1}.txt" -f $datePart, $fileIndex
    $fullPath = Join-Path -Path $OutputDir -ChildPath $fileName

    try {
        [System.IO.File]::WriteAllLines($fullPath, $chunk, $utf8NoBom)
        Write-Host ("Saved: {0} ({1} lines)" -f $fullPath, $chunk.Count) -ForegroundColor Green
    } catch {
        Write-Host ("Failed to write {0}: {1}" -f $fullPath, $_) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host ("Done! Files: {0}, total lines: {1}" -f $fileIndex, $lines.Count) -ForegroundColor Green