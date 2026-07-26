import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import AIEnglishTutor

final class SessionStorageTests: XCTestCase, TestRunnable {
    func testSaveAndLoadSession() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = SessionStorageService(storageDirectory: tempDir)
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
        XCTAssertEqual(loaded.first?.id, record.id)

        let quiz = QuizGeneratorService.generateQuiz(from: loaded)
        XCTAssertFalse(quiz.isEmpty)
        XCTAssertTrue(quiz.first?.options.contains("She doesn't like apples.") == true)

        try await storage.deleteSession(id: record.id)
        let remaining = try await storage.loadAllSessions()
        XCTAssertTrue(remaining.isEmpty)

        try? FileManager.default.removeItem(at: tempDir)
    }

    public func runAllTests() async throws {
        setUp()
        try await testSaveAndLoadSession()
        tearDown()
    }
}
