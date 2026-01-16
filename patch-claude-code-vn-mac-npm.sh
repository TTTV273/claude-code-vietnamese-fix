#!/bin/bash
#
# Claude Code Vietnamese IME Fix
# Fixes Vietnamese input bug in Claude Code CLI
#
# Bug: Claude Code processes DEL (0x7F) characters from Vietnamese IME
#      but returns without inserting the replacement text
#
# Repository: https://github.com/manhit96/claude-code-vietnamese-fix
# License: MIT
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Patch marker
PATCH_MARKER="Vietnamese IME fix"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Code Vietnamese IME Fix - Patch Script          ║${NC}"
echo -e "${BLUE}║     Fix lỗi gõ tiếng Việt trong Claude Code CLI            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to find Claude Code cli.js
find_cli_js() {
    local cli_path=""

    # Method 1: Use 'which claude' and resolve symlinks
    if command -v claude &> /dev/null; then
        local claude_bin=$(which claude)
        # Use realpath first (more reliable), fallback to readlink
        local resolved_path=$(realpath "$claude_bin" 2>/dev/null || readlink -f "$claude_bin" 2>/dev/null || echo "$claude_bin")

        # Check if it's a binary (Homebrew/native) or script (npm)
        # Check the original symlink target, not the resolved path
        if file "$claude_bin" | grep -q "text"; then
            # It's a script, find cli.js in same directory or parent
            local dir=$(dirname "$resolved_path")

            # Try lib path for npm global installs
            local lib_path=$(echo "$dir" | sed 's|/bin$|/lib/node_modules/@anthropic-ai/claude-code|')
            if [[ -f "$lib_path/cli.js" ]]; then
                cli_path="$lib_path/cli.js"
            elif [[ -f "$dir/cli.js" ]]; then
                cli_path="$dir/cli.js"
            elif [[ -f "$dir/../cli.js" ]]; then
                cli_path=$(cd "$dir/.." && pwd)/cli.js
            fi
        else
            echo -e "${RED}✗ Claude Code được cài bằng binary (Homebrew/native).${NC}" >&2
            echo -e "${YELLOW}  Không thể patch bản binary. Vui lòng cài lại bằng npm:${NC}" >&2
            echo "" >&2
            echo -e "  ${GREEN}# Gỡ bản cũ${NC}" >&2
            echo -e "  brew uninstall --cask claude-code  # nếu dùng Homebrew" >&2
            echo "" >&2
            echo -e "  ${GREEN}# Cài bản npm${NC}" >&2
            echo -e "  npm install -g @anthropic-ai/claude-code" >&2
            echo "" >&2
            exit 1
        fi
    fi

    # Method 2: Check common npm paths
    if [[ -z "$cli_path" ]]; then
        local npm_paths=(
            "$HOME/.nvm/versions/node/"*"/lib/node_modules/@anthropic-ai/claude-code/cli.js"
            "$HOME/.fnm/node-versions/"*"/installation/lib/node_modules/@anthropic-ai/claude-code/cli.js"
            "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
            "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        )

        for pattern in "${npm_paths[@]}"; do
            for path in $pattern; do
                if [[ -f "$path" ]]; then
                    cli_path="$path"
                    break 2
                fi
            done
        done
    fi

    echo "$cli_path"
}

# Function to check if already patched
is_patched() {
    local cli_path="$1"
    grep -q "$PATCH_MARKER" "$cli_path" 2>/dev/null
}

# Function to check Claude Code version
get_version() {
    claude --version 2>/dev/null | head -1 || echo "unknown"
}

# Function to apply patch using Python
apply_patch() {
    local cli_path="$1"
    local backup_path="${cli_path}.backup-$(date +%Y%m%d-%H%M%S)"

    echo -e "${YELLOW}→ Đang tạo backup...${NC}"
    cp "$cli_path" "$backup_path"
    echo -e "  Backup: $backup_path"

    echo -e "${YELLOW}→ Đang phân tích và áp dụng patch...${NC}"

    # Use Python for reliable patching with dynamic variable extraction
    python3 - "$cli_path" "$backup_path" << 'PYTHON_EOF'
import sys
import re

cli_path = sys.argv[1]
backup_path = sys.argv[2]

# Read file
with open(cli_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Patch marker
PATCH_MARKER = "/* Vietnamese IME fix */"

# Already patched?
if PATCH_MARKER in content:
    print("ALREADY_PATCHED")
    sys.exit(0)

# Dynamic variable extraction approach
# Find the bug block by looking for .includes("\x7f") with actual DEL character
DEL_CHAR = chr(127)  # 0x7F

# Find the includes check with DEL character
includes_pattern = f'.includes("{DEL_CHAR}")'
idx = content.find(includes_pattern)

if idx == -1:
    print("PATTERN_NOT_FOUND")
    sys.exit(1)

# Get context around the bug block
start = max(0, idx - 300)
end = min(len(content), idx + 600)
context = content[start:end]

# Find the full if block containing this pattern
block_start = content.rfind('if(', max(0, idx - 150), idx)
if block_start == -1:
    print("PATTERN_NOT_FOUND")
    sys.exit(1)

# Find matching closing brace
depth = 0
block_end = idx
for i, c in enumerate(content[block_start:block_start+800]):
    if c == '{':
        depth += 1
    elif c == '}':
        depth -= 1
        if depth == 0:
            block_end = block_start + i + 1
            break

full_block = content[block_start:block_end]

# Extract variable names dynamically using regex
# Pattern: let COUNT=(INPUT.match(/\x7f/g)||[]).length,STATE=CURSTATE;
vars_match = re.search(r'let (\w+)=\(\w+\.match\(/\\x7f/g\)\|\|\[\]\)\.length,(\w+)=(\w+);', full_block.replace(DEL_CHAR, '\\x7f'))
if not vars_match:
    print("PATTERN_NOT_FOUND")
    sys.exit(1)

count_var = vars_match.group(1)  # e.g., EA
state_var = vars_match.group(2)  # e.g., _A
cur_state_var = vars_match.group(3)  # e.g., P

# Extract update functions: UPDATETEXT(STATE.text);UPDATEOFFSET(STATE.offset)
update_match = re.search(rf'(\w+)\({state_var}\.text\);(\w+)\({state_var}\.offset\)', full_block)
if not update_match:
    print("PATTERN_NOT_FOUND")
    sys.exit(1)

update_text_func = update_match.group(1)  # e.g., Q
update_offset_func = update_match.group(2)  # e.g., j

# Extract input variable from includes check: INPUT.includes("\x7f")
input_match = re.search(r'(\w+)\.includes\("', full_block)
if not input_match:
    print("PATTERN_NOT_FOUND")
    sys.exit(1)

input_var = input_match.group(1)  # e.g., n

# Find insertion point: right after UPDATEOFFSET(STATE.offset)}
insert_pattern = rf'{update_offset_func}\({state_var}\.offset\)\}}'
insert_match = re.search(insert_pattern, full_block)
if not insert_match:
    print("PATTERN_NOT_FOUND")
    sys.exit(1)

# Calculate absolute position for insertion
relative_pos = insert_match.end()
absolute_pos = block_start + relative_pos

# Build fix code with extracted variable names
fix_code = (
    f'{PATCH_MARKER}'
    f'let _vn={input_var}.replace(/\\x7f/g,"");'
    f'if(_vn.length>0){{'
    f'for(const _c of _vn){state_var}={state_var}.insert(_c);'
    f'if(!{cur_state_var}.equals({state_var})){{'
    f'if({cur_state_var}.text!=={state_var}.text){update_text_func}({state_var}.text);'
    f'{update_offset_func}({state_var}.offset)'
    f'}}}}'
)

# Insert fix code
content = content[:absolute_pos] + fix_code + content[absolute_pos:]

# Write patched file
with open(cli_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"SUCCESS:input={input_var},state={state_var},cur={cur_state_var}")
PYTHON_EOF

    local result=$?
    local output=$(python3 - "$cli_path" << 'CHECK_EOF'
import sys
if "Vietnamese IME fix" in open(sys.argv[1], encoding='utf-8').read():
    print("PATCHED")
else:
    print("NOT_PATCHED")
CHECK_EOF
)

    if [[ "$output" == "PATCHED" ]]; then
        return 0
    else
        # Restore backup
        echo -e "${YELLOW}→ Đang khôi phục từ backup...${NC}"
        cp "$backup_path" "$cli_path"
        return 1
    fi
}

# Function to remove patch
remove_patch() {
    local cli_path="$1"

    # Find latest backup
    local latest_backup=$(ls -t "${cli_path}.backup-"* 2>/dev/null | head -1)

    if [[ -z "$latest_backup" ]]; then
        echo -e "${RED}✗ Không tìm thấy file backup.${NC}"
        echo -e "  Bạn có thể cài lại Claude Code để khôi phục:"
        echo -e "  ${GREEN}npm install -g @anthropic-ai/claude-code${NC}"
        return 1
    fi

    echo -e "${YELLOW}→ Đang khôi phục từ backup...${NC}"
    cp "$latest_backup" "$cli_path"
    rm -f "$latest_backup"
    echo -e "${GREEN}✓ Đã khôi phục Claude Code về bản gốc.${NC}"
}

# Main script
main() {
    local action="${1:-patch}"

    echo -e "${YELLOW}→ Đang tìm Claude Code...${NC}"

    CLI_PATH=$(find_cli_js)

    if [[ -z "$CLI_PATH" ]] || [[ ! -f "$CLI_PATH" ]]; then
        echo -e "${RED}✗ Không tìm thấy Claude Code.${NC}"
        echo -e "  Vui lòng cài đặt Claude Code trước:"
        echo -e "  ${GREEN}npm install -g @anthropic-ai/claude-code${NC}"
        exit 1
    fi

    echo -e "  Đường dẫn: ${BLUE}$CLI_PATH${NC}"
    echo -e "  Phiên bản: ${BLUE}$(get_version)${NC}"
    echo ""

    case "$action" in
        patch|fix|apply)
            if is_patched "$CLI_PATH"; then
                echo -e "${GREEN}✓ Claude Code đã được patch trước đó.${NC}"
                exit 0
            fi

            echo -e "${YELLOW}→ Đang áp dụng patch...${NC}"

            if apply_patch "$CLI_PATH"; then
                echo ""
                echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║  ✓ Patch thành công! Vietnamese IME fix đã được áp dụng.  ║${NC}"
                echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "Vui lòng ${YELLOW}khởi động lại Claude Code${NC} để áp dụng thay đổi."
                echo ""
            else
                echo ""
                echo -e "${RED}✗ Không thể áp dụng patch.${NC}"
                echo -e "  Code structure có thể đã thay đổi trong phiên bản mới."
                echo -e "  Vui lòng báo lỗi tại: ${BLUE}https://github.com/manhit96/claude-code-vietnamese-fix/issues${NC}"
                exit 1
            fi
            ;;

        unpatch|remove|restore)
            if ! is_patched "$CLI_PATH"; then
                echo -e "${YELLOW}Claude Code chưa được patch.${NC}"
                exit 0
            fi

            if remove_patch "$CLI_PATH"; then
                echo -e "${GREEN}✓ Đã gỡ patch thành công.${NC}"
            else
                exit 1
            fi
            ;;

        status|check)
            echo -e "${YELLOW}→ Kiểm tra trạng thái patch...${NC}"
            echo ""

            if is_patched "$CLI_PATH"; then
                echo -e "  Trạng thái: ${GREEN}✓ Đã patch${NC}"
            else
                echo -e "  Trạng thái: ${RED}✗ Chưa patch${NC}"

                # Check if buggy code exists
                if grep -q 'backspace()' "$CLI_PATH" 2>/dev/null && grep -q '\\x7f\|"\x7f"' "$CLI_PATH" 2>/dev/null; then
                    echo -e "  Bug code:   ${YELLOW}Có tồn tại${NC} - Cần patch!"
                else
                    echo -e "  Bug code:   ${BLUE}Không tìm thấy${NC} - Có thể đã được fix bởi Anthropic"
                fi
            fi
            ;;

        *)
            echo "Usage: $0 [patch|unpatch|status]"
            echo ""
            echo "Commands:"
            echo "  patch    - Áp dụng Vietnamese IME fix (default)"
            echo "  unpatch  - Gỡ bỏ patch, khôi phục bản gốc"
            echo "  status   - Kiểm tra trạng thái patch"
            exit 1
            ;;
    esac
}

main "$@"
