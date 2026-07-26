## 2026-07-27T03:29:53Z
You are the Lead Implementation & Remediation Worker for the AI English Tutor macOS App project.

Working directory for metadata: /Users/mac/Documents/GitHub/AI_English_Tutor/.agents/worker_remediation_1
Project root directory: /Users/mac/Documents/GitHub/AI_English_Tutor

CRITICAL REMEDIATION REQUIREMENTS:
You must replace all empty facade/dummy implementations with FULL, GENUINE PRODUCTION CODE and fix all compilation errors.

Tasks:
1. Fix Compilation Errors & Duplicate Declarations:
   - Eliminate duplicate protocol and enum definitions across `*Protocol.swift` and `*.swift` files (keep protocols/enums in `*Protocol.swift` or single location).
   - Fix error throwing syntax in `MockGlobalHotkeyService.swift` (`enum HotkeyError: Error`).
   - Add missing properties and methods to `AppViewModel` (`@Published var isConnected: Bool`, `@Published var isMuted: Bool`, `@Published var isCapturing: Bool`, `@Published var transcripts: [TranscriptEntry]`, `@Published var liveSubtitle: String`, `startSession()`, `stopSession()`, `toggleMute()`, `exportTranscript()`, `saveAPIKey()`).

2. Production Service Implementations (NO DUMMY CODE, NO EMPTY COMMENTS):
   - `KeychainService.swift`: Implement Keychain storage using macOS `Security` framework (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`, `SecItemUpdate`) storing service "com.aienglishtutor.apikey".
   - `GlobalHotkeyService.swift`: Implement system-wide hotkeys using macOS `Carbon` framework (`RegisterEventHotKey`, `InstallEventHandler`, `kEventClassKeyboard`, `kEventHotKeyPressed`). Register `⌃⌥M` (Option+Control+M, keyCode 46) for mute toggle and `⌃⌥S` (Option+Control+S, keyCode 1) for session start/stop.
   - `ScreenCaptureService.swift`: Implement real `ScreenCaptureKit` (`SCShareableContent`, `SCStream`, `SCStreamOutput`), 1fps capture interval, frame resizing to <=1024px width (preserving aspect ratio using NSImage/CGImage/CoreGraphics), JPEG compression (~0.7), and base64 encoding. Add Screen Recording permission check (`CGPreflightScreenCaptureAccess()`).
   - `AudioEngineService.swift`: Implement real `AVAudioEngine`. Configure input node tap for microphone audio, convert to 16kHz PCM16 mono (`AVAudioConverter`), stream base64 PCM data. Configure output `AVAudioPlayerNode` queue for 24kHz audio playback. Implement VAD barge-in (`interruptPlayback()`) that immediately stops `AVAudioPlayerNode` playback and flushes the queue when user input is detected.
   - `GeminiLiveClient.swift`: Implement real `URLSessionWebSocketTask` connection to Google Gemini Live WebSocket API (`wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=...`). Primary model: `gemini-3.1-flash-live`, fallback model on connection error: `gemini-2.5-flash-native-audio-preview-12-2025`. Construct correct JSON setup message containing English Tutor system prompt, 24kHz audio output config, voice selection. Handle incoming WebSocket text/audio frames, dispatch live subtitles. Implement automatic reconnect (up to 3 retries) with exponential backoff on connection drop.
   - `AppViewModel.swift`: Wire all production & mock services cleanly with dependency injection.
   - `Views/`: Ensure `MenuBarView.swift` (NSStatusItem menu), `MiniFloatingWindow.swift` (`NSWindow.level = .floating`), and `MainWindow.swift` compile and bind seamlessly to `AppViewModel`.

3. Genuine Unit Tests (`Tests/AIEnglishTutorTests/`):
   - Unit test `KeychainService` logic.
   - Unit test `ScreenCaptureService` image resizing and compression helper functions.
   - Unit test `AudioEngineService` sample conversion format helpers and queue management.
   - Unit test `GeminiLiveClient` WebSocket JSON message encoding/decoding and model fallback logic.
   - Unit test `AppViewModel` state transitions, VAD barge-in flow, and transcript export format.
   - Unit test mock services and E2E integration test suite.

4. Build, Test & Package Verification:
   - Run `swift build`. Must succeed with 0 errors and 0 critical warnings.
   - Run `swift test`. Must pass 100% of unit & E2E tests.
   - Package application into a valid executable binary / `.app` bundle structure under `.build/` or `./build/AIEnglishTutor.app`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or leave empty stub methods. A Forensic Auditor will independently verify your work.

Write your handoff report to `/Users/mac/Documents/GitHub/AI_English_Tutor/.agents/worker_remediation_1/handoff.md`.
