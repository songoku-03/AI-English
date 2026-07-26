import Foundation

public enum AudioEngineError: Error, Equatable, Sendable {
    case inputNodeUnavailable
    case engineStartFailed(String)
    case invalidAudioFormat
    case bufferOverflow
    case invalidSampleRate
}

public protocol AudioEngineServiceProtocol: Sendable {
    func startInputStreaming(onPCMData: @escaping @Sendable (Data) -> Void) throws
    func playAudioChunk(data: Data)
    func stopAudio()
    func interruptPlayback()

    var isMuted: Bool { get set }
    var isPlaying: Bool { get }
    var playbackQueueCount: Int { get }
}
