# Original User Request for E2E Testing Track Worker

## 2026-07-27T03:26:48+07:00

<USER_REQUEST>
You are the E2E Testing Track Worker for the AI English Tutor macOS App project.

Working directory for metadata: /Users/mac/Documents/GitHub/AI_English_Tutor/.agents/worker_e2e_infra
Project root directory: /Users/mac/Documents/GitHub/AI_English_Tutor

Scope & Deliverables:
1. Design requirement-driven, opaque-box E2E test strategy based on /Users/mac/Documents/GitHub/AI_English_Tutor/ORIGINAL_REQUEST.md.
2. Create `TEST_INFRA.md` at project root detailing:
   - Test methodology (Category-Partition, BVA, Pairwise, Workload testing).
   - Feature inventory mapped to user requirements R1, R2, R3, R4.
   - Test Tiers definition:
     - Tier 1: Feature Coverage (Keychain, Hotkeys, ScreenCapture <=1024px JPEG, Audio 16kHz in / 24kHz out, Gemini Live setup/fallback/barge-in, Subtitle transcript export)
     - Tier 2: Boundary & Corner Cases (empty API key, invalid key format, frame resize boundary at exactly 1024px / >1024px, audio buffer overflow/underflow, WebSocket drop reconnect 3x)
     - Tier 3: Cross-Feature Interactions (Hotkeys + Audio mute, Barge-in + Audio queue flush, Screen capture stream + Gemini WebSocket payload)
     - Tier 4: Real-World Scenarios (Full conversation session flow, Mute -> Talk -> Barge-in -> Unmute -> Export transcript)
3. Set up unit/integration test structure in `Tests/AIEnglishTutorTests/E2ETests/` using dependency-injected mock services to verify full end-to-end workflow logic.
4. Execute `swift test` to verify the test suite builds and passes.
5. Create `TEST_READY.md` at project root summarizing test coverage and command to run E2E suite.
6. Write a detailed `handoff.md` in `/Users/mac/Documents/GitHub/AI_English_Tutor/.agents/worker_e2e_infra/handoff.md`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
</USER_REQUEST>
