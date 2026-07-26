# End-to-End Test Infrastructure & Test Strategy Specification
**Project:** AI English Tutor (Native macOS App)  
**Document Version:** 1.0.0  
**Target Environment:** macOS 14.0+ (Sonoma) / Swift 5.9+ / XCTest

---

## 1. Executive Summary & Strategy Overview

The **AI English Tutor** macOS application provides real-time voice-to-voice interaction powered by Google's Gemini Live API, desktop screen streaming via `ScreenCaptureKit`, real-time PCM audio input/output via `AVAudioEngine`, system-wide hotkey controls (`⌃⌥M` for mute toggle, `⌃⌥S` for session toggle), secure Keychain API key management, and live transcript rendering with export capabilities.

To ensure strict quality, real-time audio/video responsiveness, and robustness under edge/error conditions without reliance on external live network endpoints or physical AV hardware, this document defines an **opaque-box requirement-driven End-to-End (E2E) testing framework**.

---

## 2. Opaque-Box Test Methodology

Our E2E test strategy employs four established opaque-box software testing methodologies:

### 2.1 Category-Partition Method
Each feature input space is partitioned into discrete functional categories, value ranges, and system environmental states:
* **API Keys:** Valid, Empty (`""`), Invalid format (`"INVALID_KEY_123"`), Missing from Keychain.
* **Screen Resolution:** Sub-boundary (`800x600`), Exact boundary (`1024x768`), Exceeding boundary (`1920x1080`, `3840x2160`).
* **Audio Stream States:** Active speaking, Idle/Silence, Muted, Hardware Interrupted, Buffer Overflow/Underflow.
* **WebSocket Connection States:** Disconnected, Connecting, Active Session, Dropped (Retry #1..3), Unrecoverable Failure.

### 2.2 Boundary Value Analysis (BVA)
BVA focuses testing on critical system limits:
* **Screen Frame Width:** $W = 1023\text{px}$, $W = 1024\text{px}$ (exact threshold), $W = 1025\text{px}$. Max target is $\le 1024\text{px}$.
* **Audio Rates:** Input fixed at 16,000 Hz mono PCM16; Output fixed at 24,000 Hz PCM.
* **JPEG Compression:** Quality parameter $Q = 0.70$.
* **WebSocket Reconnect Limit:** Attempt counts $N = 1, 2, 3$ (successful reconnect threshold) vs $N = 4$ (max attempts exceeded error trigger).

### 2.3 Pairwise (All-Pairs) Testing
Evaluates combination matrices of concurrent feature states:
* [Session State: Active / Inactive] $\times$ [Mute State: Muted / Unmuted] $\times$ [AI Output: Playing / Silent] $\times$ [Screen Capture: Active / Inactive].

### 2.4 Workload & Real-World Stress Testing
Simulates high-throughput data streams:
* 1 frame-per-second continuous image base64 encoding & dispatch over WebSocket.
* Continuous 16kHz audio buffer chunking and 24kHz AI response playback stream queueing.
* Rapid sequential hotkey triggers (e.g., toggling mute 10 times in 1 second during active AI speech playback).

---

## 3. Feature Inventory & User Requirement Mapping

| Feature ID | Feature Description | Mapped Requirement | Verification Method |
| :--- | :--- | :--- | :--- |
| **F-01** | Keychain Secure Storage & Retrieval | **R1** (Req 19) | Unit & E2E Integration (`KeychainServiceProtocol`) |
| **F-02** | System-Wide Carbon Global Hotkeys (`⌃⌥M`, `⌃⌥S`) | **R1** (Req 18) | Mock Hotkey Event Dispatch & State Verification |
| **F-03** | Menu Bar & Floating Mini-Window State Management | **R1** (Req 17) | AppViewModel Window & Session State Verification |
| **F-04** | ScreenCaptureKit 1fps Frame Capture & Resize ($\le1024\text{px}$) | **R2** (Req 22, 24) | Image Resizing & Base64 Pipeline Integration |
| **F-05** | AudioEngine 16kHz Input & 24kHz Playback Queueing | **R3** (Req 27) | Audio Buffer Conversion & Queue Flushing |
| **F-06** | Gemini Live Client WebSocket Protocol & Model Fallback | **R3** (Req 28) | Mock Gemini Live Server Frame Parsing & Handshake |
| **F-07** | VAD Barge-in Interruption Handling | **R3** (Req 29) | Interruption Event & Playback Queue Flush Test |
| **F-08** | English Tutor Persona & Subtitle Transcript Export | **R4** (Req 32, 33) | Subtitle State History & `.txt` File Export Format |

---

## 4. E2E Test Tiers Definition

### Tier 1: Feature Coverage
Validates core functionality for every subsystem in nominal conditions:
1. **Keychain**: Save API key, retrieve API key, update key, delete key.
2. **Global Hotkeys**: Verify registration of `⌃⌥M` (mute) and `⌃⌥S` (session toggle) handlers.
3. **Screen Capture**: Verify frame processing resizes images to $\le 1024\text{px}$ width and outputs JPEG data (~0.7 quality).
4. **Audio Engine**: Verify PCM 16kHz mono audio input callback and 24kHz audio playback queueing.
5. **Gemini Live Client**: Verify WebSocket connection handshake, setup message creation with `gemini-3.1-flash-live`, audio chunk transmission, image base64 transmission, and fallback to `gemini-2.5-flash-native-audio-preview-12-2025` on model error.
6. **Transcript Export**: Verify accumulation of user/tutor transcripts and formatting for `.txt` file export.

### Tier 2: Boundary & Corner Cases
Validates system resilience against extreme parameters and errors:
1. **Empty / Invalid API Key**: Reject attempt to start session with empty (`""`) or malformed key strings.
2. **Screen Frame Boundary**: Verify image width of exact $1024\text{px}$ is preserved without upscaling, while $1920\text{px}$ is downscaled to exactly $1024\text{px}$.
3. **Audio Buffer Edge Cases**: Test empty buffer queueing (underflow protection) and large chunk injection (overflow protection).
4. **WebSocket Reconnect Threshold**: Simulate drop on 1st, 2nd, and 3rd attempt, verifying auto-reconnect up to 3 retries; verify failure emission on 4th consecutive drop.

### Tier 3: Cross-Feature Interactions
Validates state synchronization across multiple subsystems:
1. **Hotkey + Audio Mute**: Verify pressing `⌃⌥M` updates `AppViewModel.isMuted` and halts input microphone streaming in `AudioEngineService`.
2. **Barge-in + Audio Queue Flush**: Verify that when user speech is detected (VAD event or microphone activity), Gemini Live Client triggers `onInterrupted`, which immediately flushes `AudioEngineService` playback buffers.
3. **Screen Stream + WebSocket Dispatch**: Verify ScreenCapture frame callbacks continuously format images and send JPEG payloads over the active Gemini Live WebSocket connection.

### Tier 4: Real-World Scenarios
Simulates multi-step end-to-end user journeys:
1. **Complete Tutor Conversation Session**:
   - Save API key to Keychain.
   - Start session via Hotkey (`⌃⌥S`).
   - Stream microphone audio and screen captures to Gemini Live.
   - Receive AI tutor transcript and 24kHz audio chunks.
   - Trigger user interruption (Barge-in) -> verify AI playback stops immediately.
   - Mute mic (`⌃⌥M`), verify status update, unmute mic (`⌃⌥M`).
   - End session via Hotkey (`⌃⌥S`).
   - Export session transcript history to plain text `.txt`.

---

## 5. Dependency Injection & Test Infrastructure Architecture

To enable fast, deterministic, and 100% reproducible E2E tests in standard Xcode/SPM environments without physical AV devices or external internet access, all services are accessed via protocol interfaces:

```
                  +-------------------------+
                  |      AppViewModel       |
                  +------------+------------+
                               |
       +-----------------------+-----------------------+
       |           |           |           |           |
       v           v           v           v           v
  [Keychain]   [Hotkeys]   [ScreenCap]  [AudioEng] [GeminiLive]
  Protocol     Protocol    Protocol     Protocol   Protocol
       |           |           |           |           |
       v           v           v           v           v
  MockKeych    MockHotkey  MockScreen  MockAudio   MockGemini
```

Every mock service (`MockKeychainService`, `MockGlobalHotkeyService`, `MockScreenCaptureService`, `MockAudioEngineService`, `MockGeminiLiveClient`) maintains internal state, records invocation logs, and provides event simulation methods (e.g. `simulateServerTranscript()`, `simulateConnectionDrop()`, `simulateUserBargeIn()`).

---

## 6. Execution Command

Run the complete E2E test suite via Swift Package Manager:

```bash
swift test --filter E2ETests
```
