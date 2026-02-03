#
# Claude Code Vietnamese IME Fix - Universal Installer (Windows)
# Tu dong cai dat Vietnamese IME fix cho Claude Code tren Windows
#
# Usage:
#   irm https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/install.ps1 | iex
#
# Or download and run:
#   powershell -ExecutionPolicy Bypass -File install.ps1
#

$ErrorActionPreference = "Stop"

# Constants
$SCRIPT_VERSION = "1.0.0"
$WORK_DIR = ".claude-vn-fix"
$VENV_PATH = "$WORK_DIR\venv"
$PATCHER_PATH = "$WORK_DIR\patcher.py"
$PATCHER_URL = "https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patcher.py"
$MIN_PYTHON_VERSION = [version]"3.7"

# Colors (simplified for Windows console - no diacritics in Vietnamese)
function Write-Header {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  Claude Code Vietnamese IME Fix - Installer v$SCRIPT_VERSION" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "-> $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[LOI] $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor Yellow
}

# Task 3.1: Python dependency check (py launcher)
function Test-Python {
    Write-Step "Kiem tra Python..."

    $pythonCmd = $null
    $pythonVersion = $null

    # Try py launcher first (Windows standard)
    try {
        $output = py --version 2>&1 | Out-String
        if ($output -match "Python (\d+\.\d+\.\d+)") {
            $pythonVersion = [version]$Matches[1]
            if ($pythonVersion -ge $MIN_PYTHON_VERSION) {
                $pythonCmd = "py"
            }
        }
    } catch {
        # py launcher not available
    }

    # Try python3 command
    if (-not $pythonCmd) {
        try {
            $output = python3 --version 2>&1 | Out-String
            if ($output -match "Python (\d+\.\d+\.\d+)") {
                $pythonVersion = [version]$Matches[1]
                if ($pythonVersion -ge $MIN_PYTHON_VERSION) {
                    $pythonCmd = "python3"
                }
            }
        } catch {
            # python3 not available
        }
    }

    # Try python command
    if (-not $pythonCmd) {
        try {
            $output = python --version 2>&1 | Out-String
            if ($output -match "Python (\d+\.\d+\.\d+)") {
                $pythonVersion = [version]$Matches[1]
                if ($pythonVersion -ge $MIN_PYTHON_VERSION) {
                    $pythonCmd = "python"
                }
            }
        } catch {
            # python not available
        }
    }

    if (-not $pythonCmd) {
        Write-Error "Khong tim thay Python 3.7+"
        Write-Host ""
        Write-Host "De cai dat Python:"
        Write-Host ""
        Write-Host "  Cach 1: Tai tu python.org"
        Write-Host "          https://python.org/downloads"
        Write-Host ""
        Write-Host "  Cach 2: Dung winget"
        Write-Host "          winget install Python.Python.3.12"
        Write-Host ""
        Write-Host "  Cach 3: Dung Microsoft Store"
        Write-Host "          ms-windows-store://pdp/?ProductId=9NCVDN91XZQP"
        Write-Host ""
        Write-Host "Sau khi cai dat, chay lai lenh nay."
        Write-Host ""
        exit 1
    }

    Write-Success "Python $pythonVersion tim thay ($pythonCmd)"
    return $pythonCmd
}

# Task 3.2: Python venv creation
function New-PythonVenv {
    param([string]$PythonCmd)

    Write-Step "Thiet lap moi truong Python..."

    # Create work directory if not exists
    if (-not (Test-Path $WORK_DIR)) {
        New-Item -ItemType Directory -Path $WORK_DIR | Out-Null
        Write-Success "Da tao thu muc: $WORK_DIR"
    }

    # Create venv if not exists
    if (-not (Test-Path $VENV_PATH)) {
        Write-Success "Dang tao Python virtual environment..."
        & $PythonCmd -m venv $VENV_PATH
        Write-Success "Da tao venv tai: $VENV_PATH"
    } else {
        Write-Success "Venv da ton tai: $VENV_PATH"
    }
}

# Task 3.3: Venv reuse logic
function Test-VenvValid {
    Write-Step "Kiem tra virtual environment..."

    $pythonInVenv = "$VENV_PATH\Scripts\python.exe"

    if (Test-Path $pythonInVenv) {
        # Test if venv python works
        try {
            $null = & $pythonInVenv --version 2>&1
            Write-Success "Virtual environment hop le"
            return $pythonInVenv
        } catch {
            Write-Warning "Virtual environment bi hong, dang tao lai..."
            Remove-Item -Recurse -Force $VENV_PATH
            return $null
        }
    }

    return $null
}

# Task 3.4: Claude Code detection (npm only)
function Find-ClaudeCode {
    Write-Step "Tim kiem Claude Code..."

    $claudePath = $null
    $claudeType = "npm"

    # npm installation paths on Windows
    $npmPaths = @(
        "$env:APPDATA\npm\node_modules\@anthropic\claude-code\dist\cli\cli.js",
        "$env:ProgramFiles\nodejs\node_modules\@anthropic\claude-code\dist\cli\cli.js",
        "$env:LOCALAPPDATA\npm\node_modules\@anthropic\claude-code\dist\cli\cli.js"
    )

    # Also check if installed globally via nvm-windows
    $nvmRoot = $env:NVM_HOME
    if ($nvmRoot) {
        $nvmVersions = Get-ChildItem "$nvmRoot" -Directory -ErrorAction SilentlyContinue
        foreach ($version in $nvmVersions) {
            $npmPaths += "$($version.FullName)\node_modules\@anthropic\claude-code\dist\cli\cli.js"
        }
    }

    foreach ($path in $npmPaths) {
        if (Test-Path $path) {
            $claudePath = $path
            break
        }
    }

    if (-not $claudePath) {
        Write-Error "Khong tim thay Claude Code"
        Write-Host ""
        Write-Host "Vui long cai dat Claude Code truoc:"
        Write-Host "  npm:  npm install -g @anthropic/claude-code"
        Write-Host ""
        Write-Host "Luu y: Ban Windows chi ho tro ban npm."
        Write-Host ""
        exit 1
    }

    # Get version if possible
    $version = "unknown"
    $pkgJson = Join-Path (Split-Path (Split-Path (Split-Path $claudePath))) "package.json"
    if (Test-Path $pkgJson) {
        $pkg = Get-Content $pkgJson | ConvertFrom-Json
        $version = $pkg.version
    }

    Write-Success "Tim thay: $claudeType"
    Write-Success "Duong dan: $claudePath"
    if ($version -ne "unknown") {
        Write-Success "Phien ban: $version"
    }

    return @{
        Type = $claudeType
        Path = $claudePath
    }
}

# Task 3.5: patcher.py download/update
function Get-Patcher {
    Write-Step "Kiem tra patcher.py..."

    if (Test-Path $PATCHER_PATH) {
        Write-Success "patcher.py da ton tai"
        # TODO: Check for updates from GitHub
        return
    }

    # Try to download from GitHub
    Write-Success "Dang tai patcher.py tu GitHub..."

    try {
        # Force TLS 1.2+ for secure connection (TLS 1.3 may not be available on older systems)
        $tls = [Net.SecurityProtocolType]::Tls12
        if ([Enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls13') {
            $tls = $tls -bor [Net.SecurityProtocolType]::Tls13
        }
        [Net.ServicePointManager]::SecurityProtocol = $tls
        # Use -UseBasicParsing to avoid IE dependency and ensure cert validation
        Invoke-RestMethod -Uri $PATCHER_URL -OutFile $PATCHER_PATH -ErrorAction Stop -UseBasicParsing
        Write-Success "Da tai patcher.py"
        return
    } catch {
        # Download failed
    }

    # Fallback: check if patcher.py exists in current directory
    if (Test-Path "patcher.py") {
        Write-Warning "Khong the tai tu GitHub, su dung file local"
        Copy-Item "patcher.py" $PATCHER_PATH
        Write-Success "Da copy patcher.py tu thu muc hien tai"
        return
    }

    Write-Error "Khong the tai patcher.py tu GitHub hoac tim thay file local"
    Write-Host ""
    Write-Host "Vui long:"
    Write-Host "  1. Kiem tra ket noi mang"
    Write-Host "  2. Hoac tai patcher.py thu cong tu:"
    Write-Host "     https://github.com/manhit96/claude-code-vietnamese-fix"
    Write-Host "  3. Dat file patcher.py trong thu muc hien tai va chay lai"
    Write-Host ""
    exit 1
}

# Task 3.6: User confirmation (Vietnamese no diacritics)
function Confirm-Installation {
    param(
        [string]$ClaudeType,
        [string]$ClaudePath
    )

    Write-Host ""
    Write-Host "==============================================================="
    Write-Host "  THONG TIN CAI DAT"
    Write-Host "==============================================================="
    Write-Host ""
    Write-Host "  • Loai cai dat: $ClaudeType"
    Write-Host "  • Duong dan:    $ClaudePath"
    Write-Host "  • Phuong phap:  Dynamic pattern matching"
    Write-Host "  • Backup:       Tu dong tao file .backup"
    Write-Host ""
    Write-Host "==============================================================="
    Write-Host ""

    $choice = Read-Host "Tiep tuc cai dat? (y/N)"

    if ($choice -ne "y" -and $choice -ne "Y") {
        Write-Host ""
        Write-Warning "Da huy cai dat"
        exit 0
    }
}

# Task 3.7: Execute patcher
function Invoke-Patcher {
    param(
        [string]$PythonVenv,
        [string]$ClaudeType,
        [string]$ClaudePath
    )

    Write-Step "Ap dung Vietnamese IME fix..."

    try {
        & "$PythonVenv" "$PATCHER_PATH" patch --type $ClaudeType --path "$ClaudePath"
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Success "Da cai dat thanh cong!"
            return $true
        } else {
            Write-Host ""
            Write-Error "Cai dat that bai"
            return $false
        }
    } catch {
        Write-Host ""
        Write-Error "Cai dat that bai: $($_.Exception.Message)"
        return $false
    }
}

# Task 3.8: Error handling + rollback (integrated)
# Task 3.9: Manual testing prompt
function Invoke-ManualTest {
    param(
        [string]$ClaudePath,
        [string]$PythonVenv
    )

    Write-Host ""
    Write-Host "==============================================================="
    Write-Host "  [!] CAN TEST THU CONG"
    Write-Host "==============================================================="
    Write-Host ""
    Write-Host "Vui long test go tieng Viet ngay:"
    Write-Host ""
    Write-Host "  1. Mo terminal moi"
    Write-Host "  2. Chay: claude"
    Write-Host "  3. Go tieng Viet voi bo go cua ban (OpenKey, Unikey, v.v.)"
    Write-Host "  4. Thu go: ""Xin chao, toi la Claude"""
    Write-Host ""
    Write-Host "==============================================================="
    Write-Host ""

    $testResult = Read-Host "Go tieng Viet da hoat dong chua? (y/N)"

    if ($testResult -eq "y" -or $testResult -eq "Y") {
        Write-Host ""
        Write-Success "Vietnamese IME fix hoat dong tot!"
        Write-Host ""
        Write-Host "Neu gap van de sau nay:"
        Write-Host "  • Khoi phuc: cd ""$PWD"" ; & ""$PythonVenv"" ""$PATCHER_PATH"" restore --path `"$ClaudePath`""
        Write-Host "  • Bao loi:   https://github.com/manhit96/claude-code-vietnamese-fix/issues"
        Write-Host ""
    } else {
        Write-Host ""
        Write-Warning "Go tieng Viet van chua hoat dong"
        Write-Host ""
        Write-Step "Dang rollback patch..."

        try {
            & "$PythonVenv" "$PATCHER_PATH" restore --path "$ClaudePath"
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Da khoi phuc tu backup"
            }
        } catch {
            Write-Error "Khoi phuc that bai: $($_.Exception.Message)"
        }

        Write-Step "Dang tao bao cao diagnostic..."
        $diagnosticFile = "$WORK_DIR\diagnostic-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

        try {
            & "$PythonVenv" "$PATCHER_PATH" diagnostic --path "$ClaudePath" --output $diagnosticFile
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Da luu: $diagnosticFile"
            }
        } catch {
            Write-Warning "Khong the tao diagnostic: $($_.Exception.Message)"
        }

        Write-Host ""
        Write-Host "Vui long bao loi tai:"
        Write-Host "  https://github.com/manhit96/claude-code-vietnamese-fix/issues/new"
        Write-Host ""
        Write-Host "Dinh kem file $diagnosticFile khi bao loi."
        Write-Host ""
        exit 1
    }
}

# Main installation flow
function Invoke-Main {
    Write-Header

    try {
        # Step 1: Check Python
        $pythonCmd = Test-Python

        # Step 2: Create venv
        New-PythonVenv -PythonCmd $pythonCmd

        # Step 3: Check venv validity
        $pythonVenv = Test-VenvValid
        if (-not $pythonVenv) {
            New-PythonVenv -PythonCmd $pythonCmd
            $pythonVenv = "$VENV_PATH\Scripts\python.exe"
        }

        # Step 4: Find Claude Code
        $claude = Find-ClaudeCode

        # Step 5: Download patcher
        Get-Patcher

        # Step 6: Confirm with user
        Confirm-Installation -ClaudeType $claude.Type -ClaudePath $claude.Path

        # Step 7: Run patcher
        $success = Invoke-Patcher -PythonVenv $pythonVenv -ClaudeType $claude.Type -ClaudePath $claude.Path

        if ($success) {
            # Step 8: Manual testing prompt
            Invoke-ManualTest -ClaudePath $claude.Path -PythonVenv $pythonVenv
        } else {
            Write-Error "Vui long kiem tra loi o tren"
            exit 1
        }
    } catch {
        Write-Error "Loi xay ra: $($_.Exception.Message)"
        Write-Host ""
        Write-Host $_.ScriptStackTrace
        exit 1
    }
}

# Run main function
Invoke-Main
