<#
.SYNOPSIS
    定时将当前目录打包为环形缓冲区备份存档。
.DESCRIPTION
    监视当前（或指定的）目录，按可配置的时间间隔创建带时间戳的 zip 备份。
    仅保留最近 N 个存档（环形/循环缓冲）；当新备份超出限制时，自动删除最旧的备份。
.PARAMETER Path
    要备份的目录。默认为当前工作目录 ($PWD)。
.PARAMETER OutputDir
    存放 zip 文件的目录。默认为目标目录内的 "_backups" 文件夹。
.PARAMETER IntervalMinutes
    每次备份的间隔（分钟）。默认：5。
.PARAMETER BufferSize
    最多保留的 zip 文件数量（环形缓冲区深度）。默认：10。
.EXAMPLE
    .\auto-backup.ps1
    每 5 分钟备份当前目录，保留最近 10 个存档。
.EXAMPLE
    .\auto-backup.ps1 -Path C:\Projects\MyApp -IntervalMinutes 2 -BufferSize 20
    每 2 分钟备份 C:\Projects\MyApp，保留 20 个存档。
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
    $OutputDir = Join-Path $Path '_backups'
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "[初始化] 已创建输出目录: $OutputDir"
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
            Write-Host "[轮替] 已删除最旧备份: $($_.Name)"
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
        Write-Host "[备份] $zipName ($sizeMB MB)"
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
Write-Host '  自动备份（环形缓冲区）                   '
Write-Host '============================================'
Write-Host "  备份目录:    $Path"
Write-Host "  输出目录:    $OutputDir"
Write-Host "  备份间隔:    $IntervalMinutes 分钟 ($intervalSeconds 秒)"
Write-Host "  缓冲区大小:  $BufferSize"
Write-Host '============================================'
Write-Host ''
Write-Host '按 Ctrl+C 停止。'
Write-Host ''
$iteration = 0
try {
    while ($true) {
        $iteration++
        $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$now] 第 $iteration 次备份开始..."
        Remove-OldestBackups -MaxKeep ($BufferSize - 1)
        $zip = New-BackupZip
        $remaining = @(Get-ExistingBackups).Count
        Write-Host "[轮替] 已使用 $remaining / $BufferSize 个槽位"
        Write-Host ''
        Start-Sleep -Seconds $intervalSeconds
    }
}
finally {
    Write-Host "`n[退出] 自动备份已停止。"
}
