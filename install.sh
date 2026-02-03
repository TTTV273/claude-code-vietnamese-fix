#!/usr/bin/env bash
#
# Claude Code Vietnamese IME Fix - Installer
# Clone repo và tự động chạy fix
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/install.sh | bash
#

set -euo pipefail

REPO_URL="https://github.com/manhit96/claude-code-vietnamese-fix.git"
INSTALL_DIR="$HOME/.claude-vn-fix"

echo ""
echo "Claude Code Vietnamese IME Fix - Installer"
echo ""

# Check git
if ! command -v git &> /dev/null; then
    echo "[ERROR] git không tìm thấy"
    echo "Cài đặt: https://git-scm.com/downloads"
    exit 1
fi

# Check python
PYTHON_CMD=""
for cmd in python3 python; do
    if command -v "$cmd" &> /dev/null; then
        PYTHON_CMD="$cmd"
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "[ERROR] Python không tìm thấy"
    echo "Cài đặt: https://python.org/downloads"
    exit 1
fi

# Clone or update
echo "-> Cài đặt vào $INSTALL_DIR..."
if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR"
    git pull origin main 2>/dev/null || true
else
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi
echo "   Done"

# Run auto patch
echo ""
cd "$INSTALL_DIR"
"$PYTHON_CMD" patcher.py --auto

echo ""
echo "================================================"
echo "Hoàn tất!"
echo "================================================"
echo ""
echo "Commands:"
echo "  Fix:     $PYTHON_CMD $INSTALL_DIR/patcher.py"
echo "  Restore: $PYTHON_CMD $INSTALL_DIR/patcher.py --restore"
echo "  Update:  cd $INSTALL_DIR && git pull"
echo ""
