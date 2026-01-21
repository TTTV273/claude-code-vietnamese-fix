# Claude Code Vietnamese IME Fix

Fix lỗi gõ tiếng Việt trong Claude Code CLI với các bộ gõ OpenKey, EVKey, PHTV, Unikey... Hỗ trợ cả macOS và Windows.

## Tương thích

✅ **Tự động tương thích với các phiên bản mới** - Script tự động phát hiện và sửa lỗi, hoạt động với hầu hết các phiên bản Claude Code mà không cần cập nhật.

**Đã test:** Claude Code v2.1.6 → v2.1.14 (cập nhật 2026-01-21)

## Vấn đề

Khi gõ tiếng Việt trong Claude Code CLI, các bộ gõ sử dụng kỹ thuật "backspace rồi thay thế" để chuyển đổi ký tự (ví dụ: `a` → `á`). Claude Code xử lý phần backspace nhưng không hiển thị ký tự thay thế, dẫn đến:

- Ký tự bị "nuốt" hoặc mất khi gõ
- Văn bản hiển thị không đúng với những gì đã gõ
- Phải copy-paste từ nơi khác thay vì gõ trực tiếp

## Giải pháp

Script này sửa lỗi bằng cách:

- Tự động tìm vị trí xử lý backspace trong Claude Code
- Thêm logic để hiển thị ký tự tiếng Việt đúng sau khi gõ
- Hoạt động với mọi phiên bản Claude Code (kể cả khi code bị nén/tối ưu)

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

**Yêu cầu:** Chỉ hỗ trợ bản cài qua npm. Nếu bạn cài Claude Code bằng cách khác (installer, scoop...), hãy gỡ cài đặt và cài lại qua npm:

```cmd
npm install -g @anthropic-ai/claude-code
```

Mở PowerShell, chạy:

```powershell
irm https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/patch-claude-code-vn-win-npm.ps1 -OutFile patch-claude-code-vn-win-npm.ps1; .\patch-claude-code-vn-win-npm.ps1
```

Sau khi fix xong, dùng Claude Code bằng CMD.

## Các lệnh khác

**macOS:**

- Restore: `patch-claude-code-vn-mac-npm.sh restore`
- Status: `patch-claude-code-vn-mac-npm.sh status`

**Windows (PowerShell):**

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

- **Tự động tương thích:** Script tự động phát hiện và sửa lỗi, hoạt động với hầu hết phiên bản Claude Code mới
- **Khi update Claude Code:** Chạy lại lệnh fix sau khi update
- **Kiểm tra trạng thái:** Dùng lệnh `status` để xem đã fix chưa và lỗi có còn tồn tại không
- **Khôi phục nếu lỗi:** Nếu gặp vấn đề, chạy `restore` để khôi phục về bản gốc

## Credits

Tham khảo và cải tiến từ [PHTV](https://github.com/phamhungtien/PHTV) để hỗ trợ Claude Code version mới.
