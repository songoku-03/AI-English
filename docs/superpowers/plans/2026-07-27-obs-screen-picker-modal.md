# OBS-Style Screen Picker Modal & Permission Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement an OBS-Studio-style screen selection modal window with live display thumbnails, active permission checking with a 1-click System Settings button, and instant real-time live preview mapping.

**Architecture:** A new `ScreenPickerModal.swift` view will present a visual grid of all detected macOS displays with real-time thumbnail snapshots (generated via `CGDisplayCreateImage`). When the user clicks "Start Session", if screen capture permission is missing, a permission banner guides the user to System Settings. If permission is granted, the OBS-style screen picker sheet presents available monitors for explicit selection before streaming.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, ScreenCaptureKit, CoreGraphics.

## Global Constraints
- Target Platform: macOS 14.0+
- Zero external third-party dependencies
- 100% unit test passing rate

---

### Task 1: Enhance Display Discovery & Permission Utilities in ScreenCaptureService

**Files:**
- Modify: `Sources/AIEnglishTutor/Services/ScreenCaptureServiceProtocol.swift`
- Modify: `Sources/AIEnglishTutor/Services/ScreenCaptureService.swift`
- Modify: `Sources/AIEnglishTutor/Mocks/MockScreenCaptureService.swift`
- Modify: `Tests/AIEnglishTutorTests/ScreenCaptureTests.swift`

**Interfaces:**
- Produces: `DisplayInfo` with thumbnail `NSImage?`, `openScreenCaptureSettings()` method.

- [ ] **Step 1: Update DisplayInfo struct to support thumbnail previews**

In `ScreenCaptureServiceProtocol.swift`:
Add optional thumbnail or snapshot data property `public var thumbnail: NSImage?` to `DisplayInfo`.

- [ ] **Step 2: Implement display snapshot generation in ScreenCaptureService**

In `ScreenCaptureService.swift`:
Implement display thumbnail generation using `CGDisplayCreateImage(displayID)` for each detected `SCDisplay`, creating a 320px thumbnail for visual screen selection.
Implement `openScreenCaptureSettings()` using `NSWorkspace.shared.open(...)` pointing to `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`.

- [ ] **Step 3: Verify with swift test**

Run: `swift test`
Expected: PASS

---

### Task 2: Create OBS-Style ScreenPickerModal View & Permission Banner

**Files:**
- Create: `Sources/AIEnglishTutor/Views/ScreenPickerModal.swift`
- Modify: `Sources/AIEnglishTutor/ViewModels/AppViewModel.swift`
- Modify: `Sources/AIEnglishTutor/Views/MainWindow.swift`

- [ ] **Step 1: Create ScreenPickerModal.swift**

Build an OBS-style modal view:
- Grid layout showing all connected monitors.
- Highlighting selected screen card with green/blue border.
- Displays thumbnail snapshot of each display.
- Action buttons: "Start Sharing Selected Screen" and "Cancel".

- [ ] **Step 2: Update AppViewModel & MainWindow**

In `AppViewModel`:
- Add `@Published public var showScreenPickerModal: Bool = false`
- Add `@Published public var hasScreenPermission: Bool = true`
- Trigger modal when starting session.

In `MainWindow.swift`:
- Attach `.sheet(isPresented: $viewModel.showScreenPickerModal)` to present `ScreenPickerModal`.
- Display permission warning banner when `!viewModel.hasScreenPermission` with 1-click System Settings button.

- [ ] **Step 3: Run all unit tests**

Run: `swift test`
Expected: All tests PASS

- [ ] **Step 4: Build release binary & re-launch application**

Run: `swift build -c release && cp .build/release/AIEnglishTutorApp "build/AI English Tutor.app/Contents/MacOS/AI English Tutor" && open "build/AI English Tutor.app"`
