#!/usr/bin/env python3
"""
Claude Code Vietnamese IME Fix - Test Runner

Auto-downloads latest 3 npm versions, patches, verifies --version works.
"""

import json
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
SOURCES_DIR = SCRIPT_DIR / "tests" / "sources"
PATCHER = SCRIPT_DIR / "patcher.py"

GREEN = "\033[0;32m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
NC = "\033[0m"


def get_latest_versions(count=3):
    """Get latest N versions from npm registry."""
    result = subprocess.run(
        ["npm", "view", "@anthropic-ai/claude-code", "versions", "--json"],
        capture_output=True, text=True, timeout=30
    )
    versions = json.loads(result.stdout)

    def semver_key(v):
        parts = v.replace("-", ".").split(".")
        return tuple(int(p) if p.isdigit() else 0 for p in parts[:3])

    return sorted(versions, key=semver_key, reverse=True)[:count]


def download_npm(version):
    """Download npm package and extract cli.js."""
    version_dir = SOURCES_DIR / f"v{version}"

    with tempfile.TemporaryDirectory() as temp_dir:
        subprocess.run(
            ["npm", "pack", f"@anthropic-ai/claude-code@{version}"],
            cwd=temp_dir, capture_output=True, timeout=120
        )
        tarball = list(Path(temp_dir).glob("*.tgz"))[0]

        version_dir.mkdir(parents=True, exist_ok=True)
        with tarfile.open(tarball, "r:gz") as tar:
            for member in tar.getmembers():
                if member.name.startswith("package/"):
                    member.name = member.name[8:]
                    if member.name:
                        tar.extract(member, version_dir, filter="data")

    return version_dir / "cli.js"


def run_patcher(args):
    """Run patcher with args, return (success, stdout, stderr)."""
    result = subprocess.run(
        [sys.executable, str(PATCHER)] + args,
        capture_output=True, text=True, timeout=30
    )
    return result.returncode == 0, result.stdout, result.stderr


def verify_runs(file_path):
    """Verify patched cli.js runs with --version."""
    result = subprocess.run(
        ["node", str(file_path), "--version"],
        capture_output=True, text=True, timeout=10
    )
    return result.returncode == 0, result.stdout.strip()


def verify_fix_logic(file_path):
    """Verify patched code contains correct fix logic (backspace + insert)."""
    content = Path(file_path).read_text(encoding='utf-8')

    # Must have patch marker
    if "/* Vietnamese IME fix */" not in content:
        return False, "missing patch marker"

    # Extract the fix block (from marker to next return;})
    marker_idx = content.index("/* Vietnamese IME fix */")
    fix_end = content.find("return;}", marker_idx)
    if fix_end == -1:
        return False, "cannot find fix block end"
    fix_block = content[marker_idx:fix_end + 8]

    # Must have backspace loop
    if ".backspace()" not in fix_block:
        return False, "missing .backspace() in fix"

    # Must have insert loop
    if ".insert(" not in fix_block:
        return False, "missing .insert() in fix"

    # Original bug pattern should be gone (deleteTokenBefore is in the old bug block)
    # Note: deleteTokenBefore may still exist elsewhere in the file, so check
    # that there's no block combining includes(\x7f) with deleteTokenBefore
    del_char = chr(127)
    bug_pattern = f'.includes("{del_char}")'
    # Count occurrences - should only appear in our fix block
    occurrences = content.count(bug_pattern)
    if occurrences > 1:
        return False, f"bug pattern appears {occurrences} times (expected 1 from fix)"

    return True, "fix logic OK"


def main():
    print()
    print("=" * 60)
    print("  Claude Code Vietnamese IME Fix - Test Suite")
    print("=" * 60)
    print()

    # Clean old sources
    if SOURCES_DIR.exists():
        print(f"{BLUE}-> Cleaning old sources...{NC}")
        shutil.rmtree(SOURCES_DIR)

    # Get versions
    print(f"{BLUE}-> Getting latest versions...{NC}")
    versions = get_latest_versions(3)
    print(f"   {', '.join(versions)}")
    print()

    results = []

    for version in versions:
        print(f"{BLUE}-> Testing v{version}{NC}")
        print(f"   downloading...", end=" ", flush=True)

        try:
            cli_js = download_npm(version)

            # Test patch
            print("patch...", end=" ", flush=True)
            ok, stdout, stderr = run_patcher(["--path", str(cli_js)])
            if not ok:
                print(f"{RED}✗{NC} Patch failed: {stderr}")
                results.append(("patch", version, False))
                continue

            # Verify --version
            print("verify...", end=" ", flush=True)
            ok, output = verify_runs(cli_js)
            if not ok:
                print(f"{RED}✗{NC} --version failed")
                results.append(("verify", version, False))
                continue

            # Verify fix logic (backspace + insert)
            print("logic...", end=" ", flush=True)
            ok, detail = verify_fix_logic(cli_js)
            if not ok:
                print(f"{RED}✗{NC} {detail}")
                results.append(("logic", version, False))
                continue

            # Test double-patch
            print("double-patch...", end=" ", flush=True)
            ok, stdout, _ = run_patcher(["--path", str(cli_js)])
            if "Đã patch" not in stdout:
                print(f"{RED}✗{NC} double-patch not detected")
                results.append(("double", version, False))
                continue

            # Test restore
            print("restore...", end=" ", flush=True)
            ok, _, stderr = run_patcher(["--restore", "--path", str(cli_js)])
            if not ok:
                print(f"{RED}✗{NC} restore failed: {stderr}")
                results.append(("restore", version, False))
                continue

            print(f"{GREEN}✓{NC} {output}")
            results.append(("npm", version, True))

        except Exception as e:
            print(f"{RED}✗{NC} {e}")
            results.append(("npm", version, False))

        print()

    # Edge case: nonexistent file
    print(f"{BLUE}-> Testing edge cases{NC}")
    print(f"   nonexistent file...", end=" ", flush=True)
    ok, _, _ = run_patcher(["--path", "/nonexistent/file.js"])
    if not ok:
        print(f"{GREEN}✓{NC} correctly rejected")
        results.append(("edge", "N/A", True))
    else:
        print(f"{RED}✗{NC} should have failed")
        results.append(("edge", "N/A", False))
    print()

    # Summary
    print("=" * 60)
    passed = sum(1 for _, _, ok in results if ok)
    total = len(results)

    if passed == total:
        print(f"{GREEN}All {total} tests passed!{NC}")
        return 0
    else:
        print(f"{RED}{passed}/{total} tests passed{NC}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
