# Claude Code Vietnamese IME Fix

Fix lỗi gõ tiếng Việt trong Claude Code CLI trên macOS và Windows. Hỗ trợ các bộ gõ tiếng Việt phổ biến như OpenKey, EVKey, PHTV, Unikey...

## Cài đặt

### macOS

```bash
# Cài Claude Code qua npm (nếu chưa có)
npm install -g @anthropic-ai/claude-code

# Chạy patch
curl -fsSL https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patch-claude-code-vn-mac-npm.sh | bash
```

<details>
<summary>macOS - Bản Binary/Homebrew (Thử nghiệm ⚠️)</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patch-claude-code-vn-mac-binary.sh | bash
```

> ⚠️ Patch binary là bản thử nghiệm, có thể gây lỗi. Binary sẽ được re-sign với ad-hoc signature.

</details>

### Windows

```powershell
# Cài Claude Code qua npm (nếu chưa có)
npm install -g @anthropic-ai/claude-code

# Tải và chạy patch
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patch-claude-code-vn-win-npm.ps1" -OutFile "patch-claude-code-vn-win-npm.ps1"
powershell -ExecutionPolicy Bypass -File .\patch-claude-code-vn-win-npm.ps1
```

## Các lệnh khác

**macOS:**

- Restore: `patch-claude-code-vn-mac-npm.sh restore`
- Status: `patch-claude-code-vn-mac-npm.sh status`

**Windows:**

- Restore: `.\patch-claude-code-vn-win-npm.ps1 restore`
- Status: `.\patch-claude-code-vn-win-npm.ps1 status`

## Lưu ý

- Khi Claude Code update, chạy lại lệnh patch
- Nếu gặp lỗi sau khi patch, chạy `restore` để khôi phục

## Credits

Tham khảo và cải tiến từ [PHTV](https://github.com/phamhungtien/PHTV) để hỗ trợ Claude Code version mới.
