import Foundation
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

    func testViewModelInitialState() {
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(viewModel.isMuted)
        XCTAssertEqual(viewModel.statusMessage, "Ready")
        XCTAssertTrue(viewModel.transcriptEntries.isEmpty)
    }

    func testToggleSessionFlow() async throws {
        viewModel.config.apiKey = "AIzaSyD-ValidKey123456"
        await viewModel.startSession()

        XCTAssertTrue(viewModel.showScreenPickerModal)
        await viewModel.confirmScreenSelectionAndStartSession()
        XCTAssertFalse(viewModel.showScreenPickerModal)

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

    func testSessionAutoSavingAndHistoryLoading() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let customStorage = SessionStorageService(storageDirectory: tempDir)
        let vm = AppViewModel(
            keychainService: keychain,
            hotkeyService: hotkeys,
            screenCaptureService: screenCap,
            audioEngineService: audioEngine,
            geminiLiveClient: geminiClient,
            sessionStorageService: customStorage
        )

        vm.appendTranscript(TranscriptEntry(speaker: "Learner", text: "He go to school."))
        vm.appendTranscript(TranscriptEntry(speaker: "Tutor", text: "Correction: \"He go to school\" -> \"He went to school\""))

        await vm.stopSession()

        // Wait brief moment for async save/load
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(vm.savedSessions.isEmpty)
        XCTAssertEqual(vm.savedSessions.count, 1)
        XCTAssertEqual(vm.savedSessions.first?.extractedErrors.count, 1)
        XCTAssertEqual(vm.savedSessions.first?.extractedErrors.first?.correctedSentence, "He went to school")
        XCTAssertFalse(vm.dailyQuizQuestions.isEmpty)
    }

    func testDeleteSession() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let customStorage = SessionStorageService(storageDirectory: tempDir)
        let record = SessionRecord(
            durationSeconds: 120,
            transcripts: [TranscriptEntry(speaker: "Learner", text: "Hello")],
            extractedErrors: []
        )
        try await customStorage.saveSession(record)

        let vm = AppViewModel(
            keychainService: keychain,
            hotkeyService: hotkeys,
            screenCaptureService: screenCap,
            audioEngineService: audioEngine,
            geminiLiveClient: geminiClient,
            sessionStorageService: customStorage
        )

        await vm.loadSavedSessions()
        XCTAssertEqual(vm.savedSessions.count, 1)

        await vm.deleteSession(id: record.id)
        XCTAssertTrue(vm.savedSessions.isEmpty)
    }

    func testExtractGrammarErrors() {
        let entries = [
            TranscriptEntry(speaker: "Learner", text: "She don't like coffee."),
            TranscriptEntry(speaker: "Tutor", text: "Instead of \"She don't like coffee\", say \"She doesn't like coffee\".")
        ]
        let errors = viewModel.extractGrammarErrors(from: entries)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first?.originalSentence, "She don't like coffee")
        XCTAssertEqual(errors.first?.correctedSentence, "She doesn't like coffee")
    }

    func testScreenPermissionDenied() async {
        screenCap.hasPermission = false
        await viewModel.startSession()

        XCTAssertFalse(viewModel.hasScreenPermission)
        XCTAssertFalse(viewModel.showScreenPickerModal)

        viewModel.openScreenCaptureSettings()
        XCTAssertTrue(screenCap.openScreenCaptureSettingsCalled)
    }

    func testScreenPickerModalSelection() async {
        viewModel.config.apiKey = "AIzaSyD-ValidKey123456"
        await viewModel.startSession()

        XCTAssertTrue(viewModel.hasScreenPermission)
        XCTAssertTrue(viewModel.showScreenPickerModal)

        viewModel.selectedDisplayID = 2
        await viewModel.confirmScreenSelectionAndStartSession()

        XCTAssertFalse(viewModel.showScreenPickerModal)
        XCTAssertTrue(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.selectedDisplayID, 2)
    }

    func testAutoPermissionListenerAndQualitySelection() async throws {
        // 1. Verify default values
        XCTAssertEqual(viewModel.selectedFPS, 1)
        XCTAssertEqual(viewModel.selectedResolutionDimension, 1280)

        // 2. Test quality selection passing to startCapture
        viewModel.selectedFPS = 5
        viewModel.selectedResolutionDimension = 1920
        viewModel.config.apiKey = "AIzaSyD-ValidKey123456"

        await viewModel.confirmScreenSelectionAndStartSession()

        XCTAssertTrue(viewModel.isSessionActive)
        XCTAssertEqual(screenCap.lastCapturedFPS, 5)
        XCTAssertEqual(screenCap.lastCapturedMaxDimension, 1920)

        await viewModel.stopSession()

        // 3. Test Auto Permission Listener
        let noPermissionCap = MockScreenCaptureService(hasPermission: false)
        let vmPermission = AppViewModel(
            keychainService: keychain,
            hotkeyService: hotkeys,
            screenCaptureService: noPermissionCap,
            audioEngineService: audioEngine,
            geminiLiveClient: geminiClient
        )

        XCTAssertFalse(vmPermission.hasScreenPermission)

        // Simulate user granting permission in System Settings
        noPermissionCap.hasPermission = true

        // Wait for the 1.5s timer to trigger
        var permissionUpdated = false
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if vmPermission.hasScreenPermission {
                permissionUpdated = true
                break
            }
        }

        XCTAssertTrue(permissionUpdated, "Timer should detect permission change within 3s")
        XCTAssertTrue(vmPermission.hasScreenPermission)
        XCTAssertFalse(vmPermission.availableDisplays.isEmpty)
    }

    @MainActor
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

        setUp()
        try await testSessionAutoSavingAndHistoryLoading()
        tearDown()

        setUp()
        try await testDeleteSession()
        tearDown()

        setUp()
        testExtractGrammarErrors()
        tearDown()

        setUp()
        await testScreenPermissionDenied()
        tearDown()

        setUp()
        await testScreenPickerModalSelection()
        tearDown()

        setUp()
        try await testAutoPermissionListenerAndQualitySelection()
        tearDown()
    }
}

