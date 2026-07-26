# 🎓 AI English Tutor — Native macOS App

**AI English Tutor** là một ứng dụng macOS gốc (Native macOS App) được xây dựng 100% bằng **Swift & SwiftUI**, tích hợp **Google Gemini Live API** (Voice-to-Voice Realtime) và **ScreenCaptureKit** của Apple.

Ứng dụng đóng vai trò là một **thầy giáo tiếng Anh AI** luôn đồng hành cùng bạn trên màn hình macOS:
* 👁️ **Nhìn màn hình**: Tự động chụp và phân tích nội dung bạn đang xem (đọc báo, học tài liệu, làm bài tập...).
* 🎙️ **Nói chuyện trực tiếp**: Giao tiếp bằng giọng nói độ trễ thấp (Realtime Voice-to-Voice) qua WebSocket.
* 💡 **Hướng dẫn thông minh**: Giải thích từ vựng, sửa lỗi phát âm/ngữ pháp và luyện phản xạ nói theo trình độ của bạn.

---

## ✨ Tính năng nổi bật

- **Menu Bar & Mini Window (Always-on-top)**: Chạy gọn gàng trên thanh menu hệ thống (`NSStatusItem`) và có một cửa sổ mini nổi góc màn hình luôn ở trên cùng để bạn tiện tương tác mà không bị che nội dung học.
- **ScreenCaptureKit Integration**: Tự động bắt hình ảnh màn hình với hiệu năng cao, gửi về AI để giải thích ngữ cảnh bài học.
- **VAD & Barge-in**: Nhận diện giọng nói thông minh, AI lập tức dừng phát âm thanh ngay khi bạn cất lời ngắt lời (barge-in).
- **Phím tắt toàn cục (Global Hotkeys)**:
  - `Ctrl + Option + M` (`⌃⌥M`): Bật/Tắt Microphone.
  - `Ctrl + Option + S` (`⌃⌥S`): Bắt đầu / Kết thúc phiên học.
- **Bảo mật Keychain**: API Key được mã hóa và lưu trữ an toàn trong macOS Keychain.
- **Phụ đề & Lịch sử**: Hiển thị phụ đề thời gian thực và cho phép xuất lịch sử hội thoại ra file `.txt`.

---

## 💻 Yêu cầu hệ thống

* **Hệ điều hành**: macOS 14.0 Sonoma trở lên.
* **Công cụ phát triển**: Xcode 15.0+ hoặc Swift 5.9+ Toolchain.
* **Quyền hệ thống cần cấp**:
  1. **Microphone**: Cho phép ứng dụng thu âm giọng nói.
  2. **Screen Recording (Ghi màn hình)**: Cho phép ứng dụng chụp màn hình qua ScreenCaptureKit (*System Settings → Privacy & Security → Screen Recording*).

---

## 🔑 Hướng dẫn lấy Gemini API Key (Miễn phí)

1. Truy cập [Google AI Studio](https://aistudio.google.com).
2. Đăng nhập bằng tài khoản Google của bạn.
3. Chọn **Get API Key** → **Create API Key**.
4. Mở ứng dụng **AI English Tutor**, vào mục **Settings** (Cài đặt) và dán API Key vào. Key sẽ được tự động lưu an toàn trong Keychain.

---

## 🛠️ Hướng dẫn Biên dịch & Chạy dự án (Build & Run)

Dự án được quản lý bằng **Swift Package Manager (SPM)**, bạn có thể build và chạy dễ dàng từ Terminal:

### 1. Build dự án
```bash
swift build -c release
```

### 2. Chạy Unit Tests & Integration Tests
```bash
swift test
```

### 3. Chạy ứng dụng trực tiếp
```bash
swift run AIEnglishTutorApp
```

### 4. Đóng gói ứng dụng (.app)
```bash
# Build binary
swift build -c release --product AIEnglishTutorApp

# Tạo thư mục .app bundle
mkdir -p build/AI\ English\ Tutor.app/Contents/MacOS
cp .build/release/AIEnglishTutorApp build/AI\ English\ Tutor.app/Contents/MacOS/AI\ English\ Tutor
```

---

## 🏗️ Cấu trúc dự án

```
AI_English_Tutor/
├── Package.swift               # Cấu hình Swift Package Manager
├── Sources/
│   ├── AIEnglishTutor/         # Core Framework (Services, ViewModels, Views)
│   │   ├── Models/             # AppConfig, GeminiMessage, TranscriptEntry
│   │   ├── Services/           # ScreenCapture, AudioEngine, GeminiLiveClient, Keychain, Hotkeys
│   │   ├── ViewModels/         # AppViewModel (State Management)
│   │   ├── Views/              # MainWindow, MenuBarView, MiniFloatingWindow
│   │   └── Mocks/              # Protocol Mocks cho Unit Tests
│   └── AIEnglishTutorApp/      # Main Entry Point (@main)
├── Tests/
│   └── AIEnglishTutorTests/    # Bộ Unit Tests & Integration Tests đầy đủ
└── README.md
```

---

## 📋 Danh sách Kiểm thử Thủ công (Manual Testing Checklist)

| STT | Tính năng | Cách kiểm tra | Kế hoạch kiểm tra |
|---|---|---|---|
| 1 | Quyền Screen Recording | Mở app lần đầu, xác nhận hệ thống hỏi cấp quyền Ghi màn hình | Đạt ✅ |
| 2 | Menu Bar Icon | Kiểm tra icon hiện trên thanh Status Bar hệ thống | Đạt ✅ |
| 3 | Mini Floating Window | Mở cửa sổ mini, di chuyển các góc và mở app khác đè lên (phải luôn nổi trên cùng) | Đạt ✅ |
| 4 | Global Hotkeys | Bấm `⌃⌥M` để mute mic và `⌃⌥S` để dừng phiên học từ ứng dụng khác | Đạt ✅ |
| 5 | Lưu Keychain | Nhập API Key trong Settings, tắt app mở lại kiểm tra xem key còn không | Đạt ✅ |
| 6 | Export Transcript | Bấm nút Export và chọn vị trí lưu file `.txt` | Đạt ✅ |

---

## 📄 Giấy phép (License)

Dự án phát triển cá nhân phục vụ học tập và nghiên cứu tiếng Anh. MIT License.
