# Progress — AI English Tutor

## Current Status
Last visited: 2026-07-27T03:30:10Z

## Milestone Progress
- [ ] M1: Project Infra & Protocols (In Progress)
- [ ] M2: Keychain & Global Hotkeys (Planned)
- [ ] M3: ScreenCapture & AudioEngine (Planned)
- [ ] M4: Gemini Live Client (Planned)
- [ ] M5: App State & UI Layer (Planned)
- [ ] M6: Integration & E2E Verification (Planned)

## Iteration Status
Current iteration: 1 / 32

## Acceptance Criteria Checklist
- [ ] `swift build` / `xcodebuild build` succeeds with 0 errors and 0 critical warnings
- [ ] `swift test` / `xcodebuild test` succeeds with 100% unit tests passing
- [ ] Build output packaged into executable `.app` bundle
- [ ] Keychain service saves & retrieves API key securely
- [ ] GeminiLiveClient constructs WebSocket setup messages & VAD barge-in & reconnect retry x3
- [ ] ScreenCapture resizes/compresses mock frames to ≤1024px JPEG base64
- [ ] AudioEngine handles PCM16 16kHz input & 24kHz output playback queue
- [ ] Menu bar item and floating always-on-top window behave properly

## Work Log
- 2026-07-27T03:26:40Z: Created ORIGINAL_REQUEST.md, BRIEFING.md, PROJECT.md, and progress.md. Starting M1 dispatch.
- 2026-07-27T03:26:48Z: Dispatched worker_m1 (b6fc799f-4e0d-456f-a110-310a1c833438) for M1 Infra/Protocols/Mocks, and worker_e2e (add25d9e-e444-40a9-ac3a-6ac74d387427) for E2E Test Suite design.
- 2026-07-27T03:28:40Z: Worker E2E completed. Implemented 21 unit & E2E tests, TEST_INFRA.md, and TEST_READY.md.
- 2026-07-27T03:28:48Z: Dispatched Reviewers (reviewer_1, reviewer_2), Challenger (challenger_1), and Forensic Auditor (auditor_1).
- 2026-07-27T03:29:40Z: Reviewers & Challenger reported compilation errors and facade/dummy production services.
- 2026-07-27T03:34:07Z: Forensic Auditor issued VERDICT: INTEGRITY VIOLATION due to facade implementations, mock downcasts in AppViewModel, hardcoded INVALID test check, and missing task.receive() in WebSocket client. Milestone REJECTED.
- 2026-07-27T03:34:11Z: Forwarded full forensic audit evidence to Lead Remediation Worker (d0f5e044-033b-4694-9a6a-a69ef2bee5b6) for 100% genuine framework implementations (Carbon, ScreenCaptureKit, AVAudioEngine, URLSessionWebSocketTask, @MainActor VM, zero mock downcasts).
