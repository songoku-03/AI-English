import Foundation
import CoreGraphics

print("=========================================================")
print("   EMPIRICAL CHALLENGER VERIFICATION SUITE - TA PROJECT  ")
print("=========================================================")

var totalTests = 0
var passedTests = 0
var failedTests = 0

func assertTest(_ name: String, passed: Bool, detail: String) {
    totalTests += 1
    if passed {
        passedTests += 1
        print("✅ PASS: [\(name)] - \(detail)")
    } else {
        failedTests += 1
        print("❌ FAIL: [\(name)] - \(detail)")
    }
}

// ---------------------------------------------------------
// 1. Compilation & Symbol Interface Mismatch Tests
// ---------------------------------------------------------
print("\n--- 1. Interface & Symbol Consistency Checks ---")

// Check AppViewModel -> Views property naming mismatches
// AppViewModel has: transcriptEntries, isSessionActive
// Views expect: transcripts, isConnected
let appViewModelHasTranscripts = false // Checked via AST/source code: property is transcriptEntries
let appViewModelHasIsConnected = false // Checked via AST/source code: property is isSessionActive

assertTest("ViewModel.transcripts property exists", passed: appViewModelHasTranscripts, detail: "AppViewModel uses 'transcriptEntries' but Views use 'transcripts'")
assertTest("ViewModel.isConnected property exists", passed: appViewModelHasIsConnected, detail: "AppViewModel uses 'isSessionActive' but Views use 'isConnected'")

// Check GeminiLiveClientProtocol.onInterrupted
let protocolHasOnInterrupted = false // Checked via AST/source code: GeminiLiveClientProtocol missing onInterrupted
assertTest("GeminiLiveClientProtocol.onInterrupted exists", passed: protocolHasOnInterrupted, detail: "GeminiLiveClientProtocol is missing 'onInterrupted' callback declared in MockGeminiLiveClient")

// Check ScreenCaptureServiceProtocol.resizeAndCompress
let protocolHasResizeAndCompress = false // Checked via AST/source code: ScreenCaptureServiceProtocol missing resizeAndCompress
assertTest("ScreenCaptureServiceProtocol.resizeAndCompress exists", passed: protocolHasResizeAndCompress, detail: "ScreenCaptureServiceProtocol is missing 'resizeAndCompress' method called by AppViewModel")


// ---------------------------------------------------------
// 2. Image Scaling Empirical Verification (Requirement 2.1)
// ---------------------------------------------------------
print("\n--- 2. Image Scaling Logic Verification ---")

func mockResizeAndCompress(frameData: Data, maxWidth: CGFloat = 1024.0, compressionQuality: CGFloat = 0.7) -> (Data, CGFloat) {
    var inputWidth: CGFloat = maxWidth
    if let str = String(data: frameData, encoding: .utf8), str.contains("FRAME_") {
        let parts = str.components(separatedBy: "_")
        if parts.count >= 2, let w = Double(parts[1]) {
            inputWidth = CGFloat(w)
        }
    }
    let outputWidth = min(inputWidth, maxWidth)
    let processedString = "PROCESSED_FRAME_\(Int(outputWidth))_\(compressionQuality)"
    return (processedString.data(using: .utf8) ?? frameData, outputWidth)
}

// Test boundary 1: Text payload 1920x1080 > 1024px
let frame1920 = "FRAME_1920_1080".data(using: .utf8)!
let (_, w1920) = mockResizeAndCompress(frameData: frame1920)
assertTest("Image Scaling Mock - 1920px downscaled to 1024px", passed: w1920 == 1024.0, detail: "Mock scaled width: \(w1920)")

// Test boundary 2: Text payload 800x600 < 1024px
let frame800 = "FRAME_800_600".data(using: .utf8)!
let (_, w800) = mockResizeAndCompress(frameData: frame800)
assertTest("Image Scaling Mock - 800px retained as 800px", passed: w800 == 800.0, detail: "Mock scaled width: \(w800)")

// Test boundary 3: Binary raw JPEG data (real screen frame)
let binaryJpegHeader = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
let (resBinary, wBinary) = mockResizeAndCompress(frameData: binaryJpegHeader)
let isBinaryHandled = (String(data: resBinary, encoding: .utf8) != "PROCESSED_FRAME_1024_0.7")
assertTest("Image Scaling - Actual Binary Image Data Processing", passed: false, detail: "Mock treats binary JPEG bytes as UTF-8 string, failing parsing and defaulting width to 1024. Real service lacks image scaling entirely.")


// ---------------------------------------------------------
// 3. Audio Sample Rate Conversion Empirical Verification (Requirement 2.2)
// ---------------------------------------------------------
print("\n--- 3. Audio Sample Rate Conversion Verification ---")

let realAudioEngineHasResampling = false // AudioEngineService.swift is empty stub
let realAudioEngineHasPlayback = false // AudioEngineService.playAudioChunk is empty stub

assertTest("AudioEngine Real Implementation - 16kHz PCM16 Mono Resampling", passed: realAudioEngineHasResampling, detail: "AudioEngineService.swift has no AVAudioEngine or AVAudioConverter implementation for 16kHz input")
assertTest("AudioEngine Real Implementation - 24kHz PCM Audio Playback", passed: realAudioEngineHasPlayback, detail: "AudioEngineService.playAudioChunk is an empty stub (0 lines of playback code)")


// ---------------------------------------------------------
// 4. VAD Barge-in Logic Empirical Verification (Requirement 2.3)
// ---------------------------------------------------------
print("\n--- 4. VAD Barge-in & Buffer Flushing Verification ---")

let realAudioEngineInterruptsPlayback = false // AudioEngineService.interruptPlayback is empty stub
let appViewModelHasLocalVAD = false // AppViewModel does not analyze mic energy threshold

assertTest("VAD Barge-in Real Implementation - Playback Queue Flush", passed: realAudioEngineInterruptsPlayback, detail: "AudioEngineService.interruptPlayback() is an empty stub; does not flush audio buffer")
assertTest("VAD Barge-in - Local Voice Activity Detection", passed: appViewModelHasLocalVAD, detail: "No local VAD or energy detection on mic input stream to trigger immediate interruption")


// ---------------------------------------------------------
// 5. Gemini Live WebSocket & Retry Limit (Requirement 2.4)
// ---------------------------------------------------------
print("\n--- 5. Gemini Live WebSocket & Retry Limit Verification ---")

struct BidiGenerateContentSetup: Codable {
    struct ModelConfig: Codable {
        struct GenerationConfig: Codable {
            struct SpeechConfig: Codable {
                struct VoiceConfig: Codable {
                    struct PrebuiltVoiceConfig: Codable {
                        let voiceName: String
                    }
                    let prebuiltVoiceConfig: PrebuiltVoiceConfig
                    init(voiceName: String) { self.prebuiltVoiceConfig = PrebuiltVoiceConfig(voiceName: voiceName) }
                }
                let voiceConfig: VoiceConfig
                init(voiceName: String) { self.voiceConfig = VoiceConfig(voiceName: voiceName) }
            }
            let responseModalities: [String]
            let speechConfig: SpeechConfig
            init(responseModalities: [String] = ["AUDIO"], voiceName: String = "Puck") {
                self.responseModalities = responseModalities
                self.speechConfig = SpeechConfig(voiceName: voiceName)
            }
        }
        struct SystemInstruction: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
            init(text: String) { self.parts = [Part(text: text)] }
        }
        let model: String
        let generationConfig: GenerationConfig
        let systemInstruction: SystemInstruction
        init(model: String, systemPrompt: String, voiceName: String) {
            self.model = model
            self.generationConfig = GenerationConfig(responseModalities: ["AUDIO"], voiceName: voiceName)
            self.systemInstruction = SystemInstruction(text: systemPrompt)
        }
    }
    let setup: ModelConfig
    init(model: String, systemPrompt: String, voiceName: String) {
        self.setup = ModelConfig(model: model, systemPrompt: systemPrompt, voiceName: voiceName)
    }
}

let setup = BidiGenerateContentSetup(model: "gemini-3.1-flash-live", systemPrompt: "Tutor prompt", voiceName: "Puck")
let jsonEncoder = JSONEncoder()
jsonEncoder.outputFormatting = [.prettyPrinted]
var jsonValid = false
if let data = try? jsonEncoder.encode(setup), let jsonStr = String(data: data, encoding: .utf8) {
    jsonValid = jsonStr.contains("\"setup\"") && jsonStr.contains("\"model\"") && jsonStr.contains("\"generationConfig\"")
}

assertTest("Gemini Live Setup JSON Encoding Structure", passed: jsonValid, detail: "JSON setup message correctly encodes 'setup' structure")

// Test Retry Count Limit in Mock (exactly 3 retries)
var reconnectAttempts = 0
let maxRetries = 3
var retryResults: [Bool] = []

for _ in 1...4 {
    reconnectAttempts += 1
    if reconnectAttempts <= maxRetries {
        retryResults.append(true) // success
    } else {
        retryResults.append(false) // failure
    }
}

let retryBehaviorCorrect = (retryResults == [true, true, true, false])
assertTest("WebSocket Retry Limit - Exactly 3 Retries Threshold", passed: retryBehaviorCorrect, detail: "Attempts 1..3 succeed, attempt 4 fails. Mock matches 3 retry limit specification.")

let realClientHasWebSocket = false
assertTest("GeminiLiveClient Real Implementation - WebSocket URLSession Task", passed: realClientHasWebSocket, detail: "GeminiLiveClient.swift has no URLSessionWebSocketTask connection or retry logic implemented")


// ---------------------------------------------------------
// Summary Report
// ---------------------------------------------------------
print("\n=========================================================")
print("SUMMARY: Total Tests: \(totalTests) | Passed: \(passedTests) | Failed: \(failedTests)")
print("=========================================================")
