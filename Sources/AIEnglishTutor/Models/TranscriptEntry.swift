import Foundation

public struct TranscriptEntry: Identifiable, Codable, Equatable, Sendable {
    public enum Speaker: String, Codable, Equatable, Sendable {
        case user = "User"
        case tutor = "Tutor"
        case gemini = "Gemini"
        case system = "System"
    }

    public let id: UUID
    public let timestamp: Date
    public let speaker: String
    public let text: String

    public var speakerEnum: Speaker? {
        Speaker(rawValue: speaker)
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        speaker: Speaker,
        text: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.speaker = speaker.rawValue
        self.text = text
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        speaker: String,
        text: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.speaker = speaker
        self.text = text
    }
}
