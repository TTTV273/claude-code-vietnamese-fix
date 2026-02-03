#!/usr/bin/env python3
"""
Claude Code Vietnamese IME Fix - Core Patcher

Fixes Vietnamese input bug in Claude Code CLI by dynamically patching
the backspace handling logic to insert replacement text.

Repository: https://github.com/manhit96/claude-code-vietnamese-fix
License: MIT
"""

import sys
import argparse
import os
import re
import shutil
from datetime import datetime
from typing import Optional, Dict, Tuple

# Version
__version__ = "1.0.0"

# Constants
PATCH_MARKER = "/* Vietnamese IME fix */"
DEL_CHAR = chr(127)  # 0x7F

# Pattern matching search ranges
BLOCK_SEARCH_BEFORE = 150  # Characters to search before pattern for 'if(' block start
BLOCK_SEARCH_AFTER = 800   # Characters to search after for closing brace


class PatchError(Exception):
    """Base exception for patcher errors."""
    pass


class PatternNotFoundError(PatchError):
    """Raised when dynamic pattern matching fails."""
    pass


class AlreadyPatchedError(PatchError):
    """Raised when file is already patched."""
    pass


def find_bug_block(content: str) -> Tuple[int, int, str]:
    """
    Tìm block code chứa bug Vietnamese IME.

    Args:
        content: Nội dung file JavaScript

    Returns:
        Tuple[block_start, block_end, full_block]

    Raises:
        PatternNotFoundError: Nếu không tìm thấy pattern
    """
    # Find the includes check with DEL character
    includes_pattern = f'.includes("{DEL_CHAR}")'
    idx = content.find(includes_pattern)

    if idx == -1:
        raise PatternNotFoundError(
            f"Không tìm thấy pattern .includes(\"\\x7f\"). "
            f"Claude Code có thể đã được Anthropic fix bug này."
        )

    # Find the full if block containing this pattern
    block_start = content.rfind('if(', max(0, idx - BLOCK_SEARCH_BEFORE), idx)
    if block_start == -1:
        raise PatternNotFoundError("Không tìm thấy block if chứa pattern")

    # Find matching closing brace
    depth = 0
    block_end = idx
    for i, c in enumerate(content[block_start:block_start + BLOCK_SEARCH_AFTER]):
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                block_end = block_start + i + 1
                break

    if depth != 0:
        raise PatternNotFoundError("Không tìm thấy closing brace của block if")

    full_block = content[block_start:block_end]
    return block_start, block_end, full_block


def extract_variables(full_block: str) -> Dict[str, str]:
    """
    Trích xuất tên biến động từ bug block.

    Args:
        full_block: Block code chứa bug

    Returns:
        Dict chứa các biến: input, count, state, cur_state, update_text_func, update_offset_func

    Raises:
        PatternNotFoundError: Nếu không extract được biến
    """
    variables = {}

    # Normalize DEL_CHAR to \x7f for regex
    normalized_block = full_block.replace(DEL_CHAR, '\\x7f')

    # Note: Variable names can include $ (e.g., $A, EA, GT)
    # Pattern 1: let COUNT=(INPUT.match(/\x7f/g)||[]).length,STATE=CURSTATE;
    vars_match = re.search(
        r'let ([\w$]+)=\(\w+\.match\(/\\x7f/g\)\|\|\[\]\)\.length,([\w$]+)=([\w$]+);',
        normalized_block
    )

    # Pattern 2: let COUNT=(INPUT.match(/\x7f/g)||[]).length,STATE=CURSTATE;for
    if not vars_match:
        vars_match = re.search(
            r'let ([\w$]+)=\(\w+\.match\(/\\x7f/g\)\|\|\[\]\)\.length,([\w$]+)=([\w$]+);for',
            normalized_block
        )

    # Pattern 3 (older versions): separate lines or different spacing
    if not vars_match:
        vars_match = re.search(
            r'let ([\w$]+)=\(\w+\.match\(/\\x7f/g\)\|\|\[\]\)\.length[,;]([\w$]+)=([\w$]+)[;,]',
            normalized_block
        )

    if not vars_match:
        raise PatternNotFoundError(
            "Không trích xuất được biến count/state. "
            "Code structure có thể đã thay đổi."
        )

    variables['count'] = vars_match.group(1)
    variables['state'] = vars_match.group(2)
    variables['cur_state'] = vars_match.group(3)

    # Extract update functions: UPDATETEXT(STATE.text);UPDATEOFFSET(STATE.offset)
    update_match = re.search(
        rf'([\w$]+)\({re.escape(variables["state"])}\.text\);([\w$]+)\({re.escape(variables["state"])}\.offset\)',
        full_block
    )
    if not update_match:
        raise PatternNotFoundError(
            "Không trích xuất được update functions. "
            "Code structure có thể đã thay đổi."
        )

    variables['update_text_func'] = update_match.group(1)
    variables['update_offset_func'] = update_match.group(2)

    # Extract input variable from includes check: INPUT.includes("\x7f")
    input_match = re.search(r'([\w$]+)\.includes\("', full_block)
    if not input_match:
        raise PatternNotFoundError("Không trích xuất được input variable")

    variables['input'] = input_match.group(1)

    return variables


def find_insertion_point(full_block: str, variables: Dict[str, str]) -> int:
    """
    Tìm vị trí chèn fix code.

    Args:
        full_block: Block code chứa bug
        variables: Dict chứa các biến đã extract

    Returns:
        Vị trí relative trong block để chèn fix

    Raises:
        PatternNotFoundError: Nếu không tìm thấy insertion point
    """
    # Find insertion point: right after UPDATEOFFSET(STATE.offset)}
    insert_pattern = rf'{re.escape(variables["update_offset_func"])}\({re.escape(variables["state"])}\.offset\)\}}'
    insert_match = re.search(insert_pattern, full_block)

    if not insert_match:
        raise PatternNotFoundError(
            "Không tìm thấy insertion point. "
            f"Pattern tìm: {insert_pattern}"
        )

    return insert_match.end()


def generate_fix_code(variables: Dict[str, str]) -> str:
    """
    Sinh fix code với các biến đã extract.

    Args:
        variables: Dict chứa các biến

    Returns:
        Fix code string
    """
    fix_code = (
        f'{PATCH_MARKER}'
        f'let _vn={variables["input"]}.replace(/\\x7f/g,"");'
        f'if(_vn.length>0){{'
        f'for(const _c of _vn){variables["state"]}={variables["state"]}.insert(_c);'
        f'if(!{variables["cur_state"]}.equals({variables["state"]})){{'
        f'if({variables["cur_state"]}.text!=={variables["state"]}.text)'
        f'{variables["update_text_func"]}({variables["state"]}.text);'
        f'{variables["update_offset_func"]}({variables["state"]}.offset)'
        f'}}}}'
    )
    return fix_code


def is_already_patched(content: str) -> bool:
    """
    Kiểm tra xem file đã được patch chưa.

    Args:
        content: Nội dung file

    Returns:
        True nếu đã patch
    """
    return PATCH_MARKER in content


def create_backup(file_path: str) -> str:
    """
    Tạo backup file với timestamp.

    Args:
        file_path: Đường dẫn file gốc

    Returns:
        Đường dẫn backup file

    Raises:
        IOError: Nếu không tạo được backup
    """
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = f"{file_path}.backup-{timestamp}"

    try:
        shutil.copy2(file_path, backup_path)
        return backup_path
    except Exception as e:
        raise IOError(f"Không tạo được backup: {e}")


def find_latest_backup(file_path: str) -> Optional[str]:
    """
    Tìm backup mới nhất của file.

    Args:
        file_path: Đường dẫn file gốc

    Returns:
        Đường dẫn backup file hoặc None nếu không có
    """
    dir_path = os.path.dirname(file_path)
    filename = os.path.basename(file_path)

    # List all backup files
    backup_files = []
    for entry in os.listdir(dir_path or '.'):
        if entry.startswith(f"{filename}.backup-"):
            full_path = os.path.join(dir_path, entry) if dir_path else entry
            backup_files.append(full_path)

    if not backup_files:
        return None

    # Sort by modification time, return latest
    backup_files.sort(key=lambda x: os.path.getmtime(x), reverse=True)
    return backup_files[0]


def restore_from_backup(file_path: str, backup_path: Optional[str] = None) -> str:
    """
    Khôi phục file từ backup.

    Args:
        file_path: Đường dẫn file cần khôi phục
        backup_path: Đường dẫn backup (nếu None, tìm backup mới nhất)

    Returns:
        Đường dẫn backup đã restore

    Raises:
        FileNotFoundError: Nếu không tìm thấy backup
        IOError: Nếu không restore được
    """
    if backup_path is None:
        backup_path = find_latest_backup(file_path)

    if backup_path is None or not os.path.exists(backup_path):
        raise FileNotFoundError(
            f"Không tìm thấy backup cho {file_path}. "
            f"Bạn có thể cài lại Claude Code để khôi phục."
        )

    try:
        shutil.copy2(backup_path, file_path)
        return backup_path
    except Exception as e:
        raise IOError(f"Không khôi phục được từ backup: {e}")


def main():
    """Main entry point for the patcher."""
    parser = argparse.ArgumentParser(
        description="Claude Code Vietnamese IME Fix - Core Patcher",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Commands:
  patch      Áp dụng Vietnamese IME fix
  status     Kiểm tra trạng thái patch
  restore    Khôi phục file gốc từ backup
  diagnostic Tạo báo cáo chẩn đoán

Examples:
  %(prog)s patch --type npm --path /path/to/cli.js
  %(prog)s status --path /path/to/cli.js
  %(prog)s restore --path /path/to/cli.js
  %(prog)s diagnostic --output diagnostic.txt
        """
    )

    parser.add_argument(
        '--version',
        action='version',
        version=f'%(prog)s {__version__}'
    )

    subparsers = parser.add_subparsers(dest='command', help='Lệnh cần thực hiện')

    # Patch command
    patch_parser = subparsers.add_parser(
        'patch',
        help='Áp dụng Vietnamese IME fix'
    )
    patch_parser.add_argument(
        '--type',
        required=True,
        choices=['npm', 'binary'],
        help='Loại cài đặt Claude Code (npm hoặc binary)'
    )
    patch_parser.add_argument(
        '--path',
        required=True,
        type=str,
        help='Đường dẫn đến file cần patch (cli.js hoặc binary)'
    )

    # Status command
    status_parser = subparsers.add_parser(
        'status',
        help='Kiểm tra trạng thái patch'
    )
    status_parser.add_argument(
        '--path',
        required=True,
        type=str,
        help='Đường dẫn đến file cần kiểm tra'
    )

    # Restore command
    restore_parser = subparsers.add_parser(
        'restore',
        help='Khôi phục file gốc từ backup'
    )
    restore_parser.add_argument(
        '--path',
        required=True,
        type=str,
        help='Đường dẫn đến file cần khôi phục'
    )

    # Diagnostic command
    diagnostic_parser = subparsers.add_parser(
        'diagnostic',
        help='Tạo báo cáo chẩn đoán'
    )
    diagnostic_parser.add_argument(
        '--output',
        type=str,
        default='diagnostic.txt',
        help='Đường dẫn file output (mặc định: diagnostic.txt)'
    )
    diagnostic_parser.add_argument(
        '--path',
        type=str,
        help='Đường dẫn đến file Claude Code (tùy chọn)'
    )

    args = parser.parse_args()

    # Validate command
    if not args.command:
        parser.print_help()
        sys.exit(1)

    # Execute command
    try:
        if args.command == 'patch':
            exit_code = cmd_patch(args.type, args.path)
        elif args.command == 'status':
            exit_code = cmd_status(args.path)
        elif args.command == 'restore':
            exit_code = cmd_restore(args.path)
        elif args.command == 'diagnostic':
            exit_code = cmd_diagnostic(args.output, args.path)
        else:
            parser.print_help()
            exit_code = 1

        sys.exit(exit_code)

    except KeyboardInterrupt:
        print("\n\n⚠️  Đã hủy bởi người dùng.", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Lỗi: {e}", file=sys.stderr)
        sys.exit(1)


def cmd_patch(file_type: str, file_path: str) -> int:
    """
    Áp dụng Vietnamese IME fix vào file.

    Args:
        file_type: Loại file ('npm' hoặc 'binary')
        file_path: Đường dẫn đến file cần patch

    Returns:
        Exit code (0 = success, 1 = failure)
    """
    print(f"→ Đang patch file: {file_path}")
    print(f"  Loại: {file_type}")

    # Validate file exists
    if not os.path.exists(file_path):
        print(f"❌ File không tồn tại: {file_path}", file=sys.stderr)
        return 1

    backup_path = None
    try:
        # Read file content
        print("→ Đang đọc file...")
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check if already patched
        if is_already_patched(content):
            print("✓ File đã được patch trước đó.")
            return 0

        # Create backup
        print("→ Đang tạo backup...")
        backup_path = create_backup(file_path)
        print(f"  Backup: {backup_path}")

        # Dynamic pattern matching
        print("→ Đang phân tích code structure...")
        block_start, block_end, full_block = find_bug_block(content)

        # Extract variables
        print("→ Đang trích xuất biến...")
        variables = extract_variables(full_block)
        print(f"  Variables: input={variables['input']}, "
              f"state={variables['state']}, "
              f"cur={variables['cur_state']}")

        # Generate fix code
        print("→ Đang sinh fix code...")
        fix_code = generate_fix_code(variables)

        # Find insertion point
        relative_pos = find_insertion_point(full_block, variables)
        absolute_pos = block_start + relative_pos

        # Apply patch
        print("→ Đang áp dụng patch...")
        patched_content = content[:absolute_pos] + fix_code + content[absolute_pos:]

        # Write patched file
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(patched_content)

        # Verify patch
        with open(file_path, 'r', encoding='utf-8') as f:
            verify_content = f.read()

        if not is_already_patched(verify_content):
            raise PatchError("Verification failed: Patch marker không tìm thấy sau khi patch")

        print("")
        print("╔════════════════════════════════════════════════════════════╗")
        print("║  ✓ Patch thành công! Vietnamese IME fix đã được áp dụng.  ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print("")
        print(f"Backup: {backup_path}")
        print("")
        print("⚠️  Vui lòng khởi động lại Claude Code để áp dụng thay đổi.")
        print("")

        return 0

    except AlreadyPatchedError:
        print("✓ File đã được patch trước đó.")
        return 0

    except PatternNotFoundError as e:
        print(f"\n❌ Không thể patch: {e}", file=sys.stderr)
        print("\nCode structure có thể đã thay đổi trong phiên bản mới.", file=sys.stderr)
        print("Vui lòng báo lỗi tại: https://github.com/manhit96/claude-code-vietnamese-fix/issues", file=sys.stderr)

        # Rollback
        if backup_path and os.path.exists(backup_path):
            print("\n→ Đang rollback...", file=sys.stderr)
            try:
                restore_from_backup(file_path, backup_path)
                os.remove(backup_path)
                print("✓ Đã khôi phục file gốc.", file=sys.stderr)
            except Exception as rollback_err:
                print(f"⚠️  Không rollback được: {rollback_err}", file=sys.stderr)

        return 1

    except Exception as e:
        print(f"\n❌ Lỗi: {e}", file=sys.stderr)

        # Rollback
        if backup_path and os.path.exists(backup_path):
            print("\n→ Đang rollback...", file=sys.stderr)
            try:
                restore_from_backup(file_path, backup_path)
                os.remove(backup_path)
                print("✓ Đã khôi phục file gốc.", file=sys.stderr)
            except Exception as rollback_err:
                print(f"⚠️  Không rollback được: {rollback_err}", file=sys.stderr)

        return 1


def cmd_status(file_path: str) -> int:
    """
    Kiểm tra trạng thái patch của file.

    Args:
        file_path: Đường dẫn đến file cần kiểm tra

    Returns:
        Exit code (0 = đã patch, 1 = chưa patch hoặc lỗi)
    """
    print(f"→ Kiểm tra trạng thái: {file_path}")
    print("")

    # Validate file exists
    if not os.path.exists(file_path):
        print(f"❌ File không tồn tại: {file_path}", file=sys.stderr)
        return 1

    try:
        # Read file content
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check patch status
        is_patched = is_already_patched(content)

        if is_patched:
            print("  Trạng thái: ✓ Đã patch")
        else:
            print("  Trạng thái: ✗ Chưa patch")

            # Check if bug code exists
            has_bug = f'.includes("{DEL_CHAR}")' in content and 'backspace()' in content

            if has_bug:
                print("  Bug code:   ⚠️  Có tồn tại - Cần patch!")
            else:
                print("  Bug code:   ℹ️  Không tìm thấy - Có thể đã được fix bởi Anthropic")

        # Check for backups
        backup = find_latest_backup(file_path)
        if backup:
            print(f"  Backup:     {backup}")
        else:
            print("  Backup:     Không có")

        print("")
        return 0 if is_patched else 1

    except Exception as e:
        print(f"\n❌ Lỗi: {e}", file=sys.stderr)
        return 1


def cmd_restore(file_path: str) -> int:
    """
    Khôi phục file gốc từ backup.

    Args:
        file_path: Đường dẫn đến file cần khôi phục

    Returns:
        Exit code (0 = success, 1 = failure)
    """
    print(f"→ Khôi phục file: {file_path}")

    try:
        backup_path = restore_from_backup(file_path)
        print(f"✓ Đã khôi phục từ: {backup_path}")
        print("")
        print("⚠️  Vui lòng khởi động lại Claude Code.")
        print("")
        return 0

    except FileNotFoundError as e:
        print(f"\n❌ {e}", file=sys.stderr)
        return 1

    except Exception as e:
        print(f"\n❌ Lỗi: {e}", file=sys.stderr)
        return 1


def cmd_diagnostic(output_path: str, file_path: str = None) -> int:
    """
    Tạo báo cáo chẩn đoán.

    Args:
        output_path: Đường dẫn file output
        file_path: Đường dẫn đến file Claude Code (tùy chọn)

    Returns:
        Exit code (0 = success, 1 = failure)
    """
    print(f"→ Tạo báo cáo chẩn đoán: {output_path}")

    try:
        import platform
        import subprocess

        diagnostic_info = []
        diagnostic_info.append("=" * 60)
        diagnostic_info.append("Claude Code Vietnamese IME Fix - Diagnostic Report")
        diagnostic_info.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        diagnostic_info.append("=" * 60)
        diagnostic_info.append("")

        # System info
        diagnostic_info.append("## System Information")
        diagnostic_info.append(f"OS: {platform.system()} {platform.release()}")
        diagnostic_info.append(f"Architecture: {platform.machine()}")
        diagnostic_info.append(f"Python: {sys.version}")
        diagnostic_info.append("")

        # Claude Code version
        diagnostic_info.append("## Claude Code")
        try:
            result = subprocess.run(['claude', '--version'],
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                diagnostic_info.append(f"Version: {result.stdout.strip()}")
            else:
                diagnostic_info.append("Version: Unable to detect")
        except Exception:
            diagnostic_info.append("Version: Not found or error")

        # File info (if provided)
        if file_path and os.path.exists(file_path):
            diagnostic_info.append("")
            diagnostic_info.append(f"## Target File: {file_path}")
            diagnostic_info.append(f"Size: {os.path.getsize(file_path)} bytes")
            diagnostic_info.append(f"Modified: {datetime.fromtimestamp(os.path.getmtime(file_path))}")

            # Check patch status
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                is_patched = is_already_patched(content)
                has_bug = f'.includes("{DEL_CHAR}")' in content

                diagnostic_info.append(f"Patched: {'Yes' if is_patched else 'No'}")
                diagnostic_info.append(f"Bug pattern exists: {'Yes' if has_bug else 'No'}")

                # Try to extract variables
                if has_bug and not is_patched:
                    try:
                        block_start, block_end, full_block = find_bug_block(content)
                        variables = extract_variables(full_block)
                        diagnostic_info.append("\n### Extracted Variables")
                        for key, value in variables.items():
                            diagnostic_info.append(f"  {key}: {value}")
                    except PatternNotFoundError as e:
                        diagnostic_info.append(f"\nPattern Extraction Failed: {e}")

            except Exception as e:
                diagnostic_info.append(f"Error reading file: {e}")

            # Check backups
            backup = find_latest_backup(file_path)
            diagnostic_info.append(f"\nLatest backup: {backup if backup else 'None'}")

        diagnostic_info.append("")
        diagnostic_info.append("=" * 60)
        diagnostic_info.append("Vui lòng đính kèm file này khi báo lỗi tại:")
        diagnostic_info.append("https://github.com/manhit96/claude-code-vietnamese-fix/issues")
        diagnostic_info.append("=" * 60)

        # Write to file
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(diagnostic_info))

        print(f"✓ Đã tạo báo cáo: {output_path}")
        print("")
        return 0

    except Exception as e:
        print(f"\n❌ Lỗi: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    main()
