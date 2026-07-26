import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import AIEnglishTutor

final class ModelTests: XCTestCase, TestRunnable {
    func testAppConfigDefaultsAndCodable() throws {
        let config = AppConfig(apiKey: "key_123")
        XCTAssertEqual(config.apiKey, "key_123")
        XCTAssertEqual(config.frameRate, 1)
        XCTAssertEqual(config.jpegQuality, 0.7)
        XCTAssertEqual(config.maxImageDimension, 1024)
        XCTAssertEqual(config.voiceName, "Puck")

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppConfig.self, from: data)
        XCTAssertEqual(config, decoded)
    }

    func testTranscriptEntryCodable() throws {
        let entry = TranscriptEntry(speaker: "Tutor", text: "Welcome to English practice!")
        XCTAssertEqual(entry.speaker, "Tutor")
        XCTAssertEqual(entry.text, "Welcome to English practice!")

        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TranscriptEntry.self, from: data)
        XCTAssertEqual(entry.id, decoded.id)
        XCTAssertEqual(entry.speaker, decoded.speaker)
        XCTAssertEqual(entry.text, decoded.text)
    }

    func testGeminiMessageSetupJSON() throws {
        let msg = GeminiMessage.makeSetup(
            model: "models/gemini-3.1-flash-live",
            voiceName: "Puck",
            systemPrompt: "You are an English tutor."
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(msg)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("gemini-3.1-flash-live"))
        XCTAssertTrue(jsonString.contains("Puck"))
        XCTAssertTrue(jsonString.contains("You are an English tutor."))

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GeminiMessage.self, from: data)
        XCTAssertEqual(decoded.setup?.model, "models/gemini-3.1-flash-live")
        XCTAssertEqual(decoded.setup?.generationConfig?.speechConfig?.voiceConfig?.prebuiltVoiceConfig?.voiceName, "Puck")
    }

    func testGeminiMessageRealtimeMediaInputJSON() throws {
        let base64Audio = "dGVzdGF1ZGlv" // base64 for "testaudio"
        let audioMsg = GeminiMessage.pcmAudioInput(base64Data: base64Audio, sampleRate: 16000)

        let encoder = JSONEncoder()
        let audioData = try encoder.encode(audioMsg)
        let decoder = JSONDecoder()
        let decodedAudioMsg = try decoder.decode(GeminiMessage.self, from: audioData)

        XCTAssertEqual(decodedAudioMsg.realtimeInput?.mediaChunks.first?.mimeType, "audio/pcm;rate=16000")
        XCTAssertEqual(decodedAudioMsg.realtimeInput?.mediaChunks.first?.data, base64Audio)

        let base64Image = "dGVzdGltYWdl" // base64 for "testimage"
        let imageMsg = GeminiMessage.jpegImageInput(base64Data: base64Image)
        let imageData = try encoder.encode(imageMsg)
        let decodedImageMsg = try decoder.decode(GeminiMessage.self, from: imageData)

        XCTAssertEqual(decodedImageMsg.realtimeInput?.mediaChunks.first?.mimeType, "image/jpeg")
        XCTAssertEqual(decodedImageMsg.realtimeInput?.mediaChunks.first?.data, base64Image)
    }

    func testGeminiServerContentDecoding() throws {
        let json = """
        {
          "serverContent": {
            "modelTurn": {
              "role": "model",
              "parts": [
                {
                  "text": "Great job! Let's continue."
                },
                {
                  "inlineData": {
                    "mimeType": "audio/pcm;rate=24000",
                    "data": "cGNNMjQ="
                  }
                }
              ]
            },
            "turnComplete": true,
            "interrupted": false
          }
        }
        """

        let decoder = JSONDecoder()
        let msg = try decoder.decode(GeminiMessage.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(msg.serverContent?.modelTurn?.parts.first?.text, "Great job! Let's continue.")
        XCTAssertEqual(msg.serverContent?.modelTurn?.parts.last?.inlineData?.mimeType, "audio/pcm;rate=24000")
        XCTAssertEqual(msg.serverContent?.modelTurn?.parts.last?.inlineData?.data, "cGNNMjQ=")
        XCTAssertEqual(msg.serverContent?.turnComplete, true)
        XCTAssertEqual(msg.serverContent?.interrupted, false)
    }

    func testSessionRecordEncoding() throws {
        let errorItem = ExtractedErrorItem(
            originalSentence: "He go to school yesterday.",
            correctedSentence: "He went to school yesterday.",
            explanation: "Use past tense 'went' for yesterday.",
            category: "Grammar"
        )
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            durationSeconds: 120,
            transcripts: [TranscriptEntry(speaker: "Learner", text: "He go to school yesterday.")],
            extractedErrors: [errorItem]
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(record)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionRecord.self, from: data)
        XCTAssertEqual(decoded.extractedErrors.count, 1)
        XCTAssertEqual(decoded.extractedErrors.first?.correctedSentence, "He went to school yesterday.")
    }

    public func runAllTests() async throws {
        setUp()
        try testAppConfigDefaultsAndCodable()
        tearDown()

        setUp()
        try testTranscriptEntryCodable()
        tearDown()

        setUp()
        try testGeminiMessageSetupJSON()
        tearDown()

        setUp()
        try testGeminiMessageRealtimeMediaInputJSON()
        tearDown()

        setUp()
        try testGeminiServerContentDecoding()
        tearDown()

        setUp()
        try testSessionRecordEncoding()
        tearDown()
    }
}
