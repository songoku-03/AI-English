# Original User Request

## 2026-07-27T03:25:49Z

<USER_REQUEST>
# PROMPT CHO AI CODING AGENT — Native macOS App "AI English Tutor" (Swift/SwiftUI)

Native macOS App "AI English Tutor" (Swift/SwiftUI) enabling voice-to-voice interaction with Gemini Live API, real-time screen capture via ScreenCaptureKit, and audio streaming via AVAudioEngine, running as a menu bar app with an always-on-top mini floating window.

Working directory: /Users/mac/Documents/GitHub/AI_English_Tutor
Integrity mode: development

## Requirements

### R1. Native macOS Core & Menu Bar Architecture
- Built using 100% native Swift 5.9+ / SwiftUI / AppKit targeting macOS 14 Sonoma or higher.
- Runs as a menu bar app (`NSStatusItem`) with a floating always-on-top mini window (`NSWindow.level = .floating`) and a main setup/chat transcript window.
- Supports global hotkeys (`⌃⌥M` for mute, `⌃⌥S` for session start/stop) working system-wide.
- Stores API keys securely in macOS Keychain (`Security` framework).

### R2. ScreenCaptureKit Integration
- Uses `ScreenCaptureKit` (`SCStream`, `SCShareableContent`) to capture selected display/window.
- Extracts 1 frame per second, resizes to ≤1024px width, JPEG compression (~0.7), and streams JPEG base64 images to Gemini Live API.
- Gracefully checks and handles Screen Recording permissions.

### R3. Audio Engine & Realtime Gemini Live API
- Uses `AVAudioEngine` for microphone PCM16 16kHz mono audio input streaming and smooth 24kHz audio output playback buffer queuing.
- Connects to Google Gemini Live API via `URLSessionWebSocketTask` using `gemini-3.1-flash-live` (with fallback to `gemini-2.5-flash-native-audio-preview-12-2025`).
- Supports VAD / barge-in: immediately stops AI audio playback when the user interrupts and speaks.

### R4. English Tutor System Prompt & Subtitles
- Implements custom English tutor persona (patient, friendly, corrects grammar/pronunciation, concise, asks follow-up questions).
- Displays live chat subtitles/transcription and supports exporting transcript history to `.txt` via `NSSavePanel`.

## Acceptance Criteria

### Build & Automation
- [ ] `xcodebuild build` (or `swift build`) succeeds with 0 errors and 0 critical warnings.
- [ ] `xcodebuild test` (or `swift test`) runs with all unit tests PASSing.
- [ ] Build output packaged cleanly into executable `.app` bundle.

### Functionality & Storage
- [ ] API Key correctly stored and retrieved via Keychain.
- [ ] `GeminiLiveClient` constructs correct WebSocket setup messages (model, system prompt, voice, transcription).
- [ ] `ScreenCapture` correctly resizes/compresses mock frame data to ≤1024px JPEG.
- [ ] `AudioEngine` handles sample rate conversion and playback queue logic cleanly.
- [ ] Reconnect logic automatically retries up to 3 times on WebSocket drop.
- [ ] Menu bar item and floating always-on-top window initialize and behave properly.

---

## VÒNG LẶP BUILD → RUN → TEST → FIX (BẮT BUỘC)

Lặp lại cho tới khi tất cả tiêu chí PASS:
1. PLAN  : Liệt kê task nhỏ tiếp theo (≤5 task).
2. BUILD : Code task đó.
3. RUN   : Build bằng `xcodebuild` (hoặc `swift build`). Chạy app, đọc kỹ log Console.
4. TEST  : `xcodebuild test` / `swift test`. Kiểm tra 0 warning nghiêm trọng, 0 lỗi biên dịch.
5. CHECK : So với Acceptance Criteria. In bảng PASS/FAIL từng mục.
6. FIX   : Nếu FAIL → tìm nguyên nhân gốc, sửa, quay lại bước 3.
7. Khi tất cả PASS → clean build từ đầu (`xcodebuild clean` rồi build+test lại), sau đó đóng gói thành `.app`.

Quy tắc:
- Không đánh dấu PASS khi chưa thực sự chạy lệnh và thấy kết quả.
- Mỗi vòng in bảng trạng thái Acceptance Criteria.
- Cùng một lỗi sửa 3 lần không được → đổi hướng tiếp cận.
- Phần không test tự động được (âm thanh thật, màn hình thật, cấp quyền hệ thống) → viết mock/protocol để test logic thuần, và ghi rõ mục "Test thủ công" trong README.
- Ưu tiên thiết kế có protocol/dependency injection cho WebSocket, ScreenCapture, Audio để unit test dễ mock.

</USER_REQUEST>
