# Claude Code Vietnamese IME Fix

Fix lỗi gõ tiếng Việt trong Claude Code CLI trên macOS và Windows. Hỗ trợ các bộ gõ tiếng Việt phổ biến như OpenKey, EVKey, PHTV, Unikey...

## Cài đặt

### macOS - Bản npm (Ổn định, Khuyên dùng)

```bash
# Cài Claude Code qua npm (nếu chưa có)
npm install -g @anthropic-ai/claude-code

# Chạy patch
curl -fsSL https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patch-claude-code-vn-npm.sh | bash
```

### macOS - Bản Binary/Homebrew (Thử nghiệm ⚠️)

```bash
# Nếu đã cài qua Homebrew hoặc native installer
curl -fsSL https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patch-claude-code-vn-binary.sh | bash
```

> **⚠️ Cảnh báo:** Patch binary là bản thử nghiệm, có thể gây lỗi. Binary sẽ được re-sign với ad-hoc signature.

### Windows - Bản npm

```powershell
# Cài Claude Code qua npm
npm install -g @anthropic-ai/claude-code

# Tải và chạy script kiểm tra môi trường (tùy chọn)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/check-claude-env-windows.ps1" -OutFile "check-claude-env-windows.ps1"
.\check-claude-env-windows.ps1

# Tải và chạy patch
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patch-claude-code-vn-windows.ps1" -OutFile "patch-claude-code-vn-windows.ps1"
.\patch-claude-code-vn-windows.ps1
```

> **Lưu ý:** Nếu gặp lỗi Execution Policy, chạy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

## Các lệnh

### macOS

| Lệnh    | npm version                           | Binary version                           |
| ------- | ------------------------------------- | ---------------------------------------- |
| Patch   | `patch-claude-code-vn-npm.sh`         | `patch-claude-code-vn-binary.sh`         |
| Restore | `patch-claude-code-vn-npm.sh restore` | `patch-claude-code-vn-binary.sh restore` |
| Status  | `patch-claude-code-vn-npm.sh status`  | `patch-claude-code-vn-binary.sh status`  |

### Windows

| Lệnh    | Command                                      |
| ------- | -------------------------------------------- |
| Check   | `.\check-claude-env-windows.ps1`             |
| Patch   | `.\patch-claude-code-vn-windows.ps1`         |
| Restore | `.\patch-claude-code-vn-windows.ps1 restore` |
| Status  | `.\patch-claude-code-vn-windows.ps1 status`  |

## So sánh npm vs Binary

|              | npm        | Binary (Homebrew) |
| ------------ | ---------- | ----------------- |
| Patch        | ✅ Ổn định | ⚠️ Thử nghiệm     |
| Auto-update  | ❌ Manual  | ❌ Manual         |
| Signature    | Không cần  | Ad-hoc (tự sign)  |
| Khuyến khích | ✅         | Chỉ khi cần       |

## Lưu ý

- Khi Claude Code update, chạy lại lệnh patch
- Nếu gặp lỗi sau khi patch binary, chạy `restore` để khôi phục

## Credits

Tham khảo và cải tiến từ [PHTV](https://github.com/phamhungtien/PHTV) để hỗ trợ Claude Code version mới.
