# Session History, Daily Quiz & Performance Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement automatic session recording, interactive daily review quiz (for past errors), performance optimizations (frame deduplication & low CPU buffer management), and a modern macOS 4-Tab Navigation UI.

**Architecture:** Session records with extracted errors/vocabulary will be auto-saved as JSON files under `~/Library/Application Support/AIEnglishTutor/Sessions/`. A dedicated `QuizGeneratorService` will parse errors into interactive quiz questions. `ScreenCaptureService` will utilize frame hashing to skip duplicate static screen frames. `MainWindow` will use SwiftUI `TabView` with 4 tabs (Live Tutor, History, Daily Quiz, Settings).

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, CryptoKit (SHA256 frame hashing), ScreenCaptureKit, Foundation.

## Global Constraints
- Target Platform: macOS 14.0+
- Swift Version: 5.9+
- Zero external third-party dependencies (pure SPM & Apple SDKs)
- 100% test passing rate

---

### Task 1: Create SessionRecord, ExtractedErrorItem, and QuizQuestion Models

**Files:**
- Create: `Sources/AIEnglishTutor/Models/SessionRecord.swift`
- Modify: `Tests/AIEnglishTutorTests/ModelTests.swift`

**Interfaces:**
- Produces: `SessionRecord`, `ExtractedErrorItem`, `QuizQuestion` struct definitions.

- [ ] **Step 1: Write failing unit test for SessionRecord JSON encoding/decoding**

```swift
// In Tests/AIEnglishTutorTests/ModelTests.swift
func testSessionRecordEncoding() throws {
    let errorItem = ExtractedErrorItem(
        originalSentence: "He go to school yesterday.",
        correctedSentence: "He went to school yesterday.",
        explanation: "Use past tense 'went' for yesterday.",
        category: "Grammar"
    )
    let record = SessionRecord(
        id: UUID(),
        date: Date(),
        durationSeconds: 120,
        transcripts: [TranscriptEntry(speaker: "Learner", text: "He go to school yesterday.")],
        extractedErrors: [errorItem]
    )
    let encoder = JSONEncoder()
    let data = try encoder.encode(record)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(SessionRecord.self, from: data)
    XCTAssertEqual(decoded.extractedErrors.count, 1)
    XCTAssertEqual(decoded.extractedErrors.first?.correctedSentence, "He went to school yesterday.")
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter ModelTests`
Expected: FAIL due to missing `SessionRecord` and `ExtractedErrorItem`

- [ ] **Step 3: Implement SessionRecord model**

Create `Sources/AIEnglishTutor/Models/SessionRecord.swift`:
```swift
import Foundation

public struct ExtractedErrorItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let originalSentence: String
    public let correctedSentence: String
    public let explanation: String
    public let category: String

    public init(
        id: UUID = UUID(),
        originalSentence: String,
        correctedSentence: String,
        explanation: String,
        category: String = "Grammar"
    ) {
        self.id = id
        self.originalSentence = originalSentence
        self.correctedSentence = correctedSentence
        self.explanation = explanation
        self.category = category
    }
}

public struct SessionRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let durationSeconds: Int
    public let transcripts: [TranscriptEntry]
    public let extractedErrors: [ExtractedErrorItem]

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        durationSeconds: Int = 0,
        transcripts: [TranscriptEntry] = [],
        extractedErrors: [ExtractedErrorItem] = []
    ) {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
        self.transcripts = transcripts
        self.extractedErrors = extractedErrors
    }
}

public struct QuizQuestion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let questionText: String
    public let options: [String]
    public let correctOptionIndex: Int
    public let explanation: String

    public init(
        id: UUID = UUID(),
        questionText: String,
        options: [String],
        correctOptionIndex: Int,
        explanation: String
    ) {
        self.id = id
        self.questionText = questionText
        self.options = options
        self.correctOptionIndex = correctOptionIndex
        self.explanation = explanation
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ModelTests`
Expected: PASS

---

### Task 2: Implement SessionStorageService & QuizGeneratorService

**Files:**
- Create: `Sources/AIEnglishTutor/Services/SessionStorageService.swift`
- Create: `Sources/AIEnglishTutor/Services/QuizGeneratorService.swift`
- Create: `Tests/AIEnglishTutorTests/SessionStorageTests.swift`

**Interfaces:**
- Produces: `SessionStorageServiceProtocol`, `SessionStorageService`, `QuizGeneratorService`

- [ ] **Step 1: Write failing test for SessionStorageService & QuizGeneratorService**

```swift
// In Tests/AIEnglishTutorTests/SessionStorageTests.swift
import XCTest
@testable import AIEnglishTutor

final class SessionStorageTests: XCTestCase {
    func testSaveAndLoadSession() async throws {
        let storage = SessionStorageService(storageDirectory: FileManager.default.temporaryDirectory)
        let record = SessionRecord(
            durationSeconds: 300,
            transcripts: [TranscriptEntry(speaker: "Tutor", text: "Hello!")],
            extractedErrors: [
                ExtractedErrorItem(
                    originalSentence: "She don't like apples.",
                    correctedSentence: "She doesn't like apples.",
                    explanation: "Third person singular requires 'doesn't'."
                )
            ]
        )
        try await storage.saveSession(record)
        let loaded = try await storage.loadAllSessions()
        XCTAssertFalse(loaded.isEmpty)

        let quiz = QuizGeneratorService.generateQuiz(from: loaded)
        XCTAssertFalse(quiz.isEmpty)
        XCTAssertEqual(quiz.first?.correctOptionIndex, 0)
    }
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter SessionStorageTests`
Expected: FAIL (missing SessionStorageService)

- [ ] **Step 3: Implement SessionStorageService & QuizGeneratorService**

Create `Sources/AIEnglishTutor/Services/SessionStorageService.swift`:
```swift
import Foundation

public protocol SessionStorageServiceProtocol: Sendable {
    func saveSession(_ record: SessionRecord) async throws
    func loadAllSessions() async throws -> [SessionRecord]
    func deleteSession(id: UUID) async throws
}

public final class SessionStorageService: SessionStorageServiceProtocol, @unchecked Sendable {
    private let storageDirectory: URL
    private let fileManager = FileManager.default

    public init(storageDirectory: URL? = nil) {
        if let directory = storageDirectory {
            self.storageDirectory = directory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageDirectory = appSupport.appendingPathComponent("AIEnglishTutor/Sessions", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.storageDirectory, withIntermediateDirectories: true)
    }

    public func saveSession(_ record: SessionRecord) async throws {
        let fileURL = storageDirectory.appendingPathComponent("\(record.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        try data.write(to: fileURL, options: .atomic)
    }

    public func loadAllSessions() async throws -> [SessionRecord] {
        guard let files = try? fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var sessions: [SessionRecord] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let record = try? decoder.decode(SessionRecord.self, from: data) {
                sessions.append(record)
            }
        }
        return sessions.sorted(by: { $0.date > $1.date })
    }

    public func deleteSession(id: UUID) async throws {
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
    }
}
```

Create `Sources/AIEnglishTutor/Services/QuizGeneratorService.swift`:
```swift
import Foundation

public struct QuizGeneratorService: Sendable {
    public static func generateQuiz(from sessions: [SessionRecord]) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let allErrors = sessions.flatMap { $0.extractedErrors }

        for error in allErrors {
            let correctOption = error.correctedSentence
            let wrongOption1 = error.originalSentence
            let wrongOption2 = error.originalSentence.replacingOccurrences(of: "don't", with: "not")
            let options = [correctOption, wrongOption1, wrongOption2].shuffled()
            let correctIndex = options.firstIndex(of: correctOption) ?? 0

            let question = QuizQuestion(
                questionText: "How should you correctly say: \"\(error.originalSentence)\"?",
                options: options,
                correctOptionIndex: correctIndex,
                explanation: error.explanation
            )
            questions.append(question)
        }
        return questions
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SessionStorageTests`
Expected: PASS

---

### Task 3: Add Frame Hashing & Performance Optimizations to ScreenCaptureService

**Files:**
- Modify: `Sources/AIEnglishTutor/Services/ScreenCaptureService.swift`
- Modify: `Tests/AIEnglishTutorTests/ScreenCaptureTests.swift`

- [ ] **Step 1: Implement SHA256 frame deduplication check**

In `ScreenCaptureService.swift`:
Add `private var lastFrameHash: String?` and CryptoKit import (`import CryptoKit`).
If compressed frame hash equals `lastFrameHash`, skip calling `onFrame` to save bandwidth & CPU.

- [ ] **Step 2: Verify with swift test**

Run: `swift test --filter ScreenCaptureTests`
Expected: PASS

---

### Task 4: Integrate Session Storage into AppViewModel & Implement Views (HistoryView, DailyQuizView, SettingsView, Tabbed MainWindow)

**Files:**
- Modify: `Sources/AIEnglishTutor/ViewModels/AppViewModel.swift`
- Create: `Sources/AIEnglishTutor/Views/HistoryView.swift`
- Create: `Sources/AIEnglishTutor/Views/DailyQuizView.swift`
- Create: `Sources/AIEnglishTutor/Views/SettingsView.swift`
- Modify: `Sources/AIEnglishTutor/Views/MainWindow.swift`

- [ ] **Step 1: Update AppViewModel to manage sessions, auto-save, and quiz state**

Add `@Published public var savedSessions: [SessionRecord] = []`, `@Published public var dailyQuizQuestions: [QuizQuestion] = []`, `@Published public var selectedTab: Int = 0`.
Auto-save session in `stopSession()`.

- [ ] **Step 2: Create HistoryView, DailyQuizView, and SettingsView**

- [ ] **Step 3: Refactor MainWindow into 4-Tab View with TabView**

Tab 0: 🎙️ Live Tutor
Tab 1: 📚 Session History
Tab 2: 🎯 Daily Quiz
Tab 3: ⚙️ Settings

- [ ] **Step 4: Run all unit tests to ensure zero regressions**

Run: `swift test`
Expected: All tests PASS

- [ ] **Step 5: Build release binary & re-launch application bundle**

Run: `swift build -c release && cp .build/release/AIEnglishTutorApp "build/AI English Tutor.app/Contents/MacOS/AI English Tutor" && open "build/AI English Tutor.app"`
