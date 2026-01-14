# Vietnamese IME Fix for CLI Tools

Fix lỗi gõ tiếng Việt Claude Code với các bộ gõ OpenKey, EVKey, PHTV, Unikey... Hỗ trợ cả macOS và Windows.

**Phiên bản đã test:** Claude Code v2.1.6, v2.1.7

## Cài đặt

### macOS

Cài Claude Code qua npm (nếu chưa có):

```bash
npm install -g @anthropic-ai/claude-code
```

Tải và chạy fix:

```bash
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

Cài Claude Code qua npm (nếu chưa có):

```powershell
npm install -g @anthropic-ai/claude-code
```

Tải và chạy fix:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patch-claude-code-vn-win-npm.ps1" -OutFile "patch.ps1"; powershell -ExecutionPolicy Bypass -File .\patch.ps1
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

## Roadmap

Dự kiến hỗ trợ thêm các CLI khác:

- [ ] Gemini CLI
- [ ] GitHub Copilot CLI

## Credits

Tham khảo và cải tiến từ [PHTV](https://github.com/phamhungtien/PHTV) để hỗ trợ Claude Code version mới.
