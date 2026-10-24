# GameTools

实用游戏/项目开发工具集。

---

## auto-backup.ps1 — 环形缓冲区自动备份

定时将指定目录打包为 `.zip` 备份，自动维护最近 N 个存档（环形缓冲），超出数量时自动删除最旧的备份。

### 快速开始

#### 一键远程运行（无需下载，支持传参）

```powershell
# 默认参数
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/MuGdxy/GameTools/main/auto-backup.ps1)))

# 带参数
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/MuGdxy/GameTools/main/auto-backup.ps1))) -Path "C:\Projects\MyApp" -IntervalMinutes 2 -BufferSize 20
```

#### 本地调用

```powershell
# 克隆仓库
git clone https://github.com/MuGdxy/GameTools.git
cd GameTools

# 默认：备份当前目录，每 5 分钟一次，保留 10 个存档
.\auto-backup.ps1

# 自定义参数
.\auto-backup.ps1 -Path "C:\Projects\MyApp" -IntervalMinutes 2 -BufferSize 20
```

### 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-Path` | string | 当前目录 `$PWD` | 要备份的目录路径 |
| `-OutputDir` | string | `<目录>/_backups`（目录内部） | 备份 zip 存放目录 |
| `-IntervalMinutes` | double | `5` | 每次备份的间隔（分钟），最小 0.1 |
| `-BufferSize` | int | `10` | 环形缓冲区大小（最多保留的 zip 数量） |

### 使用示例

```powershell
# 示例 1：最简单用法 — 备份当前目录
.\auto-backup.ps1

# 示例 2：每 2 分钟备份，保留 20 个存档
.\auto-backup.ps1 -Path C:\Projects\MyApp -IntervalMinutes 2 -BufferSize 20

# 示例 3：自定义输出目录
.\auto-backup.ps1 -Path C:\Work -OutputDir D:\Backups\WorkBackups

# 示例 4：30 秒备份一次（用于关键操作期间）
.\auto-backup.ps1 -IntervalMinutes 0.5 -BufferSize 5
```

### 运行输出示例

```
============================================
  Auto-Backup (Ring Buffer)
============================================
  Source:      C:\Projects\MyApp
  Output:      C:\Projects\MyApp\_backups
  Interval:    5 min (300 s)
  Buffer size: 10
============================================

Press Ctrl+C to stop.

[2026-10-25 01:30:00] Backup #1 starting...
[backup] MyApp_backup_20261025_013000.zip (12.34 MB)
[ring] 1 / 10 slots used
```

### 停止

按 `Ctrl+C` 即可安全停止，脚本会输出 `[exit] Auto-backup stopped.`。

---

## License

MIT
