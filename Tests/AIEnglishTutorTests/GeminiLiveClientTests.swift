#if canImport(XCTest)
import XCTest
#endif
@testable import AIEnglishTutor

final class GeminiLiveClientTests: XCTestCase, TestRunnable {
    var mockGeminiClient: MockGeminiLiveClient!

    override func setUp() {
        super.setUp()
        mockGeminiClient = MockGeminiLiveClient()
    }

    override func tearDown() {
        mockGeminiClient = nil
        super.tearDown()
    }

    func testConnectAndSendPayloads() async throws {
        let validKey = "AIzaSyD-ValidKey123456"
        try await mockGeminiClient.connect(apiKey: validKey)

        XCTAssertTrue(mockGeminiClient.isConnected)
        XCTAssertEqual(mockGeminiClient.currentModel, AppConfig.defaultPrimaryModel)

        let audioChunk = Data([0x01, 0x02])
        mockGeminiClient.sendAudio(data: audioChunk)
        XCTAssertEqual(mockGeminiClient.sentAudioChunks.count, 1)

        mockGeminiClient.sendImage(base64JPEG: "base64image")
        XCTAssertEqual(mockGeminiClient.sentImages.count, 1)

        mockGeminiClient.disconnect()
        XCTAssertFalse(mockGeminiClient.isConnected)
    }

    func testModelFallbackOnConnectionFailure() async throws {
        mockGeminiClient.shouldFailPrimaryModel = true
        try await mockGeminiClient.connect(apiKey: "AIzaSyD-ValidKey123456")

        XCTAssertTrue(mockGeminiClient.isConnected)
        XCTAssertEqual(mockGeminiClient.currentModel, AppConfig.defaultFallbackModel)
    }

    func testGeminiMessageJSONEncodingAndDecoding() throws {
        // Setup message
        let setupMsg = GeminiMessage.makeSetup(
            model: "gemini-3.1-flash-live",
            voiceName: "Puck",
            systemPrompt: "You are an English tutor."
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let setupData = try encoder.encode(setupMsg)
        let decodedSetup = try decoder.decode(GeminiMessage.self, from: setupData)

        XCTAssertEqual(decodedSetup.setup?.model, "gemini-3.1-flash-live")
        XCTAssertEqual(decodedSetup.setup?.generationConfig?.speechConfig?.voiceConfig?.prebuiltVoiceConfig?.voiceName, "Puck")
        XCTAssertEqual(decodedSetup.setup?.systemInstruction?.parts.first?.text, "You are an English tutor.")

        // Audio Input Message
        let audioMsg = GeminiMessage.pcmAudioInput(base64Data: "SGVsbG8=")
        let audioData = try encoder.encode(audioMsg)
        let decodedAudio = try decoder.decode(GeminiMessage.self, from: audioData)

        XCTAssertEqual(decodedAudio.realtimeInput?.mediaChunks.first?.mimeType, "audio/pcm;rate=16000")
        XCTAssertEqual(decodedAudio.realtimeInput?.mediaChunks.first?.data, "SGVsbG8=")

        // Server Content Response Message
        let serverContent = ServerContent(
            modelTurn: ContentTurn(role: "model", parts: [ContentPart(text: "Hello, student!")]),
            turnComplete: true,
            interrupted: false
        )
        let serverMsg = GeminiMessage(serverContent: serverContent)
        let serverData = try encoder.encode(serverMsg)
        let decodedServer = try decoder.decode(GeminiMessage.self, from: serverData)

        XCTAssertEqual(decodedServer.serverContent?.modelTurn?.parts.first?.text, "Hello, student!")
        XCTAssertEqual(decodedServer.serverContent?.interrupted, false)
    }

    public func runAllTests() async throws {
        setUp()
        try await testConnectAndSendPayloads()
        tearDown()

        setUp()
        try await testModelFallbackOnConnectionFailure()
        tearDown()

        setUp()
        try testGeminiMessageJSONEncodingAndDecoding()
        tearDown()
    }
}
