# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project fixes Vietnamese IME input bugs in Claude Code CLI. Vietnamese input methods (OpenKey, EVKey, Unikey, PHTV) use "backspace then replace" technique to convert characters (e.g., `a` → `á`). Claude Code handles the backspace but doesn't insert the replacement character, causing text to be "swallowed".

## Architecture

Two patchers for different Claude Code installations:

| File | Target | Method |
|------|--------|--------|
| `patcher.py` | npm version (`cli.js`) | Text replacement in JavaScript |
| `patcher_bun.py` | Standalone binary (Bun) | Binary patching + code signing |

### How the Fix Works

Both patchers find the bug pattern containing `.includes("\x7f")` and `deleteTokenBefore()`, then replace it with code that:
1. Counts backspace characters (`\x7f`)
2. Extracts replacement text (input without `\x7f`)
3. Performs backspace operations
4. **Inserts replacement characters** (the missing step)

### Key Technical Details

- **npm patcher**: Extracts minified variable names dynamically using regex, generates fix code with those variables
- **Bun patcher**: Fix code must be **exactly same byte length** as original (pads with spaces if shorter), requires macOS code re-signing after modification
- **Bug pattern** appears in 2 locations in Bun binary

## Commands

```bash
# Run npm patcher (for npm install)
python3 patcher.py

# Run Bun patcher (for standalone binary)
python3 patcher_bun.py

# Restore from backup
python3 patcher.py --restore
python3 patcher_bun.py --restore

# Patch specific file
python3 patcher.py --path /path/to/cli.js
python3 patcher_bun.py --path /path/to/claude

# Run tests (downloads latest 3 npm versions, patches, verifies)
python3 test.py
```

## File Locations

- **npm cli.js**: `~/.npm/_npx/*/node_modules/@anthropic-ai/claude-code/cli.js` or `~/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/claude-code/cli.js`
- **Bun binary**: `~/.local/bin/claude` (symlink) → `~/.local/share/claude/versions/X.Y.Z` (actual binary)

## Important Notes

- Always create backup before patching
- Bun binary requires `codesign --force --sign -` on macOS after modification
- Test with `claude --version` after patching to verify binary still works
