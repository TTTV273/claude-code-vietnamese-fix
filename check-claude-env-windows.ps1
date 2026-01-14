#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code Environment Check & Setup - Windows
    Kiem tra va cai dat moi truong Claude Code tren Windows

.DESCRIPTION
    Script nay:
    - Kiem tra he thong Windows, Node.js/npm, Claude Code
    - Tu dong cai Node.js neu chua co
    - Tu dong cai Claude Code neu chua co
    - Hien thi trang thai patch

.PARAMETER AutoInstall
    Tu dong cai dat Node.js va Claude Code neu thieu

.EXAMPLE
    .\check-claude-env-windows.ps1
    .\check-claude-env-windows.ps1 -AutoInstall

.LINK
    https://github.com/manhit96/claude-code-vietnamese-fix
#>

[CmdletBinding()]
param(
    [switch]$AutoInstall = $true
)

$ErrorActionPreference = 'Continue'

# Colors
$script:Colors = @{
    Red    = 'Red'
    Green  = 'Green'
    Yellow = 'Yellow'
    Blue   = 'Cyan'
    White  = 'White'
}

function Write-ColorText {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color -NoNewline
}

function Write-ColorLine {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
}

function Write-Header {
    Write-ColorLine "" $Colors.Blue
    Write-ColorLine ([char]0x2554 + ([string][char]0x2550 * 60) + [char]0x2557) $Colors.Blue
    Write-ColorLine ([char]0x2551 + "     Claude Code Environment Check - Windows                " + [char]0x2551) $Colors.Blue
    Write-ColorLine ([char]0x255A + ([string][char]0x2550 * 60) + [char]0x255D) $Colors.Blue
    Write-Host ""
}

function Get-SystemInfo {
    Write-ColorLine "[SYSTEM INFO]" $Colors.Yellow

    $os = Get-CimInstance Win32_OperatingSystem
    $winVersion = "$($os.Caption) $($os.Version)"
    Write-Host "  Windows:     $winVersion"

    $psVersion = $PSVersionTable.PSVersion.ToString()
    Write-Host "  PowerShell:  $psVersion"

    Write-Host "  User:        $env:USERPROFILE"
    Write-Host ""
}

function Test-NodeInstalled {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    return $null -ne $nodeCmd
}

function Test-NpmInstalled {
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    return $null -ne $npmCmd
}

function Test-ClaudeInstalled {
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    return $null -ne $claudeCmd
}

function Install-NodeJs {
    Write-ColorLine "[INSTALLING NODE.JS]" $Colors.Yellow
    Write-Host "  Dang tai Node.js LTS..."

    $nodeVersion = "22.13.0"  # LTS version
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $installerUrl = "https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-$arch.msi"
    $installerPath = "$env:TEMP\node-installer.msi"

    try {
        # Download
        Write-Host "  URL: $installerUrl"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

        # Install silently
        Write-Host "  Dang cai dat Node.js v$nodeVersion..."
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$installerPath`"", "/qn", "/norestart" -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-ColorLine "  OK Node.js da cai thanh cong!" $Colors.Green

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            # Verify
            Start-Sleep -Seconds 2
            $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
            if ($nodeCmd) {
                $ver = & node --version 2>$null
                Write-Host "  Version: $ver"
                return $true
            }
            else {
                Write-ColorLine "  ! Cai xong nhung can khoi dong lai PowerShell" $Colors.Yellow
                return $true
            }
        }
        else {
            Write-ColorLine "  X Cai dat that bai (Exit code: $($process.ExitCode))" $Colors.Red
            return $false
        }
    }
    catch {
        Write-ColorLine "  X Loi: $($_.Exception.Message)" $Colors.Red
        Write-Host "  Thu cai thu cong: https://nodejs.org"
        return $false
    }
    finally {
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-ClaudeCode {
    Write-ColorLine "[INSTALLING CLAUDE CODE]" $Colors.Yellow
    Write-Host "  Dang cai @anthropic-ai/claude-code..."

    try {
        # Refresh PATH first
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $result = & npm install -g @anthropic-ai/claude-code 2>&1

        # Check if installed
        Start-Sleep -Seconds 2
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
        if ($claudeCmd) {
            Write-ColorLine "  OK Claude Code da cai thanh cong!" $Colors.Green
            $ver = & claude --version 2>$null | Select-Object -First 1
            Write-Host "  Version: $ver"
            return $true
        }
        else {
            Write-ColorLine "  X Cai dat that bai" $Colors.Red
            Write-Host $result
            return $false
        }
    }
    catch {
        Write-ColorLine "  X Loi: $($_.Exception.Message)" $Colors.Red
        return $false
    }
}

function Get-NodeInfo {
    param([switch]$Install)

    Write-ColorLine "[NODE.JS/NPM]" $Colors.Yellow

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVersion = & node --version 2>$null
        $nodePath = $nodeCmd.Source
        Write-Host "  Node.js:     $nodeVersion"
        Write-Host "  Node path:   $nodePath"

        $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
        if ($npmCmd) {
            $npmVersion = & npm --version 2>$null
            Write-Host "  npm:         $npmVersion"

            $npmRoot = & npm root -g 2>$null
            if ($npmRoot) {
                Write-Host "  npm global:  $npmRoot"
            }
        }
        else {
            Write-ColorLine "  npm:         Khong tim thay" $Colors.Red
        }

        # Detect install method
        $installMethod = "Unknown"
        if ($nodePath -match '\\nvm\\') { $installMethod = "nvm-windows" }
        elseif ($nodePath -match '\\fnm\\') { $installMethod = "fnm" }
        elseif ($nodePath -match '\\scoop\\') { $installMethod = "scoop" }
        elseif ($nodePath -match '\\Chocolatey\\') { $installMethod = "chocolatey" }
        elseif ($nodePath -match 'Program Files') { $installMethod = "Official installer" }
        Write-Host "  Install via: $installMethod"

        Write-Host ""
        return $true
    }
    else {
        Write-ColorLine "  Node.js:     Khong tim thay" $Colors.Red
        Write-Host ""

        if ($Install) {
            $installed = Install-NodeJs
            Write-Host ""
            return $installed
        }
        else {
            Write-ColorLine "  -> Can cai Node.js truoc: https://nodejs.org" $Colors.Yellow
            Write-Host ""
            return $false
        }
    }
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
        $npmRoot = & npm root -g 2>$null
        if ($npmRoot) {
            $cliPath = Join-Path $npmRoot "@anthropic-ai\claude-code\cli.js"
            if (Test-Path $cliPath) {
                return $cliPath
            }
        }
    }
    catch { }

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
    param([switch]$Install)

    Write-ColorLine "[CLAUDE CODE]" $Colors.Yellow

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue

    if (-not $claudeCmd) {
        Write-ColorLine "  Status:      X Khong tim thay" $Colors.Red
        Write-Host ""

        if ($Install) {
            $installed = Install-ClaudeCode
            Write-Host ""

            if ($installed) {
                # Re-check
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
            }
        }

        if (-not $claudeCmd) {
            return @{ Installed = $false; CliJs = $null; Type = $null; CanPatch = $false }
        }
    }

    $claudePath = $claudeCmd.Source
    Write-ColorText "  Status:      " $Colors.White
    Write-ColorLine "OK Installed" $Colors.Green

    # Detect install type
    $installType = "unknown"
    $canPatch = $false

    if ($claudePath -match '\.exe$') {
        $fileInfo = Get-Item $claudePath -ErrorAction SilentlyContinue
        if ($fileInfo.Length -gt 1MB) {
            $installType = "binary (MSI/Installer)"
            $canPatch = $false
        }
        else {
            $installType = "unknown executable"
            $canPatch = $false
        }
    }
    elseif ($claudePath -match '\.(cmd|bat|ps1)$') {
        $installType = "npm"
        $canPatch = $true
    }

    if ($canPatch) {
        Write-ColorLine "  Type:        $installType (co the patch)" $Colors.Green
    }
    else {
        Write-ColorLine "  Type:        $installType (KHONG the patch)" $Colors.Red
    }

    Write-Host "  Claude path: $claudePath"

    $cliJsPath = Find-ClaudeCliJs -ClaudePath $claudePath

    if ($cliJsPath) {
        Write-Host "  cli.js:      $cliJsPath"
    }
    elseif ($canPatch) {
        Write-ColorLine "  cli.js:      Khong tim thay" $Colors.Red
    }
    else {
        Write-Host "  cli.js:      N/A (binary install)"
    }

    try {
        $version = & claude --version 2>$null | Select-Object -First 1
        Write-Host "  Version:     $version"
    }
    catch {
        Write-Host "  Version:     Khong xac dinh"
    }

    Write-Host ""

    return @{
        Installed = $true
        CliJs     = $cliJsPath
        Type      = $installType
        CanPatch  = $canPatch
        Path      = $claudePath
    }
}

function Get-PatchStatus {
    param([string]$CliJsPath)

    Write-ColorLine "[PATCH STATUS]" $Colors.Yellow

    if (-not $CliJsPath -or -not (Test-Path $CliJsPath)) {
        Write-ColorLine "  Patched:     N/A (khong tim thay cli.js)" $Colors.Yellow
        Write-Host ""
        return
    }

    $content = Get-Content $CliJsPath -Raw -ErrorAction SilentlyContinue
    $isPatched = $content -match "PHTV Vietnamese IME fix"

    if ($isPatched) {
        Write-ColorText "  Patched:     " $Colors.White
        Write-ColorLine "OK Da patch" $Colors.Green
    }
    else {
        Write-ColorText "  Patched:     " $Colors.White
        Write-ColorLine "X Chua patch" $Colors.Red

        $hasBugCode = ($content -match 'backspace\(\)') -and ($content -match '\\x7f|"\x7f"')
        if ($hasBugCode) {
            Write-ColorLine "  Bug code:    Co ton tai - Can patch!" $Colors.Yellow
        }
        else {
            Write-ColorLine "  Bug code:    Khong tim thay - Co the da fix boi Anthropic" $Colors.Blue
        }
    }

    $cliDir = Split-Path $CliJsPath -Parent
    $backups = Get-ChildItem $cliDir -Filter "cli.js.backup-*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

    if ($backups) {
        Write-Host "  Backup:      $($backups.Count) file(s)"
    }
    else {
        Write-Host "  Backup:      Khong co"
    }

    Write-Host ""
}

function Write-Recommendation {
    param([hashtable]$ClaudeInfo)

    Write-ColorLine "[RECOMMENDATION]" $Colors.Yellow

    if (-not $ClaudeInfo.Installed) {
        Write-ColorLine "  ! Cai dat khong thanh cong." $Colors.Red
        Write-Host "  Vui long khoi dong lai PowerShell va chay lai script."
        Write-Host ""
        return
    }

    if (-not $ClaudeInfo.CanPatch) {
        Write-ColorLine "  ! Claude Code duoc cai bang binary, khong the patch." $Colors.Red
        Write-Host ""
        Write-Host "  De patch, can cai lai bang npm:"
        Write-Host "  1. Go ban binary hien tai"
        Write-Host "  2. npm install -g @anthropic-ai/claude-code"
        Write-Host "  3. Chay: .\patch-claude-code-vn-windows.ps1"
        Write-Host ""
        return
    }

    if (-not $ClaudeInfo.CliJs) {
        Write-ColorLine "  ! Khong tim thay cli.js" $Colors.Red
        Write-Host "  Thu cai lai: npm install -g @anthropic-ai/claude-code"
        Write-Host ""
        return
    }

    $content = Get-Content $ClaudeInfo.CliJs -Raw -ErrorAction SilentlyContinue
    $isPatched = $content -match "PHTV Vietnamese IME fix"

    if ($isPatched) {
        Write-ColorLine "  OK Da patch! Khong can lam gi them." $Colors.Green
    }
    else {
        Write-Host "  -> Chay de patch:"
        Write-ColorLine "     .\patch-claude-code-vn-windows.ps1" $Colors.Green
    }

    Write-Host ""
}

# Main
function Main {
    Write-Header
    Get-SystemInfo

    # Check and install Node.js
    $hasNode = Get-NodeInfo -Install:$AutoInstall

    if (-not $hasNode) {
        Write-ColorLine "[CLAUDE CODE]" $Colors.Yellow
        Write-Host "  Khong the kiem tra - can Node.js truoc"
        Write-Host ""
        Write-ColorLine "[RECOMMENDATION]" $Colors.Yellow
        Write-Host "  1. Khoi dong lai PowerShell sau khi cai Node.js"
        Write-Host "  2. Chay lai script nay"
        Write-Host ""
        return
    }

    # Check and install Claude Code
    $claudeInfo = Get-ClaudeInfo -Install:$AutoInstall

    if ($claudeInfo.CliJs) {
        Get-PatchStatus -CliJsPath $claudeInfo.CliJs
    }
    else {
        Write-ColorLine "[PATCH STATUS]" $Colors.Yellow
        Write-Host "  N/A - cli.js khong tim thay"
        Write-Host ""
    }

    Write-Recommendation -ClaudeInfo $claudeInfo
}

Main
