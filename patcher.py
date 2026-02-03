#!/usr/bin/env python3
"""
Claude Code Vietnamese IME Fix

Fixes Vietnamese input bug in Claude Code CLI (npm) by patching
the backspace handling logic to also insert replacement text.

Usage:
  python3 patcher.py              Auto-detect and fix
  python3 patcher.py --restore    Restore from backup
  python3 patcher.py --path FILE  Fix specific file

Repository: https://github.com/manhit96/claude-code-vietnamese-fix
License: MIT
"""

import os
import re
import sys
import shutil
import platform
import subprocess
from pathlib import Path
from datetime import datetime

PATCH_MARKER = "/* Vietnamese IME fix */"
DEL_CHAR = chr(127)  # 0x7F - character used by Vietnamese IME for backspace


def find_cli_js():
    """Auto-detect Claude Code npm cli.js location."""
    home = Path.home()
    is_windows = platform.system() == 'Windows'

    if is_windows:
        search_dirs = [
            Path(os.environ.get('LOCALAPPDATA', '')) / 'npm-cache' / '_npx',
            Path(os.environ.get('APPDATA', '')) / 'npm' / 'node_modules',
        ]
    else:
        search_dirs = [
            home / '.npm' / '_npx',
            home / '.nvm' / 'versions' / 'node',
            Path('/usr/local/lib/node_modules'),
            Path('/opt/homebrew/lib/node_modules'),
        ]

    for d in search_dirs:
        if d.exists():
            for cli_js in d.rglob('*/@anthropic-ai/claude-code/cli.js'):
                return str(cli_js)

    raise FileNotFoundError(
        "Không tìm thấy Claude Code npm.\n"
        "Cài đặt trước: npm install -g @anthropic-ai/claude-code"
    )


def find_bug_block(content):
    """Find the if-block containing the Vietnamese IME bug pattern."""
    pattern = f'.includes("{DEL_CHAR}")'
    idx = content.find(pattern)

    if idx == -1:
        raise RuntimeError(
            'Không tìm thấy bug pattern .includes("\\x7f").\n'
            "Claude Code có thể đã được Anthropic fix."
        )

    # Find the containing if(
    block_start = content.rfind('if(', max(0, idx - 150), idx)
    if block_start == -1:
        raise RuntimeError("Không tìm thấy block if chứa pattern")

    # Find matching closing brace
    depth = 0
    block_end = idx
    for i, c in enumerate(content[block_start:block_start + 800]):
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                block_end = block_start + i + 1
                break

    if depth != 0:
        raise RuntimeError("Không tìm thấy closing brace của block if")

    return block_start, block_end, content[block_start:block_end]


def extract_variables(block):
    """Extract dynamic variable names from the bug block."""
    # Normalize DEL char for regex matching
    normalized = block.replace(DEL_CHAR, '\\x7f')

    # Match: let COUNT=(INPUT.match(/\x7f/g)||[]).length,STATE=CURSTATE;
    m = re.search(
        r'let ([\w$]+)=\(\w+\.match\(/\\x7f/g\)\|\|\[\]\)\.length[,;]([\w$]+)=([\w$]+)[;,]',
        normalized
    )
    if not m:
        raise RuntimeError("Không trích xuất được biến count/state")

    state, cur_state = m.group(2), m.group(3)

    # Match: UPDATETEXT(STATE.text);UPDATEOFFSET(STATE.offset)
    m2 = re.search(
        rf'([\w$]+)\({re.escape(state)}\.text\);([\w$]+)\({re.escape(state)}\.offset\)',
        block
    )
    if not m2:
        raise RuntimeError("Không trích xuất được update functions")

    # Match: INPUT.includes("
    m3 = re.search(r'([\w$]+)\.includes\("', block)
    if not m3:
        raise RuntimeError("Không trích xuất được input variable")

    return {
        'input': m3.group(1),
        'state': state,
        'cur_state': cur_state,
        'update_text': m2.group(1),
        'update_offset': m2.group(2),
    }


def generate_fix(v):
    """Generate the fix code that does backspace + insert replacement text."""
    return (
        f'{PATCH_MARKER}'
        f'if({v["input"]}.includes("\\x7f")){{'
        f'let _n=({v["input"]}.match(/\\x7f/g)||[]).length,'
        f'_vn={v["input"]}.replace(/\\x7f/g,""),'
        f'{v["state"]}={v["cur_state"]};'
        f'for(let _i=0;_i<_n;_i++){v["state"]}={v["state"]}.backspace();'
        f'for(const _c of _vn){v["state"]}={v["state"]}.insert(_c);'
        f'if(!{v["cur_state"]}.equals({v["state"]})){{'
        f'if({v["cur_state"]}.text!=={v["state"]}.text)'
        f'{v["update_text"]}({v["state"]}.text);'
        f'{v["update_offset"]}({v["state"]}.offset)'
        f'}}return;}}'
    )


def find_latest_backup(file_path):
    """Find the most recent backup file."""
    dir_path = os.path.dirname(file_path)
    filename = os.path.basename(file_path)
    backups = [
        os.path.join(dir_path, f) for f in os.listdir(dir_path or '.')
        if f.startswith(f"{filename}.backup-")
    ]
    if not backups:
        return None
    backups.sort(key=os.path.getmtime, reverse=True)
    return backups[0]


def patch(file_path):
    """Apply Vietnamese IME fix to cli.js."""
    print(f"-> File: {file_path}")

    if not os.path.exists(file_path):
        print(f"Lỗi: File không tồn tại: {file_path}", file=sys.stderr)
        return 1

    # Read
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Already patched?
    if PATCH_MARKER in content:
        print("Đã patch trước đó.")
        return 0

    # Backup
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = f"{file_path}.backup-{timestamp}"
    shutil.copy2(file_path, backup_path)
    print(f"   Backup: {backup_path}")

    try:
        # Find bug block
        block_start, block_end, block = find_bug_block(content)

        # Extract variables
        variables = extract_variables(block)
        print(f"   Vars: input={variables['input']}, state={variables['state']}, cur={variables['cur_state']}")

        # Generate fix and replace
        fix_code = generate_fix(variables)
        patched = content[:block_start] + fix_code + content[block_end:]

        # Write
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(patched)

        # Verify
        with open(file_path, 'r', encoding='utf-8') as f:
            if PATCH_MARKER not in f.read():
                raise RuntimeError("Verify failed: patch marker not found after write")

        print("\n   Patch thành công! Khởi động lại Claude Code.\n")
        return 0

    except Exception as e:
        print(f"\nLỗi: {e}", file=sys.stderr)
        print("Báo lỗi tại: https://github.com/manhit96/claude-code-vietnamese-fix/issues", file=sys.stderr)
        # Rollback
        if os.path.exists(backup_path):
            shutil.copy2(backup_path, file_path)
            os.remove(backup_path)
            print("Đã rollback về bản gốc.", file=sys.stderr)
        return 1


def restore(file_path):
    """Restore file from latest backup."""
    backup = find_latest_backup(file_path)
    if not backup:
        print(f"Không tìm thấy backup cho {file_path}", file=sys.stderr)
        return 1

    shutil.copy2(backup, file_path)
    print(f"Đã khôi phục từ: {backup}")
    print("Khởi động lại Claude Code.")
    return 0


def show_help():
    """Hiển thị hướng dẫn sử dụng."""
    print("Claude Code Vietnamese IME Fix")
    print("")
    print("Sử dụng:")
    print("  python3 patcher.py              Tự động phát hiện và fix")
    print("  python3 patcher.py --restore    Khôi phục từ backup")
    print("  python3 patcher.py --path FILE  Fix file cụ thể")
    print("  python3 patcher.py --help       Hiển thị hướng dẫn")
    print("")
    print("https://github.com/manhit96/claude-code-vietnamese-fix")


def main():
    args = sys.argv[1:]

    if '--help' in args or '-h' in args:
        show_help()
        return 0

    # Parse --restore flag
    if '--restore' in args:
        args.remove('--restore')
        # Get path from --path or auto-detect
        file_path = None
        if '--path' in args:
            idx = args.index('--path')
            file_path = args[idx + 1]
        else:
            file_path = find_cli_js()
        return restore(file_path)

    # Get path from --path or auto-detect
    file_path = None
    if '--path' in args:
        idx = args.index('--path')
        file_path = args[idx + 1]
    else:
        file_path = find_cli_js()

    return patch(file_path)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except FileNotFoundError as e:
        print(f"Lỗi: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Lỗi: {e}", file=sys.stderr)
        sys.exit(1)
