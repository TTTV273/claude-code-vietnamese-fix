# Claude Code Vietnamese IME Fix

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

> ✅ Đã test thành công trên Claude Code v2.1.7 (npm)

**Yêu cầu:** Chỉ hỗ trợ bản cài qua npm. Nếu bạn cài Claude Code bằng cách khác (installer, scoop...), hãy gỡ cài đặt và cài lại qua npm:

```cmd
npm install -g @anthropic-ai/claude-code
```

Mở PowerShell, chạy:

```powershell
irm https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patch-claude-code-vn-win-npm.ps1 | iex
```

Sau khi fix xong, dùng Claude Code bằng CMD.

## Các lệnh khác

**macOS:**

- Restore: `patch-claude-code-vn-mac-npm.sh restore`
- Status: `patch-claude-code-vn-mac-npm.sh status`

**Windows:**

- Restore: `.\patch-claude-code-vn-win-npm.ps1 restore`
- Status: `.\patch-claude-code-vn-win-npm.ps1 status`

## Troubleshooting

Nếu vẫn lỗi sau khi fix, chạy script diagnostic (tự động lưu `diagnostic.txt` và hỏi tạo GitHub issue):

**macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/diagnostic-macos.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/diagnostic-windows.ps1 | iex
```

## Lưu ý

- Khi Claude Code update, chạy lại lệnh fix
- Nếu gặp lỗi sau khi fix, chạy `restore` để khôi phục

## Roadmap

Dự kiến hỗ trợ thêm các CLI khác:

- [ ] Gemini CLI
- [ ] GitHub Copilot CLI

## Credits

Tham khảo và cải tiến từ [PHTV](https://github.com/phamhungtien/PHTV) để hỗ trợ Claude Code version mới.
