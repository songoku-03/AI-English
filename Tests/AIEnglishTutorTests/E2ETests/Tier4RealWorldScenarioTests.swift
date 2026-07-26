import XCTest
@testable import AIEnglishTutor

@MainActor
final class Tier4RealWorldScenarioTests: XCTestCase {
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

    // Full Real-World Scenario: Mute -> Talk -> Barge-in -> Unmute -> Export Transcript Workflow
    func testFullRealWorldTutorSessionWorkflow() async throws {
        // Step 1: User saves API key to macOS Keychain
        let apiKey = "AIzaSyD-RealWorldTutorKey12345"
        try viewModel.saveApiKey(apiKey)
        XCTAssertEqual(viewModel.config.apiKey, apiKey)
        XCTAssertEqual(viewModel.statusMessage, "API Key Saved")
        
        // Step 2: User triggers global hotkey (⌃⌥S) to start tutoring session
        hotkeys.triggerSessionHotkey()
        
        // Wait briefly for async task execution
        try await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertTrue(viewModel.isSessionActive)
        XCTAssertTrue(geminiClient.isConnected)
        XCTAssertTrue(screenCap.isCapturing)
        XCTAssertEqual(viewModel.currentModel, AppConfig.defaultPrimaryModel)
        
        // Step 3: Screen capture stream sends 1fps desktop image base64 frame
        let desktopFrame = "FRAME_2560_1440".data(using: .utf8)!
        screenCap.emitMockFrame(data: desktopFrame)
        XCTAssertEqual(geminiClient.sentImages.count, 1)
        
        // Step 4: User speaks into mic (16kHz PCM audio stream)
        let userVoicePCM = "USER_VOICE_PCM16_AUDIO".data(using: .utf8)!
        audioEngine.simulateMicrophoneInput(pcmData: userVoicePCM)
        XCTAssertEqual(geminiClient.sentAudioChunks.count, 1)
        
        // Step 5: Gemini Live Server streams tutor response transcript and 24kHz audio chunks
        geminiClient.simulateServerTranscript(speaker: "User", text: "How do I say 'cam on' in English?")
        geminiClient.simulateServerTranscript(speaker: "Gemini", text: "You can say 'Thank you very much!'. How is your day going?")
        
        let tutorAudioResponse = "AI_24KHZ_AUDIO_RESPONSE_CHUNK".data(using: .utf8)!
        geminiClient.simulateServerAudio(data: tutorAudioResponse)
        XCTAssertTrue(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.playbackQueueCount, 1)
        
        // Step 6: User presses Mute hotkey (⌃⌥M)
        hotkeys.triggerMuteHotkey()
        XCTAssertTrue(viewModel.isMuted)
        XCTAssertTrue(audioEngine.isMuted)
        
        // Step 7: User interrupts AI speech playback (Barge-in VAD trigger)
        geminiClient.simulateUserBargeIn()
        XCTAssertFalse(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.playbackQueueCount, 0)
        
        // Step 8: User unmutes via hotkey (⌃⌥M)
        hotkeys.triggerMuteHotkey()
        XCTAssertFalse(viewModel.isMuted)
        XCTAssertFalse(audioEngine.isMuted)
        
        // Step 9: User ends session via Hotkey (⌃⌥S)
        hotkeys.triggerSessionHotkey()
        try await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(geminiClient.isConnected)
        XCTAssertFalse(screenCap.isCapturing)
        
        // Step 10: Export full transcript history to .txt string format
        let exportedTranscript = viewModel.exportTranscript()
        XCTAssertTrue(exportedTranscript.contains("User: How do I say 'cam on' in English?"))
        XCTAssertTrue(exportedTranscript.contains("Gemini: You can say 'Thank you very much!'. How is your day going?"))
        XCTAssertTrue(exportedTranscript.contains("System: [User Interrupted AI Playback]"))
    }
}
