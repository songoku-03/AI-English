import Foundation
#if canImport(XCTest)
import XCTest
#endif
import AppKit
@testable import AIEnglishTutor

@MainActor
final class Tier1FeatureCoverageTests: XCTestCase, TestRunnable {
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
        let size = NSSize(width: 1920, height: 1080)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let rep = NSBitmapImageRep(cgImage: cgImage).representation(using: .jpeg, properties: [.compressionFactor: 1.0]) else {
            XCTFail("Failed to create test JPEG data")
            return
        }

        let processedData = screenCap.resizeAndCompress(frameData: rep, maxWidth: 1024.0, compressionQuality: 0.7)

        XCTAssertEqual(screenCap.lastProcessedWidth, 1024.0)
        XCTAssertFalse(processedData.isEmpty)
    }

    // 4. Audio Input/Output Handling
    func testAudioInputOutputCoverage() throws {
        let receivedInputPCM = TestBox<Data?>(nil)
        try audioEngine.startInputStreaming { data in
            receivedInputPCM.value = data
        }

        let sampleMicData = "PCM16_16000_MONO".data(using: .utf8)!
        audioEngine.simulateMicrophoneInput(pcmData: sampleMicData)
        XCTAssertEqual(receivedInputPCM.value, sampleMicData)

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
        XCTAssertEqual(geminiClient.setupMessageSent?.model, AppConfig.defaultFallbackModel)

        let interruptedCalled = TestBox(false)
        geminiClient.onInterrupted = {
            interruptedCalled.value = true
        }
        geminiClient.simulateUserBargeIn()
        XCTAssertTrue(interruptedCalled.value)
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

    @MainActor
    public func runAllTests() async throws {
        setUp()
        try testKeychainSaveAndRetrieveCoverage()
        tearDown()

        setUp()
        try testGlobalHotkeyRegistrationCoverage()
        tearDown()

        setUp()
        testScreenCaptureFrameResizeCoverage()
        tearDown()

        setUp()
        try testAudioInputOutputCoverage()
        tearDown()

        setUp()
        try await testGeminiLiveSetupAndFallbackCoverage()
        tearDown()

        setUp()
        testSubtitleTranscriptExportCoverage()
        tearDown()
    }
}
