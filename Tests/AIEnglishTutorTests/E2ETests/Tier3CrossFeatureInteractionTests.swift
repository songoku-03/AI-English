import Foundation
#if canImport(XCTest)
import XCTest
#endif
import AppKit
@testable import AIEnglishTutor

@MainActor
final class Tier3CrossFeatureInteractionTests: XCTestCase, TestRunnable {
    var keychain: MockKeychainService!
    var hotkeys: MockGlobalHotkeyService!
    var screenCap: MockScreenCaptureService!
    var audioEngine: MockAudioEngineService!
    var geminiClient: MockGeminiLiveClient!
    var viewModel: AppViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        keychain = MockKeychainService()
        hotkeys = MockGlobalHotkeyService()
        screenCap = MockScreenCaptureService()
        audioEngine = MockAudioEngineService()
        geminiClient = MockGeminiLiveClient()

        viewModel = AppViewModel(
            keychainService: keychain,
            hotkeyService: hotkeys,
            screenCaptureService: screenCap,
            audioEngineService: audioEngine,
            geminiLiveClient: geminiClient
        )
    }

    @MainActor
    override func tearDown() {
        viewModel = nil
        geminiClient = nil
        audioEngine = nil
        screenCap = nil
        hotkeys = nil
        keychain = nil
        super.tearDown()
    }

    private func createTestImageData(width: Int, height: Int) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return Data()
        }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        guard let cgImage = context.makeImage() else {
            return Data()
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 1.0]) ?? Data()
    }

    // 1. Hotkeys + Audio Engine Mute Synchronization
    func testHotkeyTriggerMutesAudioInput() async throws {
        viewModel.config.apiKey = "AIzaSyD-ValidKey123456"
        await viewModel.startSession()
        XCTAssertTrue(viewModel.isSessionActive)

        // Trigger mute hotkey (Ctrl+Option+M)
        hotkeys.triggerMuteHotkey()
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.isMuted)
        XCTAssertTrue(audioEngine.isMuted)
        XCTAssertEqual(viewModel.statusMessage, "Microphone Muted")

        // Simulate microphone input while muted
        let sampleMicPCM = "MIC_VOICE_SAMPLE".data(using: .utf8)!
        audioEngine.simulateMicrophoneInput(pcmData: sampleMicPCM)
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Ensure no audio chunk dispatched to WebSocket client when muted
        XCTAssertEqual(geminiClient.sentAudioChunks.count, 0)

        // Unmute via hotkey
        hotkeys.triggerMuteHotkey()
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(viewModel.isMuted)
        XCTAssertFalse(audioEngine.isMuted)

        // Now send microphone input
        audioEngine.simulateMicrophoneInput(pcmData: sampleMicPCM)
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(geminiClient.sentAudioChunks.count, 1)
    }

    // 2. VAD Barge-in + Audio Engine Queue Flush Interaction
    func testBargeInFlushesAudioPlaybackQueue() async throws {
        viewModel.config.apiKey = "AIzaSyD-ValidKey123456"
        await viewModel.startSession()

        // Queue AI audio playback chunks
        audioEngine.playAudioChunk(data: Data([0x10, 0x20]))
        audioEngine.playAudioChunk(data: Data([0x30, 0x40]))
        XCTAssertTrue(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.playbackQueueCount, 2)

        // User interrupts (VAD event)
        geminiClient.simulateUserBargeIn()
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify playback interrupted immediately and queue flushed
        XCTAssertFalse(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.playbackQueueCount, 0)

        // Verify System Barge-In entry recorded in transcript history
        XCTAssertTrue(viewModel.transcriptEntries.contains { $0.text.contains("[User Interrupted AI Playback]") })
    }

    // 3. Screen Capture Stream + Gemini WebSocket Image Payload Dispatch
    func testScreenCaptureStreamDispatchesBase64PayloadToWebSocket() async throws {
        viewModel.config.apiKey = "AIzaSyD-ValidKey123456"
        await viewModel.startSession()

        XCTAssertTrue(screenCap.isCapturing)

        // Emit mock 1080p desktop frame
        let rawFrame = createTestImageData(width: 1920, height: 1080)
        screenCap.emitMockFrame(data: rawFrame)
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify image processed and base64 string sent over Gemini Live Client
        XCTAssertEqual(geminiClient.sentImages.count, 1)
        let sentPayload = try XCTUnwrap(geminiClient.sentImages.first)
        XCTAssertFalse(sentPayload.isEmpty)

        // Confirm base64 string decodes to valid JPEG image representation with scaled width
        if let decodedData = Data(base64Encoded: sentPayload),
           let decodedImage = NSImage(data: decodedData) {
            var rect = CGRect(origin: .zero, size: decodedImage.size)
            if let cgImage = decodedImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                XCTAssertLessThanOrEqual(cgImage.width, 1024)
            } else {
                XCTAssertLessThanOrEqual(Int(decodedImage.size.width), 1024)
            }
        } else {
            XCTFail("Decoded base64 payload should be a valid JPEG image with width <= 1024")
        }
    }

    @MainActor
    public func runAllTests() async throws {
        setUp()
        try await testHotkeyTriggerMutesAudioInput()
        tearDown()

        setUp()
        try await testBargeInFlushesAudioPlaybackQueue()
        tearDown()

        setUp()
        try await testScreenCaptureStreamDispatchesBase64PayloadToWebSocket()
        tearDown()
    }
}
