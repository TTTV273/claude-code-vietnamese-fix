#!/usr/bin/env python3
"""
Claude Code Vietnamese IME Fix - Bun Binary Patcher

Fixes Vietnamese input bug in Claude Code CLI (Bun/standalone version)
by patching the binary directly.

Usage:
  python3 patcher_bun.py              Auto-detect and fix
  python3 patcher_bun.py --restore    Restore from backup
  python3 patcher_bun.py --path FILE  Fix specific binary

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

PATCH_MARKER = b"/* VN-IME-FIX */"

# Bug pattern in Bun binary (JavaScript embedded as text)
# This handles Vietnamese IME backspace+replace incorrectly - only deletes, doesn't insert
BUG_PATTERN = (
    b'if(!DT.backspace&&!DT.delete&&RT.includes("\\x7F")){'
    b'let XT=(RT.match(/\\x7f/g)||[]).length,IT=b;'
    b'for(let zT=0;zT<XT;zT++)IT=IT.deleteTokenBefore()??IT.backspace();'
    b'if(!b.equals(IT)){if(b.text!==IT.text)R(IT.text);w(IT.offset)}'
    b'WyT(),QyT();return}'
)

# Fixed code - does backspace + insert replacement text
# Optimized to be same length as bug pattern (241 bytes)
FIX_CODE = (
    b'if(!DT.backspace&&!DT.delete&&RT.includes("\\x7F")){'
    b'let n=(RT.match(/\\x7f/g)||[]).length,v=RT.replace(/\\x7f/g,""),s=b;'
    b'for(;n--;)s=s.backspace();'
    b'for(let c of v)s=s.insert(c);'
    b'if(!b.equals(s)){if(b.text!==s.text)R(s.text);w(s.offset)}'
    b'return}'
)


def find_bun_binary():
    """Auto-detect Claude Code Bun binary location."""
    home = Path.home()
    is_windows = platform.system() == 'Windows'

    if is_windows:
        candidates = [
            home / '.local' / 'bin' / 'claude.exe',
            home / 'AppData' / 'Local' / 'Programs' / 'claude' / 'claude.exe',
        ]
    else:
        candidates = [
            home / '.local' / 'bin' / 'claude',
            Path('/usr/local/bin/claude'),
            Path('/opt/homebrew/bin/claude'),
        ]

    for path in candidates:
        if path.exists() and path.is_file():
            # Verify it's a binary (not a shell script or symlink to npm)
            with open(path, 'rb') as f:
                header = f.read(4)
                # Mach-O (macOS), ELF (Linux), or MZ (Windows)
                if header[:4] in [b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe',  # Mach-O
                                   b'\x7fELF',  # ELF
                                   b'MZ\x90\x00', b'MZ\x00\x00']:  # Windows PE
                    return str(path)

    raise FileNotFoundError(
        "Không tìm thấy Claude Code binary (Bun).\n"
        "Binary thường ở ~/.local/bin/claude"
    )


def find_bug_pattern(content):
    """Find the Vietnamese IME bug pattern in binary."""
    # Try exact match first
    idx = content.find(BUG_PATTERN)
    if idx != -1:
        return idx, BUG_PATTERN

    # Try regex for variable name variations
    # The pattern structure is consistent but variable names may differ
    pattern = re.compile(
        rb'if\(!(\w+)\.backspace&&!\1\.delete&&(\w+)\.includes\("\\x7F"\)\){'
        rb'let (\w+)=\(\2\.match\(/\\x7f/g\)\|\|\[\]\)\.length,(\w+)=(\w+);'
        rb'for\(let (\w+)=0;\6<\3;\6\+\+\)\4=\4\.deleteTokenBefore\(\)\?\?\4\.backspace\(\);'
        rb'if\(!\5\.equals\(\4\)\){if\(\5\.text!==\4\.text\)(\w+)\(\4\.text\);(\w+)\(\4\.offset\)}'
        rb'(\w+)\(\),(\w+)\(\);return}'
    )

    match = pattern.search(content)
    if match:
        return match.start(), match.group(0)

    raise RuntimeError(
        'Không tìm thấy bug pattern trong binary.\n'
        'Claude Code có thể đã được Anthropic fix hoặc đây không phải Bun binary.'
    )


def generate_fix(original_pattern):
    """Generate fix code with same length as original."""
    # Extract variable names from original pattern
    pattern = re.compile(
        rb'if\(!(\w+)\.backspace&&!\1\.delete&&(\w+)\.includes\("\\x7F"\)\){'
        rb'let (\w+)=\(\2\.match\(/\\x7f/g\)\|\|\[\]\)\.length,(\w+)=(\w+);'
        rb'for\(let (\w+)=0;\6<\3;\6\+\+\)\4=\4\.deleteTokenBefore\(\)\?\?\4\.backspace\(\);'
        rb'if\(!\5\.equals\(\4\)\){if\(\5\.text!==\4\.text\)(\w+)\(\4\.text\);(\w+)\(\4\.offset\)}'
        rb'(\w+)\(\),(\w+)\(\);return}'
    )

    match = pattern.match(original_pattern)
    if not match:
        # Use default FIX_CODE for exact BUG_PATTERN match
        fix = FIX_CODE
    else:
        # Generate fix with extracted variable names
        dt, rt, _, _, state_var, _, update_text, update_offset, _, _ = match.groups()

        fix = (
            b'if(!' + dt + b'.backspace&&!' + dt + b'.delete&&' + rt + b'.includes("\\x7F")){'
            b'let n=(' + rt + b'.match(/\\x7f/g)||[]).length,v=' + rt + b'.replace(/\\x7f/g,""),s=' + state_var + b';'
            b'for(;n--;)s=s.backspace();'
            b'for(let c of v)s=s.insert(c);'
            b'if(!' + state_var + b'.equals(s)){if(' + state_var + b'.text!==s.text)' + update_text + b'(s.text);' + update_offset + b'(s.offset)}'
            b'return}'
        )

    original_len = len(original_pattern)
    fix_len = len(fix)

    if fix_len > original_len:
        raise RuntimeError(
            f"Fix code ({fix_len}) dài hơn original ({original_len}). "
            "Cần tối ưu thêm."
        )

    # Pad with spaces to match original length
    if fix_len < original_len:
        # Insert spaces before the closing }
        padding = b' ' * (original_len - fix_len)
        fix = fix[:-1] + padding + b'}'

    return fix


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


def find_all_bug_patterns(content):
    """Find all Vietnamese IME bug patterns in binary."""
    results = []

    # Find all occurrences using exact match
    start = 0
    while True:
        idx = content.find(BUG_PATTERN, start)
        if idx == -1:
            break
        results.append((idx, BUG_PATTERN))
        start = idx + len(BUG_PATTERN)

    if results:
        return results

    # Try regex for variable name variations
    pattern = re.compile(
        rb'if\(!(\w+)\.backspace&&!\1\.delete&&(\w+)\.includes\("\\x7F"\)\){'
        rb'let (\w+)=\(\2\.match\(/\\x7f/g\)\|\|\[\]\)\.length,(\w+)=(\w+);'
        rb'for\(let (\w+)=0;\6<\3;\6\+\+\)\4=\4\.deleteTokenBefore\(\)\?\?\4\.backspace\(\);'
        rb'if\(!\5\.equals\(\4\)\){if\(\5\.text!==\4\.text\)(\w+)\(\4\.text\);(\w+)\(\4\.offset\)}'
        rb'(\w+)\(\),(\w+)\(\);return}'
    )

    for match in pattern.finditer(content):
        results.append((match.start(), match.group(0)))

    if not results:
        raise RuntimeError(
            'Không tìm thấy bug pattern trong binary.\n'
            'Claude Code có thể đã được Anthropic fix hoặc đây không phải Bun binary.'
        )

    return results


def patch(file_path):
    """Apply Vietnamese IME fix to Bun binary."""
    print(f"-> File: {file_path}")

    if not os.path.exists(file_path):
        print(f"Lỗi: File không tồn tại: {file_path}", file=sys.stderr)
        return 1

    # Read binary
    with open(file_path, 'rb') as f:
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
        # Find all bug patterns
        bug_locations = find_all_bug_patterns(content)
        print(f"   Found {len(bug_locations)} bug location(s)")

        patched = content
        for i, (bug_offset, bug_pattern) in enumerate(bug_locations):
            print(f"   [{i+1}] Offset: {bug_offset}, Length: {len(bug_pattern)} bytes")

            # Generate fix
            fix_code = generate_fix(bug_pattern)

            if len(fix_code) != len(bug_pattern):
                raise RuntimeError(f"Fix code length mismatch at offset {bug_offset}")

            # Replace bug with fix (adjust offset for previous patches)
            # Since all patterns have same length, offsets don't shift
            patched = patched[:bug_offset] + fix_code + patched[bug_offset + len(bug_pattern):]

        print(f"   Patched {len(bug_locations)} location(s)")

        # Write patched binary
        with open(file_path, 'wb') as f:
            f.write(patched)

        # Make executable (on Unix)
        if platform.system() != 'Windows':
            os.chmod(file_path, 0o755)

        # Re-sign binary on macOS (required after modification)
        if platform.system() == 'Darwin':
            print("   Re-signing binary...")
            result = subprocess.run(
                ['codesign', '--force', '--sign', '-', file_path],
                capture_output=True, text=True
            )
            if result.returncode != 0:
                raise RuntimeError(f"Code signing failed: {result.stderr}")
            print("   Signed successfully.")

        # Verify
        with open(file_path, 'rb') as f:
            verify_content = f.read()
            if fix_code not in verify_content:
                raise RuntimeError("Verify failed: fix code not found after write")

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

    # Make executable (on Unix)
    if platform.system() != 'Windows':
        os.chmod(file_path, 0o755)

    print(f"Đã khôi phục từ: {backup}")
    print("Khởi động lại Claude Code.")
    return 0


def show_help():
    """Hiển thị hướng dẫn sử dụng."""
    print("Claude Code Vietnamese IME Fix - Bun Binary Patcher")
    print("")
    print("Sử dụng:")
    print("  python3 patcher_bun.py              Tự động phát hiện và fix")
    print("  python3 patcher_bun.py --restore    Khôi phục từ backup")
    print("  python3 patcher_bun.py --path FILE  Fix file cụ thể")
    print("  python3 patcher_bun.py --help       Hiển thị hướng dẫn")
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
        file_path = None
        if '--path' in args:
            idx = args.index('--path')
            file_path = args[idx + 1]
        else:
            file_path = find_bun_binary()
        return restore(file_path)

    # Get path from --path or auto-detect
    file_path = None
    if '--path' in args:
        idx = args.index('--path')
        file_path = args[idx + 1]
    else:
        file_path = find_bun_binary()

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
