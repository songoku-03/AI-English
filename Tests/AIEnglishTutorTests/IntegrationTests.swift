#if canImport(XCTest)
import XCTest
#endif
@testable import AIEnglishTutor

final class IntegrationTests: XCTestCase, TestRunnable {
    func testMockServicesIntegrationFlow() async throws {
        let keychain = MockKeychainService()
        let hotkey = MockGlobalHotkeyService()
        let capture = MockScreenCaptureService(hasPermission: true)
        let audioEngine = MockAudioEngineService()
        let geminiClient = MockGeminiLiveClient()

        // 1. Save API Key to Keychain
        let apiKey = "test_integration_api_key_999"
        try keychain.save(key: "gemini_key", value: apiKey)
        let retrievedKey = try keychain.retrieve(key: "gemini_key")
        XCTAssertEqual(retrievedKey, apiKey)

        // 2. Connect Gemini Client
        try await geminiClient.connect(apiKey: retrievedKey!)
        XCTAssertTrue(geminiClient.isConnected)

        // 3. Register Global Hotkeys
        var sessionActive = true
        try hotkey.registerHotkeys(
            onMuteToggle: {},
            onSessionToggle: { sessionActive.toggle() }
        )
        XCTAssertTrue(hotkey.isRegistered)

        // 4. Start Audio & Screen Capture
        try audioEngine.startInputStreaming { pcm in
            geminiClient.sendAudio(data: pcm)
        }
        try await capture.startCapture { frameData in
            geminiClient.sendImage(base64JPEG: frameData.base64EncodedString())
        }

        XCTAssertTrue(audioEngine.isStreaming)
        XCTAssertTrue(capture.isCapturing)

        // 5. Simulate Audio and Video Inputs
        let samplePCM = Data([0x01, 0x02])
        audioEngine.simulateAudioInput(data: samplePCM)
        XCTAssertEqual(geminiClient.sentAudioChunks.count, 1)

        capture.simulateFrameWithSampleData()
        XCTAssertEqual(geminiClient.sentImages.count, 1)

        // 6. Simulate Server Response
        var receivedTranscript: TranscriptEntry?
        geminiClient.onTranscript = { speaker, text in
            receivedTranscript = TranscriptEntry(
                speaker: speaker == "user" ? .user : .tutor,
                text: text
            )
        }

        geminiClient.simulateServerTranscript(speaker: "tutor", text: "Integration test passed!")
        XCTAssertNotNil(receivedTranscript)
        XCTAssertEqual(receivedTranscript?.speaker, .tutor)
        XCTAssertEqual(receivedTranscript?.text, "Integration test passed!")

        // 7. Cleanup
        capture.stopCapture()
        audioEngine.stopAudio()
        geminiClient.disconnect()
        hotkey.unregisterHotkeys()

        XCTAssertFalse(capture.isCapturing)
        XCTAssertFalse(audioEngine.isStreaming)
        XCTAssertFalse(geminiClient.isConnected)
        XCTAssertFalse(hotkey.isRegistered)
    }

    public func runAllTests() async throws {
        setUp()
        try await testMockServicesIntegrationFlow()
        tearDown()
    }
}
