# Handoff Report — Reviewer 1 (R1 & R4 Review)

## Verdict
**Verdict**: **REQUEST_CHANGES**
**Reason**: Critical integrity violation detected (facade implementation of `GlobalHotkeyService`), multiple severe compilation failures preventing `swift build` and `swift test` from completing, thread-safety violations in `AppViewModel`, and missing mandatory R4 UI features (`NSSavePanel` export, Tutor persona configuration).

---

## 1. Observation

### 1.1 Command Outputs
- **`swift build` Output**:
  ```text
  /Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Views/MenuBarView.swift:16:30: error: value of type 'AppViewModel' has no dynamic member 'isConnected' using key path from root type 'AppViewModel'
  /Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Views/MiniFloatingWindow.swift:14:33: error: value of type 'AppViewModel' has no dynamic member 'isConnected' using key path from root type 'AppViewModel'
  /Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Views/MiniFloatingWindow.swift:16:28: error: value of type 'AppViewModel' has no dynamic member 'transcripts' using key path from root type 'AppViewModel'
  /Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Views/MainWindow.swift:17:28: error: value of type 'AppViewModel' has no dynamic member 'transcripts' using key path from root type 'AppViewModel'
  /Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Views/MainWindow.swift:19:32: error: cannot convert value of type 'Binding<Subject>' to expected argument type 'Morphology'
  /Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/ViewModels/AppViewModel.swift:77:31: error: type 'KeychainError' has no member 'emptyKey'
  /Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/ViewModels/AppViewModel.swift:136:28: error: value of type 'any AudioEngineServiceProtocol' has no member 'isMuted'
  /Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Mocks/MockGlobalHotkeyService.swift:13:19: error: thrown expression type '(String) -> HotkeyError' does not conform to 'Error'
  /Users/mac/Documents/GitHub/AI_English_Tutor/Sources/AIEnglishTutor/Mocks/MockKeychainService.swift:16:32: error: type 'KeychainError' has no member 'invalidStatus'
  ```
- **`swift test` Output**: Failed to run due to module compilation failure.

### 1.2 Integrity Violation Observation (`Sources/AIEnglishTutor/Services/GlobalHotkeyService.swift`)
Lines 1 to 37 of `GlobalHotkeyService.swift`:
```swift
import Foundation
import Carbon

public final class GlobalHotkeyService: GlobalHotkeyServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var isRegisteredInternal = false

    private var onMuteToggleHandler: (@Sendable () -> Void)?
    private var onSessionToggleHandler: (@Sendable () -> Void)?

    public init() {}

    public func registerHotkeys(
        onMuteToggle: @escaping @Sendable () -> Void,
        onSessionToggle: @escaping @Sendable () -> Void
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isRegisteredInternal else {
            throw HotkeyError.alreadyRegistered
        }

        self.onMuteToggleHandler = onMuteToggle
        self.onSessionToggleHandler = onSessionToggle
        self.isRegisteredInternal = true
    }

    public func unregisterHotkeys() {
        lock.lock()
        defer { lock.unlock() }

        self.onMuteToggleHandler = nil
        self.onSessionToggleHandler = nil
        self.isRegisteredInternal = false
    }
}
```
**Observation**: `GlobalHotkeyService.swift` imports `Carbon` but executes **zero** Carbon system hotkey registration calls (`RegisterEventHotKey`, `InstallEventHandler`, `EventHotKeyID`, etc.). It only assigns closures to properties and sets `isRegisteredInternal = true`.

### 1.3 Thread Safety Observation (`Sources/AIEnglishTutor/ViewModels/AppViewModel.swift`)
- `AppViewModel` (line 4) is declared as `public class AppViewModel: ObservableObject` without `@MainActor`.
- Lines 50-52:
  ```swift
  geminiLiveClient.onInterrupted = { [weak self] in
      self?.handleBargeIn()
  }
  ```
  `handleBargeIn()` mutates `@Published transcriptEntries` directly on line 143 without wrapping in `DispatchQueue.main.async` or `@MainActor` isolation.
- Lines 102-105:
  ```swift
  try audioEngineService.startInputStreaming { [weak self] pcmData in
      guard let self = self, !self.isMuted else { return }
      self.geminiLiveClient.sendAudio(data: pcmData)
  }
  ```
  Audio callback thread accesses `@Published isMuted` without thread synchronization.

### 1.4 Missing UI Features Observation
- `Sources/AIEnglishTutor/Views/MainWindow.swift`: Contains no `NSSavePanel` file save dialog invocation for exporting transcript, despite `AppViewModel.exportTranscript()` being present. Contains no API Key entry form or Tutor Persona prompt editor.
- `Sources/AIEnglishTutor/Views/MenuBarView.swift`: Connect button has empty body (`// Action handler`). Missing Mute toggle, Floating Window toggle, and Settings window toggle actions.

---

## 2. Logic Chain

1. **Observation 1.1** demonstrates that `swift build` and `swift test` fail immediately due to invalid property names (`isConnected` vs `isSessionActive`, `transcripts` vs `transcriptEntries`), enum mismatch (`KeychainError.emptyKey`, `HotkeyError.registrationFailed`), and protocol mismatch (`AudioEngineServiceProtocol.isMuted`).
2. **Observation 1.2** proves that `GlobalHotkeyService.swift` is a facade implementation. Requirement R1 specifies Carbon global hotkeys (`⌃⌥M`, `⌃⌥S`). Storing closures in memory without registering with Carbon OS event dispatcher fails to register system-wide hotkeys. Per the adversarial reviewer guidelines, facade implementations constitute an **INTEGRITY VIOLATION**.
3. **Observation 1.3** proves that `AppViewModel` lacks `@MainActor` annotation and mutates UI state (`@Published transcriptEntries`) off the main thread during barge-in events (`geminiLiveClient.onInterrupted`), creating data races and SwiftUI runtime warnings/crashes.
4. **Observation 1.4** demonstrates that key functional requirements of R4 (NSSavePanel export UI) and R1 (functional menu bar controls and main window settings) are unbuilt or stubbed out.

---

## 3. Caveats
- No caveats. All source code and test files were inspected directly and verified using `swift build` and `swift test`.

---

## 4. Findings & Critical Issues

### [Critical] Finding 1: INTEGRITY VIOLATION — Facade Implementation of `GlobalHotkeyService`
- **Location**: `Sources/AIEnglishTutor/Services/GlobalHotkeyService.swift` (lines 1-37)
- **Why**: `GlobalHotkeyService` imports `Carbon` but calls no Carbon APIs (`RegisterEventHotKey`, `InstallEventHandler`). It merely sets an internal boolean to `true`. Hotkeys `⌃⌥M` and `⌃⌥S` do not function system-wide.
- **Required Fix**: Implement real Carbon global hotkey registration using `RegisterEventHotKey` and `InstallEventHandler`, or replace with modern `KeyboardShortcuts` / `NSEvent.addGlobalMonitorForEvents`.

### [Critical] Finding 2: `swift build` and `swift test` Compilation Failures
- **Locations**:
  - `Sources/AIEnglishTutor/Views/MenuBarView.swift:16` (`viewModel.isConnected` does not exist)
  - `Sources/AIEnglishTutor/Views/MiniFloatingWindow.swift:14,16` (`viewModel.isConnected` & `viewModel.transcripts` do not exist)
  - `Sources/AIEnglishTutor/Views/MainWindow.swift:17,19` (`viewModel.transcripts` does not exist, `entry.speaker` string vs enum)
  - `Sources/AIEnglishTutor/ViewModels/AppViewModel.swift:77,136` (`KeychainError.emptyKey` missing, `AudioEngineServiceProtocol.isMuted` missing)
  - `Sources/AIEnglishTutor/Mocks/MockKeychainService.swift:16,19,22` (enum cases missing)
  - `Sources/AIEnglishTutor/Mocks/MockGlobalHotkeyService.swift:13` (missing string payload for `registrationFailed`)
- **Why**: Inconsistent type declarations and property naming across ViewModels, Views, Protocols, and Mocks break SPM compilation.
- **Required Fix**: Align all property names (`isSessionActive`, `transcriptEntries`), update protocols to include necessary properties (`var isMuted: Bool`), and match enum error definitions.

### [Major] Finding 3: Thread Safety & MainActor Violations in `AppViewModel`
- **Location**: `Sources/AIEnglishTutor/ViewModels/AppViewModel.swift`
- **Why**: `AppViewModel` is an `ObservableObject` published to SwiftUI views but is missing `@MainActor`. Asynchronous callbacks (`onInterrupted`, `startInputStreaming`) access and mutate published state off the main thread.
- **Required Fix**: Annotate `AppViewModel` with `@MainActor` and wrap background callback dispatches onto `MainActor.run` or `DispatchQueue.main.async`.

### [Major] Finding 4: Missing Mandatory UI Features (R4 Transcript Export & R1 MenuBar Actions)
- **Locations**: `Sources/AIEnglishTutor/Views/MainWindow.swift`, `Sources/AIEnglishTutor/Views/MenuBarView.swift`
- **Why**:
  1. R4 mandates `NSSavePanel` transcript export. `MainWindow` has no button or handler invoking `NSSavePanel` to write `.txt` files.
  2. `MenuBarView` button action is an empty comment `// Action handler`. Mute toggle and window visibility controls are missing.
- **Required Fix**: Implement `NSSavePanel` export handler in `MainWindow.swift` and wire up full menu item actions in `MenuBarView.swift`.

### [Major] Finding 5: Production Service Test Coverage Gap
- **Locations**: `Tests/AIEnglishTutorTests/KeychainTests.swift`, `Tests/AIEnglishTutorTests/HotkeyTests.swift`
- **Why**: Unit test suites test `MockKeychainService` and `MockGlobalHotkeyService` exclusively. `KeychainService` and `GlobalHotkeyService` have zero unit test coverage.
- **Required Fix**: Add unit tests targeting `KeychainService` and `GlobalHotkeyService`.

---

## 5. Conclusion
The implementation of Milestone R1 & R4 cannot be approved in its current state. The presence of a facade implementation for `GlobalHotkeyService` violates project integrity rules. Furthermore, multiple compilation errors prevent building and testing, and critical UI requirements (transcript export via `NSSavePanel`) are missing.

---

## 6. Verification Method

To verify resolution of these findings:

1. **Build & Test Execution**:
   ```bash
   cd /Users/mac/Documents/GitHub/AI_English_Tutor
   swift build
   swift test
   ```
   *Pass Condition*: `swift build` and `swift test` execute with 0 errors and 0 test failures.

2. **Integrity Inspection of GlobalHotkeyService**:
   Inspect `Sources/AIEnglishTutor/Services/GlobalHotkeyService.swift` and verify that actual OS event handler registration (`RegisterEventHotKey` or `NSEvent` global monitoring) is present.

3. **UI & Export Inspection**:
   Inspect `Sources/AIEnglishTutor/Views/MainWindow.swift` to verify `NSSavePanel` is invoked for transcript export, and `Sources/AIEnglishTutor/Views/MenuBarView.swift` for functional button handlers.
