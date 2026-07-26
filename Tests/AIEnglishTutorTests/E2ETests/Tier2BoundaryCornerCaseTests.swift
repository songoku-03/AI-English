import XCTest
@testable import AIEnglishTutor

@MainActor
final class Tier2BoundaryCornerCaseTests: XCTestCase {
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

    // 1. Empty API Key Validation
    func testEmptyApiKeyValidation() async {
        viewModel.config.apiKey = ""
        await viewModel.startSession()
        
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.statusMessage, "Error: API Key is required")
        
        XCTAssertThrowsError(try viewModel.saveApiKey("   ")) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.emptyKey)
        }
    }

    // 2. Invalid API Key Format Validation
    func testInvalidApiKeyFormatValidation() async {
        let invalidKey = "INVALID_KEY"
        XCTAssertThrowsError(try keychain.save(key: "gemini_api_key", value: invalidKey))
        
        // Test client rejection
        do {
            try await geminiClient.connect(apiKey: invalidKey)
            XCTFail("Should have thrown invalidApiKeyFormat")
        } catch {
            XCTAssertEqual(error as? GeminiLiveError, GeminiLiveError.invalidApiKeyFormat)
        }
    }

    // 3. Screen Capture Frame Resize Boundary (1024px vs >1024px vs <1024px)
    func testScreenCaptureFrameResizeBoundaries() {
        // Boundary 1: Exactly 1024px (No scaling down beyond 1024)
        let exact1024Frame = "FRAME_1024_768".data(using: .utf8)!
        _ = screenCap.resizeAndCompress(frameData: exact1024Frame, maxWidth: 1024.0, compressionQuality: 0.7)
        XCTAssertEqual(screenCap.lastProcessedWidth, 1024.0)

        // Boundary 2: >1024px (3840x2160 4K frame downscaled to 1024)
        let largeFrame = "FRAME_3840_2160".data(using: .utf8)!
        _ = screenCap.resizeAndCompress(frameData: largeFrame, maxWidth: 1024.0, compressionQuality: 0.7)
        XCTAssertEqual(screenCap.lastProcessedWidth, 1024.0)

        // Boundary 3: <1024px (800x600 retained without upscale)
        let smallFrame = "FRAME_800_600".data(using: .utf8)!
        _ = screenCap.resizeAndCompress(frameData: smallFrame, maxWidth: 1024.0, compressionQuality: 0.7)
        XCTAssertEqual(screenCap.lastProcessedWidth, 800.0)
    }

    // 4. Audio Buffer Edge Cases (Overflow / Underflow)
    func testAudioBufferOverflowAndUnderflow() {
        // Underflow test: play request on empty queue
        audioEngine.stopAudio()
        XCTAssertEqual(audioEngine.playbackQueueCount, 0)
        XCTAssertFalse(audioEngine.isPlaying)

        // Overflow test: exceed maximum capacity
        audioEngine.maxBufferCapacity = 3
        audioEngine.playAudioChunk(data: Data([0x01]))
        audioEngine.playAudioChunk(data: Data([0x02]))
        audioEngine.playAudioChunk(data: Data([0x03]))
        audioEngine.playAudioChunk(data: Data([0x04])) // overflow chunk dropped
        
        XCTAssertEqual(audioEngine.playbackQueueCount, 3)
    }

    // 5. WebSocket Connection Drop & Automatic Reconnect Retry (3x limit)
    func testWebSocketReconnectRetryThreshold() throws {
        geminiClient.isConnected = true
        geminiClient.maxRetriesBeforeFail = 3

        // Drop #1 -> Retry #1 (Succeeds)
        try geminiClient.simulateConnectionDrop()
        XCTAssertTrue(geminiClient.isConnected)
        XCTAssertEqual(geminiClient.reconnectAttempts, 1)

        // Drop #2 -> Retry #2 (Succeeds)
        try geminiClient.simulateConnectionDrop()
        XCTAssertTrue(geminiClient.isConnected)
        XCTAssertEqual(geminiClient.reconnectAttempts, 2)

        // Drop #3 -> Retry #3 (Succeeds)
        try geminiClient.simulateConnectionDrop()
        XCTAssertTrue(geminiClient.isConnected)
        XCTAssertEqual(geminiClient.reconnectAttempts, 3)

        // Drop #4 -> Retries Exceeded (Fails)
        XCTAssertThrowsError(try geminiClient.simulateConnectionDrop()) { error in
            XCTAssertEqual(error as? GeminiLiveError, GeminiLiveError.maxReconnectAttemptsExceeded)
        }
        XCTAssertFalse(geminiClient.isConnected)
    }
}
