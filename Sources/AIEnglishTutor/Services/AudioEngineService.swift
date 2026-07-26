import Foundation
import AVFoundation

public final class AudioEngineService: AudioEngineServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()

    public var isMuted: Bool = false
    public private(set) var isPlaying: Bool = false

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private var pendingBufferCount: Int = 0
    private var pcmCallback: (@Sendable (Data) -> Void)?

    private let targetInputFormat: AVAudioFormat
    private let targetOutputFormat: AVAudioFormat

    public init() {
        let inputFmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
        let outputFmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
        self.targetInputFormat = inputFmt
        self.targetOutputFormat = outputFmt

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: targetOutputFormat)
    }

    public var playbackQueueCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingBufferCount
    }

    public func startInputStreaming(onPCMData: @escaping @Sendable (Data) -> Void) throws {
        lock.lock()
        self.pcmCallback = onPCMData
        lock.unlock()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw AudioEngineError.inputNodeUnavailable
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetInputFormat) else {
            throw AudioEngineError.invalidAudioFormat
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.lock.lock()
            let isMutedCurrent = self.isMuted
            let callback = self.pcmCallback
            self.lock.unlock()

            guard !isMutedCurrent, let callback = callback else { return }

            let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * 16000.0 / inputFormat.sampleRate)
            guard frameCapacity > 0, let pcmBuffer = AVAudioPCMBuffer(pcmFormat: self.targetInputFormat, frameCapacity: frameCapacity) else { return }

            var error: NSError?
            var inputBufferProvided = false
            let status = converter.convert(to: pcmBuffer, error: &error) { _, outStatus in
                if !inputBufferProvided {
                    inputBufferProvided = true
                    outStatus.pointee = .haveData
                    return buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            if status == .haveData, let channelData = pcmBuffer.int16ChannelData {
                let bytes = Data(bytes: channelData[0], count: Int(pcmBuffer.frameLength) * 2)
                callback(bytes)
            }
        }

        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                throw AudioEngineError.engineStartFailed(error.localizedDescription)
            }
        }
    }

    public func playAudioChunk(data: Data) {
        guard !data.isEmpty else { return }

        let frameCount = AVAudioFrameCount(data.count / 2)
        guard frameCount > 0, let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetOutputFormat, frameCapacity: frameCount) else { return }
        pcmBuffer.frameLength = frameCount

        if let channelData = pcmBuffer.int16ChannelData {
            data.copyBytes(to: UnsafeMutableBufferPointer(start: channelData[0], count: data.count / 2))
        }

        lock.lock()
        pendingBufferCount += 1
        isPlaying = true
        lock.unlock()

        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        if !playerNode.isPlaying {
            playerNode.play()
        }

        playerNode.scheduleBuffer(pcmBuffer) { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.pendingBufferCount = max(0, self.pendingBufferCount - 1)
            if self.pendingBufferCount == 0 {
                self.isPlaying = false
            }
            self.lock.unlock()
        }
    }

    public func stopAudio() {
        audioEngine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        audioEngine.stop()

        lock.lock()
        pendingBufferCount = 0
        isPlaying = false
        pcmCallback = nil
        lock.unlock()
    }

    public func interruptPlayback() {
        playerNode.stop()

        lock.lock()
        pendingBufferCount = 0
        isPlaying = false
        lock.unlock()

        playerNode.play()
    }
}
