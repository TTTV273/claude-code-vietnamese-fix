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

# ── Legacy pattern (Claude Code < 2.1.114) ────────────────────────────────────
# The old code had an explicit but broken Vietnamese IME handler that deleted
# chars but never inserted the replacements.
BUG_PATTERN = (
    b'if(!DT.backspace&&!DT.delete&&RT.includes("\\x7F")){'
    b'let XT=(RT.match(/\\x7f/g)||[]).length,IT=b;'
    b'for(let zT=0;zT<XT;zT++)IT=IT.deleteTokenBefore()??IT.backspace();'
    b'if(!b.equals(IT)){if(b.text!==IT.text)R(IT.text);w(IT.offset)}'
    b'WyT(),QyT();return}'
)

FIX_CODE = (
    b'if(!DT.backspace&&!DT.delete&&RT.includes("\\x7F")){'
    b'let s=b;for(let c of RT)c==="\\x7f"?s=s.backspace():s=s.insert(c);'
    b'if(!b.equals(s)){if(b.text!==s.text)R(s.text);w(s.offset)}'
    b'WyT(),QyT();return}'
)

# ── New pattern (Claude Code >= 2.1.114) ─────────────────────────────────────
# The explicit IME handler was removed; the key-handler function t() now simply
# calls p.insert(ZH) without any \x7f check, so Vietnamese IME input is broken.
# Fix: replace the entire function t body with a compacted version that adds
# the \x7f check and frees space via switch-case merges.
BUG_PATTERN_NEW = (
    b'function t($H,ZH){switch($H.key){'
    b'case"escape":if(X)return;return Q(),p;'
    b'case"left":if($H.ctrl||$H.meta||$H.fn)return p.prevWord();if(T&&!$H.shift&&p.text==="")return T(),p;return p.left();'
    b'case"right":if($H.ctrl||$H.meta||$H.fn)return p.nextWord();return p.right();'
    b'case"up":if($H.shift||$H.ctrl||$H.meta)return;return e();'
    b'case"down":if($H.shift||$H.ctrl||$H.meta)return;return s();'
    b'case"backspace":if($H.superKey)return TH();if($H.meta||$H.ctrl)return HH();return p.deleteTokenBefore()??p.backspace();'
    b'case"delete":if($H.superKey)return _H();if($H.meta)return _H();return p.del();'
    b'case"home":if($H.ctrl)return;return p.startOfLine();'
    b'case"end":if($H.ctrl)return;return p.endOfLine();'
    b'case"pagedown":if(Uq()||$H.ctrl)return;return p.endOfLine();'
    b'case"pageup":if(Uq()||$H.ctrl)return;return p.startOfLine();'
    b'case"return":if($H.ctrl)return;return wH($H);'
    b'case"enter":return p.insert(`\n`);'
    b'case"tab":return}'
    b'if($H.ctrl)return jH($H.key);if($H.meta)return YH($H.key);if(ot4.has($H.key))return;if(ZH.length===0)return;if(p.isAtStart()&&lK9(ZH))return p.insert(ZH).left();return p.insert(ZH)}'
)

# Fix: compact switch cases to free ~92 bytes, use the space for the IME check.
# Semantically equivalent transformations applied to up/down, backspace, delete,
# home/end, pagedown/pageup, and the tail condition chain.
FIX_CODE_NEW = (
    b'function t($H,ZH){switch($H.key){'
    b'case"escape":if(X)return;return Q(),p;'
    b'case"left":if($H.ctrl||$H.meta||$H.fn)return p.prevWord();if(T&&!$H.shift&&p.text==="")return T(),p;return p.left();'
    b'case"right":if($H.ctrl||$H.meta||$H.fn)return p.nextWord();return p.right();'
    b'case"up":case"down":if($H.shift||$H.ctrl||$H.meta)return;return $H.key==="up"?e():s();'
    b'case"backspace":return $H.superKey?TH():$H.meta||$H.ctrl?HH():p.deleteTokenBefore()??p.backspace();'
    b'case"delete":return $H.superKey||$H.meta?_H():p.del();'
    b'case"home":case"end":if($H.ctrl)return;return p[$H.key==="home"?"startOfLine":"endOfLine"]();'
    b'case"pagedown":case"pageup":if(Uq()||$H.ctrl)return;return p[$H.key==="pagedown"?"endOfLine":"startOfLine"]();'
    b'case"return":if($H.ctrl)return;return wH($H);'
    b'case"enter":return p.insert(`\n`);'
    b'case"tab":return}'
    b'if($H.ctrl)return jH($H.key);if($H.meta)return YH($H.key);'
    b'if(ot4.has($H.key)||!ZH)return;'
    b'/* VN-IME-FIX */'
    b'if(ZH.includes("\\x7f"))return[...ZH].reduce((s,c)=>"\\x7f"==c?s.backspace():s.insert(c),p);'
    b'return p.isAtStart()&&lK9(ZH)?p.insert(ZH).left():p.insert(ZH)}'
)


# ── New pattern v3 (Claude Code >= 2.1.148) ──────────────────────────────────
# function renamed and switch now uses .name instead of .key
BUG_PATTERN_V3_RE = re.compile(
    rb'function ([\w$]+)\(([\w$]+),([\w$]+)\)\{switch\(\2\.name\)\{'
    rb'case"escape":if\(([\w$]+)\)return;return ([\w$]+)\(\),([\w$]+);'
    rb'(case"left":if\(\2\.superKey\)return \6\.startOfLine\(\);if\(\2\.ctrl\|\|\2\.meta\|\|\2\.fn\)return \6\.prevWord\(\);if\([\w$]+&&!\2\.shift&&\6\.text===""\)\{if\([\w$]+\)[\w$]+\(\);else [\w$]+\(\);return \6\}return \6\.left\(\);)'
    rb'(case"right":if\(\2\.superKey\)return \6\.endOfLine\(\);if\(\2\.ctrl\|\|\2\.meta\|\|\2\.fn\)return \6\.nextWord\(\);return \6\.right\(\);)'
    rb'case"up":if\(\2\.shift\|\|\2\.ctrl\|\|\2\.meta\)return;return ([\w$]+)\(\);'
    rb'case"down":if\(\2\.shift\|\|\2\.ctrl\|\|\2\.meta\)return;return ([\w$]+)\(\);'
    rb'case"backspace":if\(\2\.superKey\)return ([\w$]+)\(\);if\(\2\.meta\|\|\2\.ctrl\)return ([\w$]+)\(\);return \6\.deleteTokenBefore\(\)\?\?\6\.backspace\(\);'
    rb'case"delete":if\(\2\.superKey\)return ([\w$]+)\(\);if\(\2\.meta\)return \13\(\);return \6\.del\(\);'
    rb'case"home":if\(\2\.ctrl\)return;return \6\.startOfLine\(\);case"end":if\(\2\.ctrl\)return;return \6\.endOfLine\(\);'
    rb'case"pagedown":if\(([\w$]+)\(\)\|\|\2\.ctrl\)return;return \6\.endOfLine\(\);case"pageup":if\(\14\(\)\|\|\2\.ctrl\)return;return \6\.startOfLine\(\);'
    rb'case"return":if\(\2\.ctrl\)return;return ([\w$]+)\(\2\);'
    rb'case"enter":return \6\.insert\(`\n`\);case"tab":return\}'
    rb'if\(\2\.ctrl\)return ([\w$]+)\(\2\.key\);if\(\2\.meta\)return ([\w$]+)\(\2\.key\);'
    rb'if\(([\w$]+)\.has\(\2\.name\)\)return;if\(\3\.length===0\)return;'
    rb'if\(\6\.isAtStart\(\)&&([\w$]+)\(\3\)\)return \6\.insert\(\3\)\.left\(\);return \6\.insert\(\3\)\}'
)


def generate_fix_v3(m):
    """Generate IME fix for v2.1.148+ pattern from regex match groups."""
    fn, ev, text, esc, reset, state = m.group(1, 2, 3, 4, 5, 6)
    left_case, right_case = m.group(7), m.group(8)
    up_fn, down_fn = m.group(9), m.group(10)
    bksp_super, bksp_ctrl = m.group(11), m.group(12)
    del_fn = m.group(13)
    scroll_fn = m.group(14)
    return_fn = m.group(15)
    ctrl_fn, meta_fn = m.group(16), m.group(17)
    special_keys = m.group(18)
    prefix_fn = m.group(19)

    return (
        b'function ' + fn + b'(' + ev + b',' + text + b'){switch(' + ev + b'.name){'
        b'case"escape":if(' + esc + b')return;return ' + reset + b'(),' + state + b';'
        + left_case + right_case
        + b'case"up":case"down":if(' + ev + b'.shift||' + ev + b'.ctrl||' + ev + b'.meta)return;return ' + ev + b'.name==="up"?' + up_fn + b'():' + down_fn + b'();'
        b'case"backspace":return ' + ev + b'.superKey?' + bksp_super + b'():' + ev + b'.meta||' + ev + b'.ctrl?' + bksp_ctrl + b'():' + state + b'.deleteTokenBefore()??' + state + b'.backspace();'
        b'case"delete":return ' + ev + b'.superKey||' + ev + b'.meta?' + del_fn + b'():' + state + b'.del();'
        b'case"home":case"end":if(' + ev + b'.ctrl)return;return ' + state + b'[' + ev + b'.name==="home"?"startOfLine":"endOfLine"]();'
        b'case"pagedown":case"pageup":if(' + scroll_fn + b'()||' + ev + b'.ctrl)return;return ' + state + b'[' + ev + b'.name==="pagedown"?"endOfLine":"startOfLine"]();'
        b'case"return":if(' + ev + b'.ctrl)return;return ' + return_fn + b'(' + ev + b');'
        b'case"enter":return ' + state + b'.insert(`\n`);case"tab":return}'
        b'if(' + ev + b'.ctrl)return ' + ctrl_fn + b'(' + ev + b'.key);if(' + ev + b'.meta)return ' + meta_fn + b'(' + ev + b'.key);'
        b'if(' + special_keys + b'.has(' + ev + b'.name)||!' + text + b')return;'
        b'/* VN-IME-FIX */'
        b'if(' + text + b'.includes("\\x7f"))return[...' + text + b'].reduce((a,b)=>"\\x7f"==b?a.backspace():a.insert(b),' + state + b');'
        b'return ' + state + b'.isAtStart()&&' + prefix_fn + b'(' + text + b')?' + state + b'.insert(' + text + b').left():' + state + b'.insert(' + text + b')}'
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


def generate_fix(original_pattern):
    """Generate fix code with same length as original."""
    # New pattern v3 (>= v2.1.148): .name-based switch, flexible variable names
    v3_match = BUG_PATTERN_V3_RE.match(original_pattern)
    if v3_match:
        fix = generate_fix_v3(v3_match)
    # New pattern v2 (>= v2.1.114): entire function t body
    elif original_pattern == BUG_PATTERN_NEW:
        fix = FIX_CODE_NEW
    else:
        # Legacy pattern: extract variable names via regex
        legacy_re = re.compile(
            rb'if\(!([\w$]+)\.backspace&&!\1\.delete&&([\w$]+)\.includes\("\\x7F"\)\){'
            rb'let ([\w$]+)=\(\2\.match\(/\\x7f/g\)\|\|\[\]\)\.length,([\w$]+)=([\w$]+);'
            rb'for\(let ([\w$]+)=0;\6<\3;\6\+\+\)\4=\4\.deleteTokenBefore\(\)\?\?\4\.backspace\(\);'
            rb'if\(!\5\.equals\(\4\)\){if\(\5\.text!==\4\.text\)([\w$]+)\(\4\.text\);([\w$]+)\(\4\.offset\)}'
            rb'([\w$]+)\(\),([\w$]+)\(\);return}'
        )
        match = legacy_re.match(original_pattern)
        if not match:
            fix = FIX_CODE
        else:
            dt, rt, _, _, state_var, _, update_text, update_offset, fn1, fn2 = match.groups()
            fix = (
                b'if(!' + dt + b'.backspace&&!' + dt + b'.delete&&' + rt + b'.includes("\\x7F")){'
                b'let s=' + state_var + b';for(let c of ' + rt + b')c==="\\x7f"?s=s.backspace():s=s.insert(c);'
                b'if(!' + state_var + b'.equals(s)){if(' + state_var + b'.text!==s.text)' + update_text + b'(s.text);' + update_offset + b'(s.offset)}'
                + fn1 + b'(),' + fn2 + b'();return}'
            )

    original_len = len(original_pattern)
    fix_len = len(fix)

    if fix_len > original_len:
        raise RuntimeError(
            f"Fix code ({fix_len}) dài hơn original ({original_len}). "
            "Cần tối ưu thêm."
        )

    # Pad with spaces before the closing } to match original length
    if fix_len < original_len:
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

    # ── New pattern v3 (>= v2.1.148): .name-based switch ─────────────────────
    for match in BUG_PATTERN_V3_RE.finditer(content):
        results.append((match.start(), match.group(0)))

    if results:
        return results

    # ── New pattern v2 (>= v2.1.114): entire function t body ──────────────────
    start = 0
    while True:
        idx = content.find(BUG_PATTERN_NEW, start)
        if idx == -1:
            break
        results.append((idx, BUG_PATTERN_NEW))
        start = idx + len(BUG_PATTERN_NEW)

    if results:
        return results

    # ── Legacy exact match ─────────────────────────────────────────────────────
    start = 0
    while True:
        idx = content.find(BUG_PATTERN, start)
        if idx == -1:
            break
        results.append((idx, BUG_PATTERN))
        start = idx + len(BUG_PATTERN)

    if results:
        return results

    # ── Legacy regex fallback (variable name variations) ─────────────────────
    legacy_re = re.compile(
        rb'if\(!([\w$]+)\.backspace&&!\1\.delete&&([\w$]+)\.includes\("\\x7F"\)\){'
        rb'let ([\w$]+)=\(\2\.match\(/\\x7f/g\)\|\|\[\]\)\.length,([\w$]+)=([\w$]+);'
        rb'for\(let ([\w$]+)=0;\6<\3;\6\+\+\)\4=\4\.deleteTokenBefore\(\)\?\?\4\.backspace\(\);'
        rb'if\(!\5\.equals\(\4\)\){if\(\5\.text!==\4\.text\)([\w$]+)\(\4\.text\);([\w$]+)\(\4\.offset\)}'
        rb'([\w$]+)\(\),([\w$]+)\(\);return}'
    )
    for match in legacy_re.finditer(content):
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

        # Write patched binary using a temporary file to avoid "Text file busy"
        temp_path = f"{file_path}.tmp"
        try:
            with open(temp_path, 'wb') as f:
                f.write(patched)
            
            # On Linux, renaming over a busy file is allowed, while truncating it isn't.
            # This is safer than following the symlink and patching the target which might be shared.
            os.rename(temp_path, file_path)
        except Exception as e:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise e

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
        # Rollback using rename to avoid "Text file busy"
        if os.path.exists(backup_path):
            temp_rb = f"{file_path}.rollback.tmp"
            try:
                shutil.copy2(backup_path, temp_rb)
                os.rename(temp_rb, file_path)
            except Exception:
                if os.path.exists(temp_rb):
                    os.remove(temp_rb)
            finally:
                if os.path.exists(backup_path):
                    os.remove(backup_path)
            print("Đã rollback về bản gốc.", file=sys.stderr)
        return 1


def restore(file_path):
    """Restore file from latest backup."""
    backup = find_latest_backup(file_path)
    if not backup:
        print(f"Không tìm thấy backup cho {file_path}", file=sys.stderr)
        return 1

    # Use a safer way to restore if the file is busy (using rename)
    temp_path = f"{file_path}.restore.tmp"
    try:
        shutil.copy2(backup, temp_path)
        os.rename(temp_path, file_path)
    except Exception as e:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise e

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
