import Foundation
#if canImport(XCTest)
import XCTest
#endif
import AppKit
@testable import AIEnglishTutor

@MainActor
final class Tier4RealWorldScenarioTests: XCTestCase, TestRunnable {
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

    // Full Real-World Scenario: Mute -> Talk -> Barge-in -> Unmute -> Export Transcript Workflow
    func testFullRealWorldTutorSessionWorkflow() async throws {
        // Step 1: User saves API key to macOS Keychain
        let apiKey = "AIzaSyD-RealWorldTutorKey12345"
        try viewModel.saveApiKey(apiKey)
        XCTAssertEqual(viewModel.config.apiKey, apiKey)
        XCTAssertEqual(viewModel.statusMessage, "API Key Saved")

        // Step 2: User triggers global hotkey (⌃⌥S) to start tutoring session
        hotkeys.triggerSessionHotkey()
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.isSessionActive)
        XCTAssertTrue(geminiClient.isConnected)
        XCTAssertTrue(screenCap.isCapturing)
        XCTAssertEqual(viewModel.currentModel, AppConfig.defaultPrimaryModel)

        // Step 3: Screen capture stream sends 1fps desktop image base64 frame
        let desktopFrame = createTestImageData(width: 2560, height: 1440)
        screenCap.emitMockFrame(data: desktopFrame)
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(geminiClient.sentImages.count, 1)

        // Step 4: User speaks into mic (16kHz PCM audio stream)
        let userVoicePCM = "USER_VOICE_PCM16_AUDIO".data(using: .utf8)!
        audioEngine.simulateMicrophoneInput(pcmData: userVoicePCM)
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(geminiClient.sentAudioChunks.count, 1)

        // Step 5: Gemini Live Server streams tutor response transcript and 24kHz audio chunks
        geminiClient.simulateServerTranscript(speaker: "User", text: "How do I say 'cam on' in English?")
        geminiClient.simulateServerTranscript(speaker: "Gemini", text: "You can say 'Thank you very much!'. How is your day going?")
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        let tutorAudioResponse = "AI_24KHZ_AUDIO_RESPONSE_CHUNK".data(using: .utf8)!
        geminiClient.simulateServerAudio(data: tutorAudioResponse)
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.playbackQueueCount, 1)

        // Step 6: User presses Mute hotkey (⌃⌥M)
        hotkeys.triggerMuteHotkey()
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.isMuted)
        XCTAssertTrue(audioEngine.isMuted)

        // Step 7: User interrupts AI speech playback (Barge-in VAD trigger)
        geminiClient.simulateUserBargeIn()
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(audioEngine.isPlaying)
        XCTAssertEqual(audioEngine.playbackQueueCount, 0)

        // Step 8: User unmutes via hotkey (⌃⌥M)
        hotkeys.triggerMuteHotkey()
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(viewModel.isMuted)
        XCTAssertFalse(audioEngine.isMuted)

        // Step 9: User ends session via Hotkey (⌃⌥S)
        hotkeys.triggerSessionHotkey()
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(geminiClient.isConnected)
        XCTAssertFalse(screenCap.isCapturing)

        // Step 10: Export full transcript history to .txt string format
        let exportedTranscript = viewModel.exportTranscript()
        XCTAssertTrue(exportedTranscript.contains("User: How do I say 'cam on' in English?"))
        XCTAssertTrue(exportedTranscript.contains("Gemini: You can say 'Thank you very much!'. How is your day going?"))
        XCTAssertTrue(exportedTranscript.contains("System: [User Interrupted AI Playback]"))
    }

    @MainActor
    public func runAllTests() async throws {
        setUp()
        try await testFullRealWorldTutorSessionWorkflow()
        tearDown()
    }
}
