#!/usr/bin/env bash
#
# Claude Code Vietnamese IME Fix - Universal Installer
# Tự động cài đặt Vietnamese IME fix cho Claude Code (macOS/Linux)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/install.sh | bash
#
# Or download and run:
#   bash install.sh
#

set -euo pipefail

# Constants
SCRIPT_VERSION="1.0.0"
WORK_DIR=".claude-vn-fix"
VENV_PATH="$WORK_DIR/venv"
PATCHER_PATH="$WORK_DIR/patcher.py"
PATCHER_URL="https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patcher.py"
MIN_PYTHON_VERSION="3.7"

# Colors (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Helper functions
print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  Claude Code Vietnamese IME Fix - Installer v${SCRIPT_VERSION}        ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_step() {
    echo -e "${BLUE}→${NC} $1" >&2
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1" >&2
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1" >&2
}

cleanup_on_error() {
    print_error "Lỗi xảy ra. Đang dọn dẹp..."
    # Rollback logic will be added later
    exit 1
}

trap cleanup_on_error ERR

# Task 2.1: Python 3.7+ dependency check
check_python() {
    print_step "Kiểm tra Python..."

    local python_cmd=""
    local python_version=""

    # Try python3 first, then python
    for cmd in python3 python; do
        if command -v "$cmd" &> /dev/null; then
            python_version=$("$cmd" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            if [ -n "$python_version" ]; then
                # Check if version >= MIN_PYTHON_VERSION
                local major minor
                major=$(echo "$python_version" | cut -d. -f1)
                minor=$(echo "$python_version" | cut -d. -f2)

                if [ "$major" -gt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -ge 7 ]); then
                    python_cmd="$cmd"
                    break
                fi
            fi
        fi
    done

    if [ -z "$python_cmd" ]; then
        print_error "Không tìm thấy Python ${MIN_PYTHON_VERSION}+"
        echo ""
        echo "Để cài đặt Python:"
        echo ""

        # Detect OS and provide appropriate instructions
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  macOS:   brew install python3"
            echo "           hoặc tải từ: https://python.org/downloads"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt &> /dev/null; then
                echo "  Ubuntu/Debian:   sudo apt update && sudo apt install python3 python3-venv"
            elif command -v dnf &> /dev/null; then
                echo "  Fedora/RHEL:     sudo dnf install python3"
            elif command -v pacman &> /dev/null; then
                echo "  Arch:            sudo pacman -S python"
            else
                echo "  Linux:           Sử dụng package manager của distro để cài python3"
            fi
        fi
        echo ""
        echo "Sau khi cài đặt, chạy lại lệnh này."
        exit 1
    fi

    print_success "Python $python_version tìm thấy ($python_cmd)"
    echo "$python_cmd"
}

# Task 2.2: Python venv creation
create_venv() {
    local python_cmd="$1"

    print_step "Thiết lập môi trường Python..."

    # Create work directory if not exists
    if [ ! -d "$WORK_DIR" ]; then
        mkdir -p "$WORK_DIR"
        print_success "Đã tạo thư mục: $WORK_DIR"
    fi

    # Create venv if not exists
    if [ ! -d "$VENV_PATH" ]; then
        print_success "Đang tạo Python virtual environment..."
        "$python_cmd" -m venv "$VENV_PATH"
        print_success "Đã tạo venv tại: $VENV_PATH"
    else
        print_success "Venv đã tồn tại: $VENV_PATH"
    fi
}

# Task 2.3: Venv reuse logic
check_venv_valid() {
    print_step "Kiểm tra virtual environment..."

    local python_in_venv=""

    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        python_in_venv="$VENV_PATH/Scripts/python"
    else
        python_in_venv="$VENV_PATH/bin/python"
    fi

    if [ -f "$python_in_venv" ]; then
        # Test if venv python works
        if "$python_in_venv" --version &> /dev/null; then
            print_success "Virtual environment hợp lệ"
            echo "$python_in_venv"
            return 0
        else
            print_warning "Virtual environment bị hỏng, đang tạo lại..."
            rm -rf "$VENV_PATH"
            return 1
        fi
    else
        return 1
    fi
}

# Task 2.4: OS detection
detect_os() {
    print_step "Nhận diện hệ điều hành..."

    local os_name=""
    local arch=""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_name="macOS"
        arch=$(uname -m)
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_name="Linux"
        arch=$(uname -m)
    else
        print_error "Hệ điều hành không được hỗ trợ: $OSTYPE"
        exit 1
    fi

    print_success "OS: $os_name ($arch)"
    echo "$os_name"
}

# Task 2.5: Claude Code detection
detect_claude_code() {
    print_step "Tìm kiếm Claude Code..."

    local claude_path=""
    local claude_type=""

    # Try npm installation first
    local npm_paths=(
        "$HOME/.nvm/versions/node/*/lib/node_modules/@anthropic/claude-code/dist/cli/cli.js"
        "/usr/local/lib/node_modules/@anthropic/claude-code/dist/cli/cli.js"
        "/opt/homebrew/lib/node_modules/@anthropic/claude-code/dist/cli/cli.js"
        "$HOME/.npm-global/lib/node_modules/@anthropic/claude-code/dist/cli/cli.js"
    )

    for pattern in "${npm_paths[@]}"; do
        # Use bash glob expansion
        for path in $pattern; do
            if [ -f "$path" ]; then
                claude_path="$path"
                claude_type="npm"
                break 2
            fi
        done
    done

    # Try binary installation if npm not found
    if [ -z "$claude_path" ]; then
        local binary_paths=(
            "$HOME/.local/bin/claude"
            "/usr/local/bin/claude"
            "/opt/homebrew/bin/claude"
            "$HOME/bin/claude"
        )

        for path in "${binary_paths[@]}"; do
            if [ -f "$path" ] && [ -x "$path" ]; then
                # Check if it's a Mach-O binary or ELF binary
                if file "$path" | grep -qE "(Mach-O|ELF)"; then
                    claude_path="$path"
                    claude_type="binary"
                    break
                fi
            fi
        done
    fi

    if [ -z "$claude_path" ]; then
        print_error "Không tìm thấy Claude Code"
        echo ""
        echo "Vui lòng cài đặt Claude Code trước:"
        echo "  npm:    npm install -g @anthropic/claude-code"
        echo "  binary: Tải từ https://claude.ai/download"
        echo ""
        exit 1
    fi

    # Get version if possible
    local version="unknown"
    if [ "$claude_type" = "npm" ]; then
        # Try to extract version from package.json
        local pkg_json=$(dirname "$(dirname "$(dirname "$claude_path")")")/package.json
        if [ -f "$pkg_json" ]; then
            version=$(grep '"version"' "$pkg_json" | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        fi
    fi

    print_success "Tìm thấy: $claude_type"
    print_success "Đường dẫn: $claude_path"
    if [ "$version" != "unknown" ]; then
        print_success "Phiên bản: $version"
    fi

    echo "$claude_type|$claude_path"
}

# Task 2.6: patcher.py download/update
download_patcher() {
    print_step "Kiểm tra patcher.py..."

    if [ -f "$PATCHER_PATH" ]; then
        print_success "patcher.py đã tồn tại"
        # TODO: Check for updates from GitHub
        # For now, skip update check
        return 0
    fi

    # Try to download from GitHub
    print_success "Đang tải patcher.py từ GitHub..."

    local download_success=0

    if command -v curl &> /dev/null; then
        if curl -fsSL "$PATCHER_URL" -o "$PATCHER_PATH" 2>/dev/null; then
            download_success=1
        fi
    elif command -v wget &> /dev/null; then
        if wget -q "$PATCHER_URL" -O "$PATCHER_PATH" 2>/dev/null; then
            download_success=1
        fi
    fi

    if [ $download_success -eq 1 ]; then
        print_success "Đã tải patcher.py"
        return 0
    fi

    # Fallback: check if patcher.py exists in current directory
    if [ -f "patcher.py" ]; then
        print_warning "Không thể tải từ GitHub, sử dụng file local"
        cp "patcher.py" "$PATCHER_PATH"
        print_success "Đã copy patcher.py từ thư mục hiện tại"
        return 0
    fi

    print_error "Không thể tải patcher.py từ GitHub hoặc tìm thấy file local"
    echo ""
    echo "Vui lòng:"
    echo "  1. Kiểm tra kết nối mạng"
    echo "  2. Hoặc tải patcher.py thủ công từ:"
    echo "     https://github.com/manhit96/claude-code-vietnamese-fix"
    echo "  3. Đặt file patcher.py trong thư mục hiện tại và chạy lại"
    echo ""
    exit 1
}

# Task 2.7: User confirmation flow
confirm_installation() {
    local claude_type="$1"
    local claude_path="$2"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  THÔNG TIN CÀI ĐẶT"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  • Loại cài đặt: $claude_type"
    echo "  • Đường dẫn:    $claude_path"
    echo "  • Phương pháp:  Dynamic pattern matching"
    echo "  • Backup:       Tự động tạo file .backup"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Read from /dev/tty to work with piped input
    read -p "Tiếp tục cài đặt? (y/N): " -n 1 -r choice < /dev/tty
    echo ""

    if [[ ! $choice =~ ^[Yy]$ ]]; then
        echo ""
        print_warning "Đã hủy cài đặt"
        exit 0
    fi
}

# Task 2.8: Execute patcher
run_patcher() {
    local python_venv="$1"
    local claude_type="$2"
    local claude_path="$3"

    print_step "Áp dụng Vietnamese IME fix..."

    # Run patcher.py
    if "$python_venv" "$PATCHER_PATH" patch --type "$claude_type" --path "$claude_path"; then
        echo ""
        print_success "Đã cài đặt thành công!"
        return 0
    else
        echo ""
        print_error "Cài đặt thất bại"
        return 1
    fi
}

# Task 2.9: Error handling + rollback (integrated into run_patcher)
# Task 2.10: Manual testing prompt
prompt_manual_test() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ⚠️  CẦN TEST THỦ CÔNG"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Vui lòng test gõ tiếng Việt ngay:"
    echo ""
    echo "  1. Mở terminal mới"
    echo "  2. Chạy: claude"
    echo "  3. Gõ tiếng Việt với bộ gõ của bạn (OpenKey, EVKey, v.v.)"
    echo "  4. Thử gõ: \"Xin chào, tôi là Claude\""
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    read -p "Gõ tiếng Việt đã hoạt động chưa? (y/N): " -n 1 -r test_result < /dev/tty
    echo ""
    echo ""

    if [[ $test_result =~ ^[Yy]$ ]]; then
        echo ""
        print_success "Vietnamese IME fix hoạt động tốt!"
        echo ""
        echo "Nếu gặp vấn đề sau này:"
        echo "  • Khôi phục: cd \"$PWD\" && $VENV_PATH/bin/python $PATCHER_PATH restore --path \"$1\""
        echo "  • Báo lỗi:   https://github.com/manhit96/claude-code-vietnamese-fix/issues"
        echo ""
    else
        echo ""
        print_warning "Gõ tiếng Việt vẫn chưa hoạt động"
        echo ""
        print_step "Đang rollback patch..."

        if "$2" "$PATCHER_PATH" restore --path "$1"; then
            print_success "Đã khôi phục từ backup"
        fi

        print_step "Đang tạo báo cáo diagnostic..."
        local diagnostic_file="diagnostic-$(date +%Y%m%d-%H%M%S).txt"

        if "$2" "$PATCHER_PATH" diagnostic --path "$1" --output "$diagnostic_file"; then
            print_success "Đã lưu: $diagnostic_file"
        fi

        echo ""
        echo "Vui lòng báo lỗi tại:"
        echo "  https://github.com/manhit96/claude-code-vietnamese-fix/issues/new"
        echo ""
        echo "Đính kèm file $diagnostic_file khi báo lỗi."
        echo ""
        exit 1
    fi
}

# Main installation flow
main() {
    print_header

    # Step 1: Check Python
    python_cmd=$(check_python)

    # Step 2: Create venv
    create_venv "$python_cmd"

    # Step 3: Check venv validity
    python_venv=$(check_venv_valid)
    if [ -z "$python_venv" ]; then
        create_venv "$python_cmd"
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
            python_venv="$VENV_PATH/Scripts/python"
        else
            python_venv="$VENV_PATH/bin/python"
        fi
    fi

    # Step 4: Detect OS
    os_name=$(detect_os)

    # Step 5: Find Claude Code
    detection_result=$(detect_claude_code)
    claude_type=$(echo "$detection_result" | cut -d'|' -f1)
    claude_path=$(echo "$detection_result" | cut -d'|' -f2)

    # Step 6: Download patcher
    download_patcher

    # Step 7: Confirm with user
    confirm_installation "$claude_type" "$claude_path"

    # Step 8: Run patcher
    if run_patcher "$python_venv" "$claude_type" "$claude_path"; then
        # Step 9: Manual testing prompt
        prompt_manual_test "$claude_path" "$python_venv"
    else
        print_error "Vui lòng kiểm tra lỗi ở trên"
        exit 1
    fi
}

# Run main function only if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
