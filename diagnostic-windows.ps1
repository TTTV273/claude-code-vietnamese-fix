#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code Vietnamese IME Fix - Diagnostic Tool (Windows)

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
    Write-ColorLine "  Claude Code Vietnamese IME Fix - Diagnostic (Windows)     " $Colors.Blue
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
    Add-DiagLine "[SYSTEM INFO]"

    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        Add-DiagLine "  OS: $($os.Caption) $($os.Version)"
    } else {
        Add-DiagLine "  OS: Windows (unknown version)"
    }

    Add-DiagLine "  PowerShell: $($PSVersionTable.PSVersion.ToString())"
    Add-DiagLine "  Architecture: $([Environment]::Is64BitOperatingSystem ? 'x64' : 'x86')"
    Add-DiagLine ""
}

function Get-NodeInfo {
    Add-DiagLine "[NODE.JS/NPM]"

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVersion = & node --version 2>$null
        $nodePath = $nodeCmd.Source
        Add-DiagLine "  Node.js: $nodeVersion"
        Add-DiagLine "  Path: $nodePath"

        $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
        if ($npmCmd) {
            $npmVersion = & npm --version 2>$null
            Add-DiagLine "  npm: $npmVersion"

            $npmRoot = & npm root -g 2>$null
            if ($npmRoot) {
                Add-DiagLine "  npm global: $npmRoot"
            }
        } else {
            Add-DiagLine "  npm: NOT FOUND"
        }

        # Detect install method
        $installMethod = "Unknown"
        if ($nodePath -match '\\nvm\\') { $installMethod = "nvm-windows" }
        elseif ($nodePath -match '\\fnm\\') { $installMethod = "fnm" }
        elseif ($nodePath -match '\\scoop\\') { $installMethod = "scoop" }
        elseif ($nodePath -match '\\Chocolatey\\') { $installMethod = "chocolatey" }
        elseif ($nodePath -match 'Program Files') { $installMethod = "Official installer" }
        Add-DiagLine "  Install via: $installMethod"
    } else {
        Add-DiagLine "  Node.js: NOT FOUND"
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
        $npmRoot = & npm root -g 2>$null
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
        Add-DiagLine "  Status: NOT FOUND"
        Add-DiagLine ""
        return @{ Installed = $false; CliJs = $null; CanPatch = $false }
    }

    $claudePath = $claudeCmd.Source
    Add-DiagLine "  Status: Installed"
    Add-DiagLine "  Path: $claudePath"

    # Detect install type
    $installType = "unknown"
    $canPatch = $false

    if ($claudePath -match '\.exe$') {
        $fileInfo = Get-Item $claudePath -ErrorAction SilentlyContinue
        if ($fileInfo.Length -gt 1MB) {
            $installType = "binary"
            $canPatch = $false
        } else {
            $installType = "unknown exe"
            $canPatch = $false
        }
    } elseif ($claudePath -match '\.(cmd|bat|ps1)$') {
        $installType = "npm"
        $canPatch = $true
    }

    Add-DiagLine "  Type: $installType"
    Add-DiagLine "  Can patch: $canPatch"

    $cliJsPath = Find-ClaudeCliJs -ClaudePath $claudePath

    if ($cliJsPath) {
        Add-DiagLine "  cli.js: $cliJsPath"
    } else {
        Add-DiagLine "  cli.js: NOT FOUND"
    }

    try {
        $version = & claude --version 2>$null | Select-Object -First 1
        Add-DiagLine "  Version: $version"
    } catch {
        Add-DiagLine "  Version: Unknown"
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

    Add-DiagLine "[PATCH STATUS]"

    if (-not $CliJsPath -or -not (Test-Path $CliJsPath)) {
        Add-DiagLine "  Status: N/A (cli.js not found)"
        Add-DiagLine ""
        return
    }

    $content = Get-Content $CliJsPath -Raw -ErrorAction SilentlyContinue
    $isPatched = $content -match "PHTV Vietnamese IME fix"

    if ($isPatched) {
        Add-DiagLine "  Status: PATCHED"
    } else {
        Add-DiagLine "  Status: NOT PATCHED"

        # Check for bug code
        $hasBugCode = ($content -match 'backspace\(\)') -and ($content -match '\\x7f|"\x7f"')
        if ($hasBugCode) {
            Add-DiagLine "  Bug code: EXISTS (needs patch)"
        } else {
            Add-DiagLine "  Bug code: NOT FOUND (may be fixed by Anthropic)"
        }
    }

    # Check backups
    $cliDir = Split-Path $CliJsPath -Parent
    $backups = Get-ChildItem $cliDir -Filter "cli.js.backup-*" -ErrorAction SilentlyContinue
    Add-DiagLine "  Backups: $($backups.Count) file(s)"

    # Check cli.js size
    $fileInfo = Get-Item $CliJsPath -ErrorAction SilentlyContinue
    if ($fileInfo) {
        $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        Add-DiagLine "  cli.js size: $sizeMB MB"
    }

    Add-DiagLine ""
}

function Get-IMEInfo {
    Add-DiagLine "[IME INFO]"

    # Get keyboard layouts
    $layouts = Get-WinUserLanguageList -ErrorAction SilentlyContinue
    if ($layouts) {
        foreach ($lang in $layouts) {
            Add-DiagLine "  Language: $($lang.LanguageTag)"
            foreach ($input in $lang.InputMethodTips) {
                Add-DiagLine "    Input: $input"
            }
        }
    } else {
        Add-DiagLine "  Unable to get language list"
    }

    Add-DiagLine ""
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

<!-- Describe the issue you're experiencing -->

## Steps to Reproduce

1.
2.
3.

## Expected Behavior

<!-- What should happen -->

## Actual Behavior

<!-- What actually happens -->
"@

    # URL encode the body
    $encodedBody = [System.Web.HttpUtility]::UrlEncode($body)
    $encodedTitle = [System.Web.HttpUtility]::UrlEncode($issueTitle)

    $issueUrl = "$REPO_URL/issues/new?title=$encodedTitle&body=$encodedBody"

    Write-Host ""
    Write-ColorLine "[CREATE GITHUB ISSUE]" $Colors.Yellow
    Write-Host "  Opening browser to create issue..."
    Write-Host ""

    Start-Process $issueUrl
}

function Show-Summary {
    Write-Host ""
    Write-ColorLine "============================================================" $Colors.Blue
    Write-ColorLine "  SUMMARY" $Colors.Blue
    Write-ColorLine "============================================================" $Colors.Blue
    Write-Host ""
    Write-Host "  Copy the output above and paste it when creating an issue at:"
    Write-ColorLine "  $REPO_URL/issues" $Colors.Green
    Write-Host ""
    Write-Host "  Or run with -CreateIssue to auto-open GitHub:"
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
    }

    Get-IMEInfo

    if ($CreateIssue) {
        Create-GitHubIssue
    } else {
        Show-Summary
    }
}

Main
