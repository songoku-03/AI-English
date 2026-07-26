import Foundation

public final class MockAudioEngineService: AudioEngineServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()

    public private(set) var isStreaming: Bool = false
    public private(set) var isAudioPlaying: Bool = false
    public var isPlaying: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return isAudioPlaying && !internalPlayedChunks.isEmpty
        }
    }

    public var isMuted: Bool = false
    public var maxBufferCapacity: Int = 100

    private var internalPlayedChunks: [Data] = []
    public var playedChunks: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return internalPlayedChunks
    }

    public var playbackQueueCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return internalPlayedChunks.count
    }

    public private(set) var wasInterrupted: Bool = false
    public var shouldFailToStartInput: Bool = false

    public var onPCMDataHandler: (@Sendable (Data) -> Void)?
    public var onAudioLevelHandler: (@Sendable (Float) -> Void)?

    public init() {}

    public func startInputStreaming(onPCMData: @escaping @Sendable (Data) -> Void, onAudioLevel: (@Sendable (Float) -> Void)? = nil) throws {
        lock.lock()
        defer { lock.unlock() }

        if shouldFailToStartInput {
            throw AudioEngineError.engineStartFailed("Mock engine start failed")
        }

        self.onPCMDataHandler = onPCMData
        self.onAudioLevelHandler = onAudioLevel
        self.isStreaming = true
    }

    public func playAudioChunk(data: Data) {
        lock.lock()
        defer { lock.unlock() }

        if internalPlayedChunks.count < maxBufferCapacity {
            internalPlayedChunks.append(data)
            isAudioPlaying = true
        }
    }

    public func stopAudio() {
        lock.lock()
        defer { lock.unlock() }

        isStreaming = false
        isAudioPlaying = false
        internalPlayedChunks.removeAll()
        onPCMDataHandler = nil
    }

    public func interruptPlayback() {
        lock.lock()
        defer { lock.unlock() }

        wasInterrupted = true
        internalPlayedChunks.removeAll()
        isAudioPlaying = false
    }

    public func simulateMicrophoneInput(pcmData: Data) {
        simulateAudioInput(data: pcmData)
    }

    public func simulateAudioInput(data: Data) {
        let handler: (@Sendable (Data) -> Void)?
        let muted: Bool
        lock.lock()
        handler = onPCMDataHandler
        muted = isMuted
        lock.unlock()

        if !muted {
            handler?(data)
        }
    }

    public func resetInterruptedFlag() {
        lock.lock()
        defer { lock.unlock() }
        wasInterrupted = false
    }
}
