import Foundation

public enum GeminiLiveError: Error, Equatable, Sendable {
    case emptyApiKey
    case invalidApiKeyFormat
    case invalidAPIKey
    case connectionFailed(String)
    case maxReconnectAttemptsExceeded
    case notConnected
}

public typealias GeminiLiveClientError = GeminiLiveError

public protocol GeminiLiveClientProtocol: AnyObject, Sendable {
    var onTranscript: ((_ speaker: String, _ text: String) -> Void)? { get set }
    var onAudioReceived: ((_ pcmData: Data) -> Void)? { get set }
    var onError: ((_ error: Error) -> Void)? { get set }
    var onInterrupted: (() -> Void)? { get set }
    var currentModel: String { get }

    func connect(apiKey: String) async throws
    func sendAudio(data: Data)
    func sendImage(base64JPEG: String)
    func disconnect()
}
