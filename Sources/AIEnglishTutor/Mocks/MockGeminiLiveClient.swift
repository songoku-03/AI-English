import Foundation

public class MockGeminiLiveClient: GeminiLiveClientProtocol, @unchecked Sendable {
    public var onTranscript: ((String, String) -> Void)?
    public var onAudioReceived: ((Data) -> Void)?
    public var onError: ((Error) -> Void)?
    public var onInterrupted: (() -> Void)?
    
    public var isConnected: Bool = false
    public var currentModel: String = AppConfig.defaultPrimaryModel
    public var reconnectAttempts: Int = 0
    
    public var shouldFailPrimaryModel: Bool = false
    public var shouldFailAllConnections: Bool = false
    public var maxRetriesBeforeFail: Int = 3
    
    public var sentAudioChunks: [Data] = []
    public var sentImages: [String] = []
    public var setupMessageSent: BidiGenerateContentSetup?
    
    public init() {}
    
    public func connect(apiKey: String) async throws {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw GeminiLiveError.emptyApiKey
        }
        guard cleanKey.count >= 8 && !cleanKey.contains("INVALID") else {
            throw GeminiLiveError.invalidApiKeyFormat
        }
        if shouldFailAllConnections {
            throw GeminiLiveError.connectionFailed("Network unreachable")
        }
        
        if shouldFailPrimaryModel {
            currentModel = AppConfig.defaultFallbackModel
        } else {
            currentModel = AppConfig.defaultPrimaryModel
        }
        
        setupMessageSent = BidiGenerateContentSetup(
            model: currentModel,
            systemPrompt: AppConfig.defaultSystemPrompt,
            voiceName: "Puck"
        )
        isConnected = true
        reconnectAttempts = 0
    }
    
    public func sendAudio(data: Data) {
        guard isConnected else { return }
        sentAudioChunks.append(data)
    }
    
    public func sendImage(base64JPEG: String) {
        guard isConnected else { return }
        sentImages.append(base64JPEG)
    }
    
    public func disconnect() {
        isConnected = false
    }
    
    public func simulateConnectionDrop() throws {
        isConnected = false
        reconnectAttempts += 1
        if reconnectAttempts <= maxRetriesBeforeFail {
            isConnected = true
        } else {
            throw GeminiLiveError.maxReconnectAttemptsExceeded
        }
    }
    
    public func simulateServerTranscript(speaker: String, text: String) {
        onTranscript?(speaker, text)
    }
    
    public func simulateServerAudio(data: Data) {
        onAudioReceived?(data)
    }
    
    public func simulateUserBargeIn() {
        onInterrupted?()
    }
}
