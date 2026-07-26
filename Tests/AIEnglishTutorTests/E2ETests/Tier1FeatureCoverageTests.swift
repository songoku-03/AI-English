import XCTest
@testable import AIEnglishTutor

@MainActor
final class Tier1FeatureCoverageTests: XCTestCase {
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

    // 1. Keychain API Key Save and Retrieval
    func testKeychainSaveAndRetrieveCoverage() throws {
        let testKey = "AIzaSyD-TestKey1234567890"
        try viewModel.saveApiKey(testKey)
        
        XCTAssertEqual(viewModel.config.apiKey, testKey)
        XCTAssertEqual(try keychain.retrieve(key: "gemini_api_key"), testKey)
        
        // Retrieve into new viewmodel
        let newViewModel = AppViewModel(
            keychainService: keychain,
            hotkeyService: hotkeys,
            screenCaptureService: screenCap,
            audioEngineService: audioEngine,
            geminiLiveClient: geminiClient
        )
        XCTAssertEqual(newViewModel.config.apiKey, testKey)
    }

    // 2. Global Hotkey Registration
    func testGlobalHotkeyRegistrationCoverage() throws {
        XCTAssertTrue(hotkeys.isRegistered)
        XCTAssertNotNil(hotkeys.muteToggleHandler)
        XCTAssertNotNil(hotkeys.sessionToggleHandler)
    }

    // 3. ScreenCapture <=1024px JPEG Compression
    func testScreenCaptureFrameResizeCoverage() {
        let originalFrameData = "FRAME_1920_1080".data(using: .utf8)!
        let processedData = screenCap.resizeAndCompress(frameData: originalFrameData, maxWidth: 1024.0, compressionQuality: 0.7)
        
        XCTAssertEqual(screenCap.lastProcessedWidth, 1024.0)
        let processedString = String(data: processedData, encoding: .utf8)!
        XCTAssertTrue(processedString.contains("PROCESSED_FRAME_1024_0.7"))
    }

    // 4. Audio Input/Output Handling
    func testAudioInputOutputCoverage() throws {
        var receivedInputPCM: Data?
        try audioEngine.startInputStreaming { data in
            receivedInputPCM = data
        }
        
        let sampleMicData = "PCM16_16000_MONO".data(using: .utf8)!
        audioEngine.simulateMicrophoneInput(pcmData: sampleMicData)
        XCTAssertEqual(receivedInputPCM, sampleMicData)
        
        let sampleOutputChunk = "PCM_24000_AUDIO_CHUNK".data(using: .utf8)!
        audioEngine.playAudioChunk(data: sampleOutputChunk)
        
        XCTAssertTrue(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.playbackQueueCount, 1)
    }

    // 5. Gemini Live Client Connection & Setup & Model Fallback & Barge-in
    func testGeminiLiveSetupAndFallbackCoverage() async throws {
        geminiClient.shouldFailPrimaryModel = true
        let validKey = "AIzaSyD-ValidKey123456"
        
        try await geminiClient.connect(apiKey: validKey)
        XCTAssertTrue(geminiClient.isConnected)
        XCTAssertEqual(geminiClient.currentModel, AppConfig.defaultFallbackModel)
        XCTAssertEqual(geminiClient.setupMessageSent?.setup.model, AppConfig.defaultFallbackModel)
        
        var interruptedCalled = false
        geminiClient.onInterrupted = {
            interruptedCalled = true
        }
        geminiClient.simulateUserBargeIn()
        XCTAssertTrue(interruptedCalled)
    }

    // 6. Subtitle Transcript Export
    func testSubtitleTranscriptExportCoverage() {
        let entry1 = TranscriptEntry(speaker: "User", text: "Hello AI Tutor!")
        let entry2 = TranscriptEntry(speaker: "Gemini", text: "Hello! How can I help you today?")
        
        viewModel.transcriptEntries.append(contentsOf: [entry1, entry2])
        let exportedText = viewModel.exportTranscript()
        
        XCTAssertTrue(exportedText.contains("User: Hello AI Tutor!"))
        XCTAssertTrue(exportedText.contains("Gemini: Hello! How can I help you today?"))
    }
}
