# Project: AI English Tutor (Native macOS App)

## Architecture
Native macOS application (macOS 14 Sonoma+) written in 100% Swift 5.9+ using SwiftUI and AppKit.

The application enables real-time voice-to-voice interaction with Google Gemini Live API (`gemini-3.1-flash-live` with fallback to `gemini-2.5-flash-native-audio-preview-12-2025`), live screen capture via `ScreenCaptureKit`, real-time PCM audio input/output via `AVAudioEngine`, system-wide global hotkeys (`⌃⌥M` for mute, `⌃⌥S` for session start/stop), secure Keychain API key storage, and a dual-window UI architecture (Menu Bar Status Item, Floating Always-on-Top Mini Window, and Setup/Transcript Window with `.txt` export).

### Modular Architecture & Dependency Injection
To ensure 100% testability without live microphone, camera/screen, or network connection, every hardware/network service is abstracted behind Swift protocols:

1. **Keychain**: `KeychainServiceProtocol` -> `KeychainService` & `MockKeychainService`
2. **Global Hotkeys**: `GlobalHotkeyServiceProtocol` -> `GlobalHotkeyService` & `MockGlobalHotkeyService`
3. **Screen Capture**: `ScreenCaptureServiceProtocol` -> `ScreenCaptureService` (`SCStream`, `SCShareableContent` 1fps <=1024px JPEG base64) & `MockScreenCaptureService`
4. **Audio Engine**: `AudioEngineServiceProtocol` -> `AudioEngineService` (`AVAudioEngine` PCM16 16kHz mono in, 24kHz out, VAD barge-in) & `MockAudioEngineService`
5. **Gemini Live Client**: `GeminiLiveClientProtocol` -> `GeminiLiveClient` (`URLSessionWebSocketTask`, setup messages, retry x3, VAD handling) & `MockGeminiLiveClient`
6. **App State**: `AppViewModel` (Coordinates services, manages subtitles, live audio/video state, transcript history)

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Project Infra & Protocols | SPM / Xcode structure, core data models, protocols, mock services, test runner harness | None | PLANNED |
| 2 | Keychain & Global Hotkeys | Keychain secure API key storage, Carbon global hotkeys (`⌃⌥M`, `⌃⌥S`) | M1 | PLANNED |
| 3 | ScreenCapture & AudioEngine | ScreenCaptureKit 1fps JPEG stream, AVAudioEngine PCM16 16kHz in / 24kHz out queuing, barge-in | M1 | PLANNED |
| 4 | Gemini Live Client | WebSocket URLSession setup, gemini-3.1-flash-live + fallback, VAD barge-in, retry x3 | M1 | PLANNED |
| 5 | App State & UI Layer | StatusItem Menu Bar, floating always-on-top window, Setup/Transcript window, export .txt | M1, M2, M3, M4 | PLANNED |
| 6 | E2E Verification & App Bundling | 100% unit tests passing, zero errors/warnings, executable .app build | M1..M5 | PLANNED |

## Interface Contracts
- `KeychainServiceProtocol`: `func save(key: String, value: String) throws`, `func retrieve(key: String) throws -> String?`, `func delete(key: String) throws`
- `GlobalHotkeyServiceProtocol`: `func registerHotkeys(onMuteToggle: @escaping () -> Void, onSessionToggle: @escaping () -> Void) throws`, `func unregisterHotkeys()`
- `ScreenCaptureServiceProtocol`: `func startCapture(onFrame: @escaping (Data) -> Void) async throws`, `func stopCapture()`, `func checkPermission() -> Bool`
- `AudioEngineServiceProtocol`: `func startInputStreaming(onPCMData: @escaping (Data) -> Void) throws`, `func playAudioChunk(data: Data)`, `func stopAudio()`, `func interruptPlayback()`
- `GeminiLiveClientProtocol`: `func connect(apiKey: String) async throws`, `func sendAudio(data: Data)`, `func sendImage(base64JPEG: String)`, `func disconnect()`, `var onTranscript: ((String, String) -> Void)?`

## Code Layout
```
AI_English_Tutor/
├── Package.swift
├── Sources/
│   └── AIEnglishTutor/
│       ├── Main.swift
│       ├── Models/
│       │   ├── AppConfig.swift
│       │   ├── TranscriptEntry.swift
│       │   └── GeminiMessage.swift
│       ├── Services/
│       │   ├── KeychainService.swift
│       │   ├── GlobalHotkeyService.swift
│       │   ├── ScreenCaptureService.swift
│       │   ├── AudioEngineService.swift
│       │   └── GeminiLiveClient.swift
│       ├── Mocks/
│       │   ├── MockKeychainService.swift
│       │   ├── MockGlobalHotkeyService.swift
│       │   ├── MockScreenCaptureService.swift
│       │   ├── MockAudioEngineService.swift
│       │   └── MockGeminiLiveClient.swift
│       ├── ViewModels/
│       │   └── AppViewModel.swift
│       └── Views/
│           ├── MenuBarView.swift
│           ├── MiniFloatingWindow.swift
│           └── MainWindow.swift
└── Tests/
    └── AIEnglishTutorTests/
        ├── KeychainTests.swift
        ├── HotkeyTests.swift
        ├── ScreenCaptureTests.swift
        ├── AudioEngineTests.swift
        ├── GeminiLiveClientTests.swift
        ├── ViewModelTests.swift
        └── IntegrationTests.swift
```
