#!/bin/bash
#
# Claude Code Vietnamese IME Fix - Diagnostic Tool (macOS)
# Thu thap thong tin moi truong de debug loi go tieng Viet.
#
# Usage:
#   ./diagnostic-macos.sh              # Run diagnostic
#   ./diagnostic-macos.sh --issue      # Open GitHub to create issue
#
# https://github.com/manhit96/claude-code-vietnamese-fix

set -e

REPO_URL="https://github.com/manhit96/claude-code-vietnamese-fix"
DIAGNOSTIC_OUTPUT=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

add_line() {
    DIAGNOSTIC_OUTPUT+="$1"$'\n'
    echo "$1"
}

print_header() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  Claude Code Vietnamese IME Fix - Diagnostic (macOS)       ${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
}

get_system_info() {
    add_line "[SYSTEM INFO]"

    # macOS version
    local macos_version=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
    local macos_build=$(sw_vers -buildVersion 2>/dev/null || echo "Unknown")
    add_line "  macOS: $macos_version ($macos_build)"

    # Architecture
    local arch=$(uname -m)
    add_line "  Architecture: $arch"

    # Shell
    add_line "  Shell: $SHELL"

    add_line ""
}

get_node_info() {
    add_line "[NODE.JS/NPM]"

    if command -v node &> /dev/null; then
        local node_version=$(node --version 2>/dev/null)
        local node_path=$(which node)
        add_line "  Node.js: $node_version"
        add_line "  Path: $node_path"

        if command -v npm &> /dev/null; then
            local npm_version=$(npm --version 2>/dev/null)
            add_line "  npm: $npm_version"

            local npm_root=$(npm root -g 2>/dev/null)
            if [ -n "$npm_root" ]; then
                add_line "  npm global: $npm_root"
            fi
        else
            add_line "  npm: NOT FOUND"
        fi

        # Detect install method
        local install_method="Unknown"
        case "$node_path" in
            */nvm/*) install_method="nvm" ;;
            */fnm/*) install_method="fnm" ;;
            */homebrew/*|*/Homebrew/*) install_method="homebrew" ;;
            */volta/*) install_method="volta" ;;
            /usr/local/*) install_method="Official installer or homebrew" ;;
        esac
        add_line "  Install via: $install_method"
    else
        add_line "  Node.js: NOT FOUND"
    fi

    add_line ""
}

find_claude_cli_js() {
    local claude_path="$1"

    # Method 1: npm root -g
    if command -v npm &> /dev/null; then
        local npm_root=$(npm root -g 2>/dev/null)
        if [ -n "$npm_root" ]; then
            local cli_path="$npm_root/@anthropic-ai/claude-code/cli.js"
            if [ -f "$cli_path" ]; then
                echo "$cli_path"
                return
            fi
        fi
    fi

    # Method 2: Common paths
    local common_paths=(
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "$HOME/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        "$HOME/.fnm/node-versions/*/installation/lib/node_modules/@anthropic-ai/claude-code/cli.js"
    )

    for path_pattern in "${common_paths[@]}"; do
        for path in $path_pattern; do
            if [ -f "$path" ]; then
                echo "$path"
                return
            fi
        done
    done

    echo ""
}

get_claude_info() {
    add_line "[CLAUDE CODE]"

    if command -v claude &> /dev/null; then
        local claude_path=$(which claude)
        add_line "  Status: Installed"
        add_line "  Path: $claude_path"

        # Detect install type
        local install_type="unknown"
        local can_patch="false"

        local file_type=$(file "$claude_path" 2>/dev/null)
        if echo "$file_type" | grep -q "Mach-O"; then
            install_type="binary"
            can_patch="false (binary)"
        elif echo "$file_type" | grep -q "script\|text"; then
            install_type="npm"
            can_patch="true"
        fi

        add_line "  Type: $install_type"
        add_line "  Can patch: $can_patch"

        CLI_JS_PATH=$(find_claude_cli_js "$claude_path")
        if [ -n "$CLI_JS_PATH" ]; then
            add_line "  cli.js: $CLI_JS_PATH"
        else
            add_line "  cli.js: NOT FOUND"
        fi

        local version=$(claude --version 2>/dev/null | head -1)
        add_line "  Version: $version"
    else
        add_line "  Status: NOT FOUND"
        CLI_JS_PATH=""
    fi

    add_line ""
}

get_patch_status() {
    add_line "[PATCH STATUS]"

    if [ -z "$CLI_JS_PATH" ] || [ ! -f "$CLI_JS_PATH" ]; then
        add_line "  Status: N/A (cli.js not found)"
        add_line ""
        return
    fi

    if grep -q "PHTV Vietnamese IME fix" "$CLI_JS_PATH" 2>/dev/null; then
        add_line "  Status: PATCHED"
    else
        add_line "  Status: NOT PATCHED"

        # Check for bug code
        if grep -q 'backspace()' "$CLI_JS_PATH" 2>/dev/null && grep -q '\\x7f\|"\x7f"' "$CLI_JS_PATH" 2>/dev/null; then
            add_line "  Bug code: EXISTS (needs patch)"
        else
            add_line "  Bug code: NOT FOUND (may be fixed by Anthropic)"
        fi
    fi

    # Check backups
    local cli_dir=$(dirname "$CLI_JS_PATH")
    local backup_count=$(ls -1 "$cli_dir"/cli.js.backup-* 2>/dev/null | wc -l | tr -d ' ')
    add_line "  Backups: $backup_count file(s)"

    # Check cli.js size
    local file_size=$(ls -lh "$CLI_JS_PATH" 2>/dev/null | awk '{print $5}')
    add_line "  cli.js size: $file_size"

    add_line ""
}

get_ime_info() {
    add_line "[IME INFO]"

    # Get current input source
    local current_input=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null | grep "KeyboardLayout Name" | head -1 | sed 's/.*= "\(.*\)";/\1/')
    if [ -n "$current_input" ]; then
        add_line "  Current input: $current_input"
    fi

    # Check for Vietnamese IME apps
    local ime_apps=("OpenKey" "EVKey" "GoTiengViet" "Unikey")
    for app in "${ime_apps[@]}"; do
        if [ -d "/Applications/$app.app" ] || [ -d "$HOME/Applications/$app.app" ]; then
            add_line "  Found: $app"
        fi
    done

    # Check running IME processes
    local running_ime=$(ps aux 2>/dev/null | grep -iE "openkey|evkey|gotiengviet|unikey" | grep -v grep | awk '{print $11}' | xargs -I {} basename {} 2>/dev/null | sort -u)
    if [ -n "$running_ime" ]; then
        add_line "  Running: $running_ime"
    fi

    add_line ""
}

create_github_issue() {
    # Get version for title prefix
    local claude_version="Unknown"
    if command -v claude &> /dev/null; then
        local ver=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        if [ -n "$ver" ]; then
            claude_version="v$ver"
        fi
    fi

    local issue_title="[macOS][$claude_version] Vietnamese IME issue"

    local body="## Environment

\`\`\`
$DIAGNOSTIC_OUTPUT
\`\`\`

## Problem Description

<!-- Describe the issue you're experiencing -->

## Steps to Reproduce

1.
2.
3.

## Expected Behavior

<!-- What should happen -->

## Actual Behavior

<!-- What actually happens -->"

    # URL encode (basic)
    local encoded_body=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$body'''))" 2>/dev/null || echo "")
    local encoded_title=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$issue_title'))" 2>/dev/null || echo "")

    if [ -n "$encoded_body" ]; then
        local issue_url="$REPO_URL/issues/new?title=$encoded_title&body=$encoded_body"
        echo ""
        echo -e "${YELLOW}[CREATE GITHUB ISSUE]${NC}"
        echo "  Opening browser to create issue..."
        echo ""
        open "$issue_url"
    else
        echo ""
        echo -e "${YELLOW}[CREATE GITHUB ISSUE]${NC}"
        echo "  Could not encode URL. Please copy the output above manually."
        echo "  Go to: $REPO_URL/issues/new"
        echo ""
    fi
}

show_summary() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  SUMMARY${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
    echo "  Copy the output above and paste it when creating an issue at:"
    echo -e "  ${GREEN}$REPO_URL/issues${NC}"
    echo ""
    echo "  Or run with --issue to auto-open GitHub:"
    echo -e "  ${YELLOW}./diagnostic-macos.sh --issue${NC}"
    echo ""
}

# Main
main() {
    local create_issue=false

    if [ "$1" = "--issue" ] || [ "$1" = "-i" ]; then
        create_issue=true
    fi

    print_header
    get_system_info
    get_node_info
    get_claude_info
    get_patch_status
    get_ime_info

    if [ "$create_issue" = true ]; then
        create_github_issue
    else
        show_summary
    fi
}

main "$@"
