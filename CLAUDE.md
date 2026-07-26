# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI English Tutor is a native macOS app (macOS 14+, Swift 5.9+, SwiftUI + AppKit, Swift Package Manager) that provides real-time voice-to-voice English tutoring via the Google Gemini Live API over WebSocket, with live screen capture (ScreenCaptureKit), real-time PCM audio (AVAudioEngine), global hotkeys (`⌃⌥M` mute, `⌃⌥S` session toggle), and Keychain-stored API keys.

## Commands

```bash
swift build                                  # Debug build
swift build -c release                       # Release build
swift test                                   # Run all tests
swift test --filter KeychainTests            # Run one test class
swift test --filter KeychainTests/testSaveAndRetrieve   # Run one test method
swift run AIEnglishTutorApp                  # Run the app directly
```

Package as a `.app` bundle:

```bash
swift build -c release --product AIEnglishTutorApp
mkdir -p "build/AI English Tutor.app/Contents/MacOS"
cp .build/release/AIEnglishTutorApp "build/AI English Tutor.app/Contents/MacOS/AI English Tutor"
```

## Architecture

Two SPM targets under `Sources/`:

- **`AIEnglishTutor`** (library) — all app logic: `Models/`, `Services/`, `ViewModels/`, `Views/`, and `Mocks/`.
- **`AIEnglishTutorApp`** (executable) — only the `@main` entry point (`main.swift`), which depends on the library. Keeping logic in the library is what makes it testable; new code belongs in the library target.

### Dependency injection via service protocols

Every hardware/network dependency is abstracted behind a protocol with a real implementation and a mock, so the entire test suite runs with no microphone, screen-recording permission, or network:

| Protocol | Real | Purpose |
|---|---|---|
| `KeychainServiceProtocol` | `KeychainService` | API key storage |
| `GlobalHotkeyServiceProtocol` | `GlobalHotkeyService` | Carbon global hotkeys |
| `ScreenCaptureServiceProtocol` | `ScreenCaptureService` | SCStream 1fps, ≤1024px JPEG → base64 |
| `AudioEngineServiceProtocol` | `AudioEngineService` | PCM16 16kHz mono in / 24kHz out, VAD barge-in |
| `GeminiLiveClientProtocol` | `GeminiLiveClient` | URLSessionWebSocketTask, model fallback, retry ×3 |

Mocks live in `Sources/AIEnglishTutor/Mocks/` (inside the library target, not the test target) so both tests and previews can use them. When adding a new service, follow this pattern: protocol + real implementation + mock.

### State management

`AppViewModel` (in `ViewModels/`) is the single coordinator: it wires all services together, owns session state, subtitles/transcript history, session persistence (`SessionStorageService` / `SessionRecord`), and quiz generation (`QuizGeneratorService`). Views (`MainWindow`, `MenuBarView`, `MiniFloatingWindow`, `SettingsView`, `HistoryView`, `DailyQuizView`, `ScreenPickerModal`) render from it.

The UI is dual-window: an `NSStatusItem` menu bar presence plus a floating always-on-top mini window, alongside the main setup/transcript window (with `.txt` export).

### Gemini Live specifics

Primary model `gemini-3.1-flash-live` with fallback to `gemini-2.5-flash-native-audio-preview-12-2025`. Audio input is fixed at 16kHz mono PCM16, output at 24kHz PCM. Barge-in: when the user speaks during AI playback, the playback queue is flushed (`interruptPlayback()`). WebSocket reconnects retry up to 3 times before surfacing an error.

### Tests

`Tests/AIEnglishTutorTests/` uses XCTest with per-service test files plus `IntegrationTests.swift` and tiered E2E suites in `E2ETests/` (feature coverage → boundary/corner cases → cross-feature interaction → real-world scenarios). `XCTestCompat.swift` and `TestBox` provide test-suite stability helpers. Test strategy and boundary values (e.g. the 1024px frame threshold, reconnect attempt limits) are documented in `TEST_INFRA.md`.

## Swift Best Practices (MANDATORY)

**Before writing or modifying ANY Swift code in this repository, you MUST invoke the `swift-best-practices` skill** ([.claude/skills/swift-best-practices/SKILL.md](.claude/skills/swift-best-practices/SKILL.md)) and follow its rules. This is not optional guidance — code that violates the skill's rules must not be committed. Run `/init` at the start of a session to load it up front.

The skill is the single source of the project-adapted rules (Lickability Swift best practices). Escalation order on anything it doesn't cover:

1. **Fuller quick reference:** [docs/swift-best-practices.md](docs/swift-best-practices.md) (same rules with explanations; UIKit/Interface Builder sections do not apply here).
2. **Authoritative source (verbatim copy from https://github.com/Lickability/swift-best-practices):** [docs/lickability-swift-best-practices/CombinedDocument.md](docs/lickability-swift-best-practices/CombinedDocument.md). On any conflict, this document wins.
3. **Lint config:** [docs/lickability-swift-best-practices/swiftlint.yml](docs/lickability-swift-best-practices/swiftlint.yml) — Lickability's SwiftLint configuration, kept for reference/adoption.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **AI-English** (1177 symbols, 4140 relationships, 29 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/AI-English/context` | Codebase overview, check index freshness |
| `gitnexus://repo/AI-English/clusters` | All functional areas |
| `gitnexus://repo/AI-English/processes` | All execution flows |
| `gitnexus://repo/AI-English/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
