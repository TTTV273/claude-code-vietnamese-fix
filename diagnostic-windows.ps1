#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code Vietnamese IME Fix - Cong cu chan doan (Windows)

.DESCRIPTION
    Thu thap thong tin moi truong de debug loi go tieng Viet.
    Co the tu dong tao GitHub issue.

.PARAMETER CreateIssue
    Tu dong mo trang tao GitHub issue voi thong tin da thu thap

.EXAMPLE
    .\diagnostic-windows.ps1
    .\diagnostic-windows.ps1 -CreateIssue

.LINK
    https://github.com/manhit96/claude-code-vietnamese-fix
#>

[CmdletBinding()]
param(
    [switch]$CreateIssue
)

$ErrorActionPreference = 'Continue'
$REPO_URL = "https://github.com/manhit96/claude-code-vietnamese-fix"

# Colors
$script:Colors = @{
    Red    = 'Red'
    Green  = 'Green'
    Yellow = 'Yellow'
    Blue   = 'Cyan'
    White  = 'White'
}

function Write-ColorLine {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
}

function Write-Header {
    Write-Host ""
    Write-ColorLine "============================================================" $Colors.Blue
    Write-ColorLine "  Claude Code Vietnamese IME Fix - Chan doan (Windows)      " $Colors.Blue
    Write-ColorLine "============================================================" $Colors.Blue
    Write-Host ""
}

# Collect all diagnostic info
$script:DiagnosticOutput = @()

function Add-DiagLine {
    param([string]$Text)
    $script:DiagnosticOutput += $Text
    Write-Host $Text
}

function Get-SystemInfo {
    Add-DiagLine "[THONG TIN HE THONG]"

    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        Add-DiagLine "  He dieu hanh: $($os.Caption) $($os.Version)"
    } else {
        Add-DiagLine "  He dieu hanh: Windows (khong xac dinh)"
    }

    Add-DiagLine "  PowerShell: $($PSVersionTable.PSVersion.ToString())"
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    Add-DiagLine "  Kien truc: $arch"
    Add-DiagLine ""
}

function Get-NodeInfo {
    Add-DiagLine "[NODE.JS/NPM]"

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVersion = & node --version 2>$null
        $nodePath = $nodeCmd.Source
        Add-DiagLine "  Node.js: $nodeVersion"
        Add-DiagLine "  Duong dan: $nodePath"

        $npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
        if ($npmCmd) {
            $npmVersion = & npm.cmd --version 2>$null
            Add-DiagLine "  npm: $npmVersion"

            $npmRoot = & npm.cmd root -g 2>$null
            if ($npmRoot) {
                Add-DiagLine "  npm global: $npmRoot"
            }
        } else {
            Add-DiagLine "  npm: KHONG TIM THAY"
        }

        # Detect install method
        $installMethod = "Khong xac dinh"
        if ($nodePath -match '\\nvm\\') { $installMethod = "nvm-windows" }
        elseif ($nodePath -match '\\fnm\\') { $installMethod = "fnm" }
        elseif ($nodePath -match '\\scoop\\') { $installMethod = "scoop" }
        elseif ($nodePath -match '\\Chocolatey\\') { $installMethod = "chocolatey" }
        elseif ($nodePath -match 'Program Files') { $installMethod = "Official installer" }
        Add-DiagLine "  Cai qua: $installMethod"
    } else {
        Add-DiagLine "  Node.js: KHONG TIM THAY"
    }

    Add-DiagLine ""
}

function Find-ClaudeCliJs {
    param([string]$ClaudePath)

    # Method 1: From claude command path
    if ($ClaudePath -and ($ClaudePath -match '\.(cmd|bat|ps1)$')) {
        $claudeDir = Split-Path $ClaudePath -Parent
        $npmModules = Join-Path $claudeDir "node_modules\@anthropic-ai\claude-code\cli.js"
        if (Test-Path $npmModules) {
            return $npmModules
        }
    }

    # Method 2: npm root -g
    try {
        $npmRoot = & npm.cmd root -g 2>$null
        if ($npmRoot) {
            $cliPath = Join-Path $npmRoot "@anthropic-ai\claude-code\cli.js"
            if (Test-Path $cliPath) {
                return $cliPath
            }
        }
    } catch { }

    # Method 3: Common paths
    $commonPaths = @(
        "$env:APPDATA\npm\node_modules\@anthropic-ai\claude-code\cli.js"
        "$env:USERPROFILE\AppData\Local\npm\node_modules\@anthropic-ai\claude-code\cli.js"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Get-ClaudeInfo {
    Add-DiagLine "[CLAUDE CODE]"

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue

    if (-not $claudeCmd) {
        Add-DiagLine "  Trang thai: KHONG TIM THAY"
        Add-DiagLine ""
        return @{ Installed = $false; CliJs = $null; CanPatch = $false }
    }

    $claudePath = $claudeCmd.Source
    Add-DiagLine "  Trang thai: Da cai dat"
    Add-DiagLine "  Duong dan: $claudePath"

    # Detect install type
    $installType = "khong xac dinh"
    $canPatch = $false

    if ($claudePath -match '\.exe$') {
        $fileInfo = Get-Item $claudePath -ErrorAction SilentlyContinue
        if ($fileInfo.Length -gt 1MB) {
            $installType = "binary"
            $canPatch = $false
        } else {
            $installType = "exe khong xac dinh"
            $canPatch = $false
        }
    } elseif ($claudePath -match '\.(cmd|bat|ps1)$') {
        $installType = "npm"
        $canPatch = $true
    }

    Add-DiagLine "  Loai cai: $installType"
    Add-DiagLine "  Co the fix: $canPatch"

    $cliJsPath = Find-ClaudeCliJs -ClaudePath $claudePath

    if ($cliJsPath) {
        Add-DiagLine "  cli.js: $cliJsPath"
    } else {
        Add-DiagLine "  cli.js: KHONG TIM THAY"
    }

    try {
        $version = & claude --version 2>$null | Select-Object -First 1
        Add-DiagLine "  Phien ban: $version"
    } catch {
        Add-DiagLine "  Phien ban: Khong xac dinh"
    }

    Add-DiagLine ""

    return @{
        Installed = $true
        CliJs = $cliJsPath
        CanPatch = $canPatch
    }
}

function Get-PatchStatus {
    param([string]$CliJsPath)

    Add-DiagLine "[TRANG THAI FIX]"

    if (-not $CliJsPath -or -not (Test-Path $CliJsPath)) {
        Add-DiagLine "  Trang thai: N/A (khong tim thay cli.js)"
        Add-DiagLine ""
        return
    }

    $content = Get-Content $CliJsPath -Raw -ErrorAction SilentlyContinue
    $isPatched = $content -match "PHTV Vietnamese IME fix"

    if ($isPatched) {
        Add-DiagLine "  Trang thai: DA FIX"
    } else {
        Add-DiagLine "  Trang thai: CHUA FIX"

        # Check for bug code
        $hasBugCode = ($content -match 'backspace\(\)') -and ($content -match '\\x7f|"\x7f"')
        if ($hasBugCode) {
            Add-DiagLine "  Code loi: CO TON TAI (can fix)"
        } else {
            Add-DiagLine "  Code loi: KHONG TIM THAY (co the da duoc Anthropic sua)"
        }
    }

    # Check backups
    $cliDir = Split-Path $CliJsPath -Parent
    $backups = Get-ChildItem $cliDir -Filter "cli.js.backup-*" -ErrorAction SilentlyContinue
    Add-DiagLine "  Backup: $($backups.Count) file"

    # Check cli.js size
    $fileInfo = Get-Item $CliJsPath -ErrorAction SilentlyContinue
    if ($fileInfo) {
        $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        Add-DiagLine "  Kich thuoc cli.js: $sizeMB MB"
    }

    Add-DiagLine ""
}

function Get-IMEInfo {
    Add-DiagLine "[BO GO TIENG VIET]"

    # Get keyboard layouts
    $layouts = Get-WinUserLanguageList -ErrorAction SilentlyContinue
    if ($layouts) {
        foreach ($lang in $layouts) {
            Add-DiagLine "  Ngon ngu: $($lang.LanguageTag)"
            foreach ($input in $lang.InputMethodTips) {
                Add-DiagLine "    Kieu go: $input"
            }
        }
    } else {
        Add-DiagLine "  Khong lay duoc danh sach ngon ngu"
    }

    # Detect Vietnamese IME processes
    $imeProcesses = @('UniKeyNT', 'EVKey', 'OpenKey', 'GoTiengViet', 'Unikey')
    $runningIME = @()
    foreach ($ime in $imeProcesses) {
        $proc = Get-Process -Name $ime -ErrorAction SilentlyContinue
        if ($proc) {
            $runningIME += $ime
        }
    }

    if ($runningIME.Count -gt 0) {
        Add-DiagLine "  Bo go dang chay: $($runningIME -join ', ')"
    } else {
        Add-DiagLine "  Bo go dang chay: Khong phat hien (co the dung bo go Windows)"
    }

    Add-DiagLine ""
}

function Get-PatchCodeDetails {
    param([string]$CliJsPath)

    Add-DiagLine "[CHI TIET CODE FIX]"

    if (-not $CliJsPath -or -not (Test-Path $CliJsPath)) {
        Add-DiagLine "  Khong tim thay cli.js"
        Add-DiagLine ""
        return
    }

    $content = Get-Content $CliJsPath -Raw -ErrorAction SilentlyContinue

    # Check for PHTV marker
    if ($content -match "PHTV Vietnamese IME fix") {
        Add-DiagLine "  Danh dau fix: TIM THAY"

        # Extract variable name used in patch
        if ($content -match "PHTV Vietnamese IME fix\*/let _phtv_clean=s\.replace.*?for\(const _c of _phtv_clean\)\{(\w+)=") {
            Add-DiagLine "  Bien su dung: $($Matches[1])"
        }

        # Check if patch code looks correct
        if ($content -match "_phtv_clean\.length>0") {
            Add-DiagLine "  Logic fix: OK"
        } else {
            Add-DiagLine "  Logic fix: CHUA HOAN CHINH"
        }
    } else {
        Add-DiagLine "  Danh dau fix: KHONG TIM THAY"
    }

    # Check original bug code pattern
    if ($content -match 'backspace\(\)') {
        Add-DiagLine "  Ham backspace(): TIM THAY"
    }

    # Check which variable pattern exists
    $varPatterns = @('_(FA.offset)}', '_(EA.offset)}', '_(A.offset)}')
    foreach ($pat in $varPatterns) {
        if ($content.Contains($pat)) {
            Add-DiagLine ("  Pattern '" + $pat + "': TIM THAY")
        }
    }

    # Check for 0x7F handling
    $x7fPattern = '\\x7f|"\x7f"'
    if ($content -match $x7fPattern) {
        Add-DiagLine "  Xu ly 0x7F: TIM THAY"
    }

    Add-DiagLine ""
}

function Start-DebugMode {
    Write-Host ""
    Write-ColorLine "============================================================" $Colors.Yellow
    Write-ColorLine "  CHE DO DEBUG - Thu thap du lieu nhap" $Colors.Yellow
    Write-ColorLine "============================================================" $Colors.Yellow
    Write-Host ""
    Write-Host "  Phan nay se thu thap du lieu ban phim de phan tich bo go tieng Viet."
    Write-Host "  Go mot tu tieng Viet (VD: 'viet') roi nhan Enter."
    Write-Host "  Nhan Ctrl+C de thoat."
    Write-Host ""

    Write-ColorLine "  Nhap:" $Colors.Green
    $input = Read-Host

    Write-Host ""
    Write-ColorLine "  Bytes tho (hex):" $Colors.Yellow

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($input)
    $hexString = ($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
    Write-Host "  $hexString"

    Write-Host ""
    Write-ColorLine "  Phan tich ky tu:" $Colors.Yellow
    foreach ($char in $input.ToCharArray()) {
        $code = [int][char]$char
        $hex = '{0:X4}' -f $code
        $desc = switch ($code) {
            0x7F { "(DEL - danh dau bo go tieng Viet)" }
            0x08 { "(Backspace)" }
            default { "" }
        }
        Write-Host "  '$char' = U+$hex $desc"
    }

    # Check for 0x7F
    if ($input.Contains([char]0x7F)) {
        Write-Host ""
        Write-ColorLine "  >> Tim thay ky tu DEL (0x7F) - Day la pattern bo go tieng Viet!" $Colors.Green
    } elseif ($input.Contains([char]0x08)) {
        Write-Host ""
        Write-ColorLine "  >> Tim thay ky tu Backspace (0x08) - Pattern bo go khac!" $Colors.Yellow
    } else {
        Write-Host ""
        Write-ColorLine "  >> Khong tim thay ky tu dieu khien dac biet" $Colors.Blue
    }

    Write-Host ""
}

function Create-GitHubIssue {
    # Get version for title prefix
    $claudeVersion = "Unknown"
    try {
        $ver = & claude --version 2>$null | Select-Object -First 1
        if ($ver -match '[\d.]+') {
            $claudeVersion = "v$($Matches[0])"
        }
    } catch { }

    $issueTitle = "[Windows][$claudeVersion] Vietnamese IME issue"

    $body = @"
## Environment

``````
$($script:DiagnosticOutput -join "`n")
``````

## Problem Description

<!-- Mo ta van de ban gap phai -->

## Steps to Reproduce

1.
2.
3.

## Expected Behavior

<!-- Ket qua mong doi -->

## Actual Behavior

<!-- Ket qua thuc te -->
"@

    # URL encode the body
    $encodedBody = [System.Web.HttpUtility]::UrlEncode($body)
    $encodedTitle = [System.Web.HttpUtility]::UrlEncode($issueTitle)

    $issueUrl = "$REPO_URL/issues/new?title=$encodedTitle&body=$encodedBody"

    Write-Host ""
    Write-ColorLine "[TAO GITHUB ISSUE]" $Colors.Yellow
    Write-Host "  Dang mo trinh duyet de tao issue..."
    Write-Host ""

    Start-Process $issueUrl
}

function Show-Summary {
    Write-Host ""
    Write-ColorLine "============================================================" $Colors.Blue
    Write-ColorLine "  TONG KET" $Colors.Blue
    Write-ColorLine "============================================================" $Colors.Blue
    Write-Host ""
    Write-Host "  Copy ket qua o tren va dan khi tao issue tai:"
    Write-ColorLine "  $REPO_URL/issues" $Colors.Green
    Write-Host ""
    Write-Host "  Hoac chay voi -CreateIssue de tu dong mo GitHub:"
    Write-ColorLine "  .\diagnostic-windows.ps1 -CreateIssue" $Colors.Yellow
    Write-Host ""
}

# Main
function Main {
    # Load System.Web for URL encoding
    Add-Type -AssemblyName System.Web

    Write-Header
    Get-SystemInfo
    Get-NodeInfo
    $claudeInfo = Get-ClaudeInfo

    if ($claudeInfo.CliJs) {
        Get-PatchStatus -CliJsPath $claudeInfo.CliJs
        Get-PatchCodeDetails -CliJsPath $claudeInfo.CliJs
    }

    Get-IMEInfo
    Start-DebugMode

    if ($CreateIssue) {
        Create-GitHubIssue
    } else {
        Show-Summary
    }
}

Main
