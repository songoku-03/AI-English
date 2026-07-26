## 2026-07-26T20:26:48Z
You are the Implementation Worker for Milestone 1: "Project Infra & Protocols" for the AI English Tutor macOS App project.

Working directory for metadata: /Users/mac/Documents/GitHub/AI_English_Tutor/.agents/worker_m1
Project root directory: /Users/mac/Documents/GitHub/AI_English_Tutor

Scope & Deliverables:
1. Initialize a clean Swift 5.9+ Package structure (or macOS App structure) in project root:
   - Target macOS 14 Sonoma or higher (`.macOS(.v14)`).
   - Executable/Library targets supporting SwiftUI, AppKit, ScreenCaptureKit, Security, AVFoundation, Carbon.
2. Define Core Models (`Sources/AIEnglishTutor/Models/`):
   - `AppConfig`: API key, system prompt, voice name, frame rate (1 fps), JPEG quality (0.7), max image dimension (1024).
   - `TranscriptEntry`: ID, timestamp, speaker (`.user` or `.tutor`), text content.
   - `GeminiLiveMessage`: WebSocket JSON message models for Gemini 3.1 Live API setup, client content (PCM16 16kHz base64, JPEG image base64), server content (realtime output audio 24kHz base64, text transcription).
3. Define Service Protocols (`Sources/AIEnglishTutor/Services/`):
   - `KeychainServiceProtocol`
   - `GlobalHotkeyServiceProtocol`
   - `ScreenCaptureServiceProtocol`
   - `AudioEngineServiceProtocol`
   - `GeminiLiveClientProtocol`
4. Implement Complete Mock Services (`Sources/AIEnglishTutor/Mocks/`):
   - `MockKeychainService` (in-memory dictionary store for testing)
   - `MockGlobalHotkeyService` (simulates hotkey triggers)
   - `MockScreenCaptureService` (generates mock test frames)
   - `MockAudioEngineService` (simulates audio input stream and output queue)
   - `MockGeminiLiveClient` (simulates setup, streaming audio/video, receiving transcriptions/audio responses)
5. Create Unit Tests (`Tests/AIEnglishTutorTests/`):
   - Test data models, JSON encoding/decoding for Gemini WebSocket messages.
   - Test mock services behavior.
6. Verify Build & Test:
   - Run `swift build` and `swift test` (or xcodebuild).
   - Ensure 0 compilation errors and 0 critical warnings.
   - Write a detailed `handoff.md` in `/Users/mac/Documents/GitHub/AI_English_Tutor/.agents/worker_m1/handoff.md` with build logs and test results.
