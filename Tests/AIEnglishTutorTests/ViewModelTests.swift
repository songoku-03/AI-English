#if canImport(XCTest)
import XCTest
#endif
@testable import AIEnglishTutor

@MainActor
final class ViewModelTests: XCTestCase, TestRunnable {
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

    func testViewModelInitialState() {
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(viewModel.isMuted)
        XCTAssertEqual(viewModel.statusMessage, "Ready")
        XCTAssertTrue(viewModel.transcriptEntries.isEmpty)
    }

    func testToggleSessionFlow() async throws {
        viewModel.config.apiKey = "AIzaSyD-ValidKey123456"
        await viewModel.startSession()

        XCTAssertTrue(viewModel.isSessionActive)
        XCTAssertTrue(viewModel.isConnected)
        XCTAssertEqual(viewModel.statusMessage, "Session Active")

        await viewModel.stopSession()
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(viewModel.isConnected)
        XCTAssertEqual(viewModel.statusMessage, "Session Stopped")
    }

    func testToggleMuteFlow() {
        viewModel.toggleMute()
        XCTAssertTrue(viewModel.isMuted)

        viewModel.toggleMute()
        XCTAssertFalse(viewModel.isMuted)
    }

    func testVADBargeInFlowAndTranscriptExport() {
        // Add transcripts
        viewModel.appendTranscript(TranscriptEntry(speaker: "Tutor", text: "Hello, how are you?"))
        viewModel.appendTranscript(TranscriptEntry(speaker: "Learner", text: "I am fine."))

        // Test VAD barge-in flow
        audioEngine.playAudioChunk(data: Data([0x01, 0x02]))
        XCTAssertEqual(audioEngine.playbackQueueCount, 1)

        viewModel.handleBargeIn()

        // Verify audio queue was flushed
        XCTAssertEqual(audioEngine.playbackQueueCount, 0)
        XCTAssertEqual(viewModel.transcripts.last?.speaker, "System")
        XCTAssertTrue(viewModel.transcripts.last?.text.contains("Interrupted") == true)

        // Verify export format
        let export = viewModel.exportTranscript()
        XCTAssertTrue(export.contains("Tutor: Hello, how are you?"))
        XCTAssertTrue(export.contains("Learner: I am fine."))
        XCTAssertTrue(export.contains("System: [User Interrupted AI Playback]"))
    }

    public func runAllTests() async throws {
        setUp()
        testViewModelInitialState()
        tearDown()

        setUp()
        try await testToggleSessionFlow()
        tearDown()

        setUp()
        testToggleMuteFlow()
        tearDown()

        setUp()
        testVADBargeInFlowAndTranscriptExport()
        tearDown()
    }
}
