#
# Claude Code Vietnamese IME Fix - Installer (Windows)
# Clone repo va tu dong chay fix
#
# Usage:
#   irm https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/install.ps1 | iex
#

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/manhit96/claude-code-vietnamese-fix.git"
$InstallDir = Join-Path $env:USERPROFILE ".claude-vn-fix"

Write-Host ""
Write-Host "Claude Code Vietnamese IME Fix - Installer"
Write-Host ""

# Check git
$gitExists = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitExists) {
    Write-Host "[ERROR] git khong tim thay" -ForegroundColor Red
    Write-Host "Cai dat: https://git-scm.com/downloads"
    exit 1
}

# Check python
$PythonCmd = $null
foreach ($cmd in @("python3", "python", "py")) {
    try {
        $null = & $cmd --version 2>&1
        $PythonCmd = $cmd
        break
    } catch {}
}

if (-not $PythonCmd) {
    Write-Host "[ERROR] Python khong tim thay" -ForegroundColor Red
    Write-Host "Cai dat: https://python.org/downloads"
    exit 1
}

# Clone or update
Write-Host "-> Cai dat vao $InstallDir..."
if (Test-Path $InstallDir) {
    Set-Location $InstallDir
    try { git pull origin main 2>&1 | Out-Null } catch {}
} else {
    git clone --depth 1 $RepoUrl $InstallDir
}
Write-Host "   Done"

# Run auto patch
Write-Host ""
Set-Location $InstallDir
& $PythonCmd patcher.py --auto

Write-Host ""
Write-Host "================================================"
Write-Host "Hoan tat!" -ForegroundColor Green
Write-Host "================================================"
Write-Host ""
Write-Host "Commands:"
Write-Host "  Fix:     $PythonCmd $InstallDir\patcher.py"
Write-Host "  Restore: $PythonCmd $InstallDir\patcher.py --restore"
Write-Host "  Update:  cd $InstallDir; git pull"
Write-Host ""
