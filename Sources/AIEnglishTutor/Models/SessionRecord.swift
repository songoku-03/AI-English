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
