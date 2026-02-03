# Claude Code Vietnamese IME Fix

Fix lỗi gõ tiếng Việt trong Claude Code CLI với các bộ gõ OpenKey, EVKey, PHTV, Unikey... Hỗ trợ macOS, Linux và Windows (npm).

## Vấn đề

Khi gõ tiếng Việt trong Claude Code CLI, các bộ gõ sử dụng kỹ thuật "backspace rồi thay thế" để chuyển đổi ký tự (ví dụ: `a` → `á`). Claude Code xử lý phần backspace nhưng không chèn ký tự thay thế, dẫn đến:

- Ký tự bị "nuốt" hoặc mất khi gõ
- Văn bản hiển thị không đúng với những gì đã gõ
- Phải copy-paste từ nơi khác thay vì gõ trực tiếp

## Cài đặt

Lần đầu chạy sẽ **tự động fix** luôn.

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/manhit96/claude-code-vietnamese-fix/main/install.ps1 | iex
```

## Sau khi update Claude Code

Chạy lại fix:

```bash
python3 ~/.claude-vn-fix/patcher.py
```

**Windows:**

```powershell
python ~\.claude-vn-fix\patcher.py
```

## Các lệnh

```bash
python3 patcher.py              # Tự động phát hiện và fix
python3 patcher.py --restore    # Khôi phục từ backup
python3 patcher.py --path FILE  # Fix file cụ thể
python3 patcher.py --help       # Hiển thị hướng dẫn
```

## Cập nhật patcher

```bash
cd ~/.claude-vn-fix && git pull
```

## Credits

Tham khảo và cải tiến từ [PHTV](https://github.com/phamhungtien/PHTV).
