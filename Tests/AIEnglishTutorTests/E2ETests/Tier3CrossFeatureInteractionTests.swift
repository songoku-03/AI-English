import XCTest
@testable import AIEnglishTutor

@MainActor
final class Tier3CrossFeatureInteractionTests: XCTestCase {
    var keychain: MockKeychainService!
    var hotkeys: MockGlobalHotkeyService!
    var screenCap: MockScreenCaptureService!
    var audioEngine: MockAudioEngineService!
    var geminiClient: MockGeminiLiveClient!
    var viewModel: AppViewModel!

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

    override func tearDown() {
        viewModel = nil
        geminiClient = nil
        audioEngine = nil
        screenCap = nil
        hotkeys = nil
        keychain = nil
        super.tearDown()
    }

    // 1. Hotkeys + Audio Engine Mute Synchronization
    func testHotkeyTriggerMutesAudioInput() async throws {
        viewModel.config.apiKey = "AIzaSyD-ValidKey123456"
        await viewModel.startSession()
        XCTAssertTrue(viewModel.isSessionActive)
        
        // Trigger mute hotkey (Ctrl+Option+M)
        hotkeys.triggerMuteHotkey()
        
        XCTAssertTrue(viewModel.isMuted)
        XCTAssertTrue(audioEngine.isMuted)
        XCTAssertEqual(viewModel.statusMessage, "Microphone Muted")
        
        // Simulate microphone input while muted
        let sampleMicPCM = "MIC_VOICE_SAMPLE".data(using: .utf8)!
        audioEngine.simulateMicrophoneInput(pcmData: sampleMicPCM)
        
        // Ensure no audio chunk dispatched to WebSocket client when muted
        XCTAssertEqual(geminiClient.sentAudioChunks.count, 0)
        
        // Unmute via hotkey
        hotkeys.triggerMuteHotkey()
        XCTAssertFalse(viewModel.isMuted)
        XCTAssertFalse(audioEngine.isMuted)
        
        // Now send microphone input
        audioEngine.simulateMicrophoneInput(pcmData: sampleMicPCM)
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
        let rawFrame = "FRAME_1920_1080".data(using: .utf8)!
        screenCap.emitMockFrame(data: rawFrame)
        
        // Verify image processed and base64 string sent over Gemini Live Client
        XCTAssertEqual(geminiClient.sentImages.count, 1)
        let sentPayload = geminiClient.sentImages.first!
        XCTAssertFalse(sentPayload.isEmpty)
        
        // Confirm base64 string decodes to processed frame representation
        if let decodedData = Data(base64Encoded: sentPayload), let str = String(data: decodedData, encoding: .utf8) {
            XCTAssertTrue(str.contains("PROCESSED_FRAME_1024_0.7"))
        }
    }
}
