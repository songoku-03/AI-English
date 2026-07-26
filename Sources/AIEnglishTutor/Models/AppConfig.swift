import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public static let defaultPrimaryModel = "models/gemini-3.1-flash-live"
    public static let defaultFallbackModel = "models/gemini-2.5-flash-native-audio-preview-12-2025"

    public static let defaultSystemPrompt = """
    You are a friendly, helpful, and patient English tutor for a non-native speaker. \
    Speak clearly, keep explanations concise, correct major grammar or pronunciation errors gently, \
    and encourage the learner to speak naturally.
    """

    public var apiKey: String
    public var systemPrompt: String
    public var voiceName: String
    public var frameRate: Int
    public var jpegQuality: Double
    public var maxImageDimension: Int

    public init(
        apiKey: String = "",
        systemPrompt: String = AppConfig.defaultSystemPrompt,
        voiceName: String = "Puck",
        frameRate: Int = 1,
        jpegQuality: Double = 0.7,
        maxImageDimension: Int = 1024
    ) {
        self.apiKey = apiKey
        self.systemPrompt = systemPrompt
        self.voiceName = voiceName
        self.frameRate = frameRate
        self.jpegQuality = jpegQuality
        self.maxImageDimension = maxImageDimension
    }
}
