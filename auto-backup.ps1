<#
.SYNOPSIS
    Periodically zips the current directory into a ring buffer of backup archives.
.DESCRIPTION
    Watches the current (or specified) directory and creates timestamped zip
    backups at a configurable interval.  Only the most recent N archives are
    kept (ring / circular buffer); the oldest backup is deleted when a new one
    would exceed the limit.
.PARAMETER Path
    Directory to back up.  Defaults to the current working directory ($PWD).
.PARAMETER OutputDir
    Directory where zip files are stored.  Defaults to a "_backups" folder
    next to the target directory.
.PARAMETER IntervalMinutes
    Minutes between each backup.  Default: 5.
.PARAMETER BufferSize
    Maximum number of zip files to keep (ring buffer depth).  Default: 10.
.EXAMPLE
    .\auto-backup.ps1
    Backs up $PWD every 5 minutes, keeping the latest 10 zips.
.EXAMPLE
    .\auto-backup.ps1 -Path C:\Projects\MyApp -IntervalMinutes 2 -BufferSize 20
    Backs up C:\Projects\MyApp every 2 minutes, keeping 20 archives.
#>
[CmdletBinding()]
param(
    [string]$Path = $PWD.Path,
    [string]$OutputDir,
    [ValidateRange(0.1, [double]::MaxValue)]
    [double]$IntervalMinutes = 5,
    [ValidateRange(1, [int]::MaxValue)]
    [int]$BufferSize = 10
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Path = (Resolve-Path $Path).Path
if (-not $OutputDir) {
    $OutputDir = Join-Path (Split-Path $Path -Parent) (
        '{0}_backups' -f (Split-Path $Path -Leaf)
    )
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "[init] Created output directory: $OutputDir"
}
$BackupPrefix = (Split-Path $Path -Leaf) + '_backup_'
function Get-ExistingBackups {
    Get-ChildItem -Path $OutputDir -Filter "${BackupPrefix}*.zip" -File |
        Sort-Object Name
}
function Remove-OldestBackups {
    param([int]$MaxKeep)
    $existing = @(Get-ExistingBackups)
    $excess   = $existing.Count - $MaxKeep
    if ($excess -gt 0) {
        $existing | Select-Object -First $excess | ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Host "[ring] Removed oldest backup: $($_.Name)"
        }
    }
}
function New-BackupZip {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $zipName   = "${BackupPrefix}${timestamp}.zip"
    $zipPath   = Join-Path $OutputDir $zipName
    $tempDir   = Join-Path ([System.IO.Path]::GetTempPath()) "backup_staging_$timestamp"
    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $outputLeaf = Split-Path $OutputDir -Leaf
        $items = Get-ChildItem -Path $Path -Force | Where-Object {
            $_.Name -ne $outputLeaf
        }
        foreach ($item in $items) {
            $dest = Join-Path $tempDir $item.Name
            if ($item.PSIsContainer) {
                Copy-Item $item.FullName $dest -Recurse -Force
            } else {
                Copy-Item $item.FullName $dest -Force
            }
        }
        Compress-Archive -Path (Join-Path $tempDir '*') -DestinationPath $zipPath -Force
        $sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
        Write-Host "[backup] $zipName ($sizeMB MB)"
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $zipPath
}
$intervalSeconds = [int]($IntervalMinutes * 60)
Write-Host '============================================'
Write-Host '  Auto-Backup (Ring Buffer)                 '
Write-Host '============================================'
Write-Host "  Source:      $Path"
Write-Host "  Output:      $OutputDir"
Write-Host "  Interval:    $IntervalMinutes min ($intervalSeconds s)"
Write-Host "  Buffer size: $BufferSize"
Write-Host "  Excludes:    $($ExcludePatterns -join ', ')"
Write-Host '============================================'
Write-Host ''
Write-Host 'Press Ctrl+C to stop.'
Write-Host ''
$iteration = 0
try {
    while ($true) {
        $iteration++
        $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$now] Backup #$iteration starting..."
        Remove-OldestBackups -MaxKeep ($BufferSize - 1)
        $zip = New-BackupZip
        $remaining = @(Get-ExistingBackups).Count
        Write-Host "[ring] $remaining / $BufferSize slots used"
        Write-Host ''
        Start-Sleep -Seconds $intervalSeconds
    }
}
finally {
    Write-Host "`n[exit] Auto-backup stopped."
}
