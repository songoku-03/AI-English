# Challenger Handoff Report — AI English Tutor Project

**Agent**: Challenger 1 (EMPIRICAL CHALLENGER)  
**Date**: 2026-07-27  
**Working Directory**: `/Users/mac/Documents/GitHub/AI_English_Tutor/.agents/challenger_1`  
**Target Repository**: `/Users/mac/Documents/GitHub/AI_English_Tutor`  

---

## 1. Observation

### Command Executed
```bash
swift test
```
**Result**: Build Failed (Exit Code 1)  
**Verbatim Compiler Errors**:
```
/Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Views/MainWindow.swift:16:18: error: referencing subscript 'subscript(dynamicMember:)' requires wrapper 'ObservedObject<AppViewModel>.Wrapper'
16 |             List(viewModel.transcripts) { entry in

/Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Views/MenuBarView.swift:15:30: error: value of type 'AppViewModel' has no dynamic member 'isConnected' using key path from root type 'AppViewModel'
15 |             Button(viewModel.isConnected ? "Disconnect" : "Connect") {

/Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Views/MiniFloatingWindow.swift:13:33: error: value of type 'AppViewModel' has no dynamic member 'isConnected' using key path from root type 'AppViewModel'
13 |                 .fill(viewModel.isConnected ? Color.green : Color.gray)
```

### Empirical Test Harness Execution
Command executed: `swift /Users/mac/Documents/GitHub/AI_English_Tutor/.agents/challenger_1/run_verification.swift`  
**Result Summary**: Total Tests: 14 | Passed: 4 | Failed: 10

---

## 2. Challenge Summary

**Overall Risk Assessment**: **CRITICAL**

The production codebase in `Sources/AIEnglishTutor/` contains major compilation errors and stubbed implementations for core requirements (Audio Engine, Screen Capture Resizing, WebSocket Client, and VAD Barge-in). While unit tests in `Tests/AIEnglishTutorTests/` pass against mock objects, the real service implementations are incomplete, causing the package to fail compilation and preventing `swift test` from running.

---

## 3. Specific Findings & Challenges

### [Critical] Challenge 1: Package Compilation Failure & Protocol/View Mismatches

- **Files**: 
  - `Sources/AIEnglishTutor/Views/MainWindow.swift:16`
  - `Sources/AIEnglishTutor/Views/MenuBarView.swift:15`
  - `Sources/AIEnglishTutor/Views/MiniFloatingWindow.swift:13,15`
  - `Sources/AIEnglishTutor/ViewModels/AppViewModel.swift:50,109`
  - `Sources/AIEnglishTutor/Services/GeminiLiveClientProtocol.swift`
  - `Sources/AIEnglishTutor/Services/ScreenCaptureServiceProtocol.swift`

- **Observed Behavior**:
  1. `MainWindow.swift` accesses `viewModel.transcripts`, but `AppViewModel` declares `@Published public var transcriptEntries: [TranscriptEntry]`.
  2. `MenuBarView.swift` and `MiniFloatingWindow.swift` access `viewModel.isConnected`, but `AppViewModel` declares `@Published public var isSessionActive: Bool`.
  3. `AppViewModel.swift` line 50 attempts `geminiLiveClient.onInterrupted = ...`, but `onInterrupted` is missing from `GeminiLiveClientProtocol` (only exists in `MockGeminiLiveClient`).
  4. `AppViewModel.swift` line 109 calls `screenCaptureService.resizeAndCompress(...)`, but `resizeAndCompress` is missing from `ScreenCaptureServiceProtocol` and `ScreenCaptureService` (only exists in `MockScreenCaptureService`).

- **Impact**: `swift test` fails immediately. The application target cannot be built or run.

---

### [Critical] Challenge 2: Missing Image Scaling Implementation & Binary Payload Failure

- **Files**:
  - `Sources/AIEnglishTutor/Services/ScreenCaptureService.swift`
  - `Sources/AIEnglishTutor/Mocks/MockScreenCaptureService.swift:36-51`

- **Observed Behavior**:
  1. `ScreenCaptureService.swift` contains no image scaling, cropping, or CoreGraphics/CoreImage JPEG compression logic.
  2. In `MockScreenCaptureService.swift`, `resizeAndCompress` parses mock text strings like `"FRAME_1920_1080"`. When actual binary image data (e.g. JPEG bytes from ScreenCaptureKit) is passed:
     ```swift
     if let str = String(data: frameData, encoding: .utf8), str.contains("FRAME_") { ... }
     ```
     `String(data:encoding:)` returns `nil`. `inputWidth` defaults to `maxWidth` (1024.0), and the method returns ASCII string `"PROCESSED_FRAME_1024_0.7"`.

- **Blast Radius**: Real screen capture frames sent to Gemini API will fail because binary image data is replaced by plain text strings rather than resized JPEG image bytes.

---

### [Critical] Challenge 3: Missing Audio Sample Rate Conversion & Audio Playback Stubs

- **Files**:
  - `Sources/AIEnglishTutor/Services/AudioEngineService.swift:19-22,32-35`

- **Observed Behavior**:
  1. `AudioEngineService.swift` contains no `AVAudioEngine` setup, input node tap, or `AVAudioConverter` resampling logic.
  2. Native macOS microphone hardware captures audio at 44.1kHz or 48kHz float32. Gemini Live API requires PCM16 16kHz mono. No converter exists to downsample audio.
  3. `playAudioChunk(data: Data)` (line 19) and `interruptPlayback()` (line 32) are **empty stubs** containing 0 lines of operational code:
     ```swift
     public func playAudioChunk(data: Data) {
         lock.lock()
         defer { lock.unlock() }
     }
     ```

- **Blast Radius**: The app cannot stream valid 16kHz audio to Gemini Live or play back 24kHz response audio over speakers.

---

### [Critical] Challenge 4: VAD Barge-in & Playback Queue Flushing Deficiencies

- **Files**:
  - `Sources/AIEnglishTutor/Services/AudioEngineService.swift:32`
  - `Sources/AIEnglishTutor/ViewModels/AppViewModel.swift:140-144`

- **Observed Behavior**:
  1. In `AppViewModel.swift`, `handleBargeIn()` invokes `audioEngineService.interruptPlayback()`.
  2. `AudioEngineService.interruptPlayback()` is an empty stub in the real service implementation. It does not stop audio units or clear buffers.
  3. `AppViewModel.swift` lacks local Voice Activity Detection (VAD) or energy analysis on incoming mic buffers to trigger immediate barge-in when the user speaks while AI playback is active.

- **Blast Radius**: When a user attempts to interrupt the AI tutor by speaking, active AI audio playback continues uninterrupted in production.

---

### [High] Challenge 5: Gemini Live WebSocket Protocol & Setup Message Vulnerabilities

- **Files**:
  - `Sources/AIEnglishTutor/Services/GeminiLiveClient.swift:15-24`
  - `Sources/AIEnglishTutor/Models/GeminiMessage.swift:3-53`
  - `Sources/AIEnglishTutor/Models/AppConfig.swift:12-13`
  - `Sources/AIEnglishTutor/Mocks/MockGeminiLiveClient.swift:64-73`

- **Observed Behavior**:
  1. `GeminiLiveClient.swift` is a stub. `connect(apiKey:)` does not instantiate `URLSessionWebSocketTask` or open a WebSocket connection to `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent`.
  2. Model string in `AppConfig.swift` is `"gemini-3.1-flash-live"`. Gemini API WebSocket setup requires model names prefixed with `models/` (e.g. `models/gemini-2.0-flash-exp`).
  3. Reconnect retry limit is implemented in `MockGeminiLiveClient.swift` with `maxRetriesBeforeFail = 3`. Drops 1..3 succeed, drop 4 throws `maxReconnectAttemptsExceeded`. However, `reconnectAttempts` state persists after error unless `connect()` is re-invoked.
  4. Real service `GeminiLiveClient.swift` has zero retry logic (0 retries implemented vs requirement of exactly 3 retries).

---

## 4. Stress Test Results Summary

| Scenario | Expected Behavior | Actual Behavior | Result |
|---|---|---|---|
| `swift test` build check | Package compiles and executes tests | Fails with 6 compilation errors in Views & ViewModel | ❌ FAIL |
| Binary JPEG Frame scaling (>1024px) | Resizes CGImage to max 1024px width, preserves aspect ratio, outputs JPEG | UTF-8 parsing fails on binary data, defaults width, returns text `"PROCESSED_FRAME_..."` | ❌ FAIL |
| Mic Input Downsampling (48kHz -> 16kHz PCM16) | Resamples mic stream to 16,000 Hz 16-bit mono | Real service is empty stub; no resampling occurs | ❌ FAIL |
| 24kHz Audio Response Playback | Queues and plays 24kHz PCM audio on speaker output | Real service `playAudioChunk` is an empty stub | ❌ FAIL |
| VAD Barge-in Interruption | Speech input flushes audio queue immediately | Real service `interruptPlayback` is an empty stub | ❌ FAIL |
| Gemini Setup JSON Structure | Encodes `setup` with `model`, `generationConfig`, `systemInstruction` | Struct schema matches format; model name missing `models/` prefix | ⚠️ PARTIAL |
| Reconnect Retry Limit | Retries reconnect up to 3 times; fails on 4th drop | Mock implements 3-retry limit correctly; real service has 0 retry logic | ⚠️ PARTIAL (Mock Pass / Real Fail) |

---

## 5. Logic Chain

1. **Observation**: Executing `swift test` produced compiler errors in `MainWindow.swift`, `MenuBarView.swift`, and `MiniFloatingWindow.swift` due to symbol name mismatches (`transcripts` vs `transcriptEntries`, `isConnected` vs `isSessionActive`).
2. **Logic Step 1**: The codebase fails at step 0 (compilation) because view files were updated or written with different property names than those defined in `AppViewModel.swift`.
3. **Observation**: `AppViewModel.swift` references `geminiLiveClient.onInterrupted` and `screenCaptureService.resizeAndCompress(...)`.
4. **Logic Step 2**: Neither `GeminiLiveClientProtocol` nor `ScreenCaptureServiceProtocol` declares these members. They exist only on `MockGeminiLiveClient` and `MockScreenCaptureService`. Thus, dependency injection with real services fails to compile.
5. **Observation**: Inspecting `AudioEngineService.swift`, `ScreenCaptureService.swift`, and `GeminiLiveClient.swift` revealed 0 lines of functional AVAudioEngine, ScreenCaptureKit, or URLSessionWebSocketTask code.
6. **Logic Step 3**: The unit tests in `Tests/AIEnglishTutorTests/` pass only because they execute against mock objects. The real implementation services are unbuilt stubs.
7. **Conclusion**: The codebase requires fixing symbol mismatches and implementing the real hardware/network services before it can pass verification or run as a macOS application.

---

## 6. Caveats

- Physical AV Hardware Testing: Tests were conducted using automated empirical scripts (`run_verification.swift`) and static AST analysis. Physical microphone capture and screen recording permission prompts on macOS 14 Sonoma were not tested on hardware devices.
- Network Connectivity: Real Gemini Live API endpoint connection was not tested with a live API key due to offline test isolation requirements.

---

## 7. Conclusion & Recommendations

The codebase fails empirical verification due to **10 failed checks out of 14 assertions**.

### Actionable Next Steps for Engineering Team:
1. **Fix Symbol Mismatches in Views & Protocols**:
   - Rename `viewModel.transcripts` to `viewModel.transcriptEntries` in `MainWindow.swift` and `MiniFloatingWindow.swift`.
   - Rename `viewModel.isConnected` to `viewModel.isSessionActive` in `MenuBarView.swift` and `MiniFloatingWindow.swift`.
   - Add `var onInterrupted: (() -> Void)? { get set }` to `GeminiLiveClientProtocol`.
   - Add `func resizeAndCompress(frameData: Data, maxWidth: CGFloat, compressionQuality: CGFloat) -> Data` to `ScreenCaptureServiceProtocol`.
2. **Implement Core Service Functionality**:
   - `AudioEngineService`: Implement `AVAudioEngine` tap for 16kHz PCM16 mono recording and 24kHz PCM audio playback queue with buffer flush on `interruptPlayback()`.
   - `ScreenCaptureService`: Implement `ScreenCaptureKit` stream capture and CoreGraphics image scaling for width > 1024px.
   - `GeminiLiveClient`: Implement `URLSessionWebSocketTask` connection, setup message JSON dispatch with `models/` prefix, and 3-retry auto-reconnect logic.

---

## 8. Verification Method

To independently verify these findings:

1. **Run baseline Swift test**:
   ```bash
   swift test
   ```
   *Expected result*: Build failure due to symbol errors in `MainWindow.swift`, `MenuBarView.swift`, and `MiniFloatingWindow.swift`.

2. **Run Empirical Verification Script**:
   ```bash
   swift /Users/mac/Documents/GitHub/AI_English_Tutor/.agents/challenger_1/run_verification.swift
   ```
   *Expected result*: Detailed output showing 10 failed assertions across Views, Image Scaling, Audio Engine, VAD Barge-in, and WebSocket client.
