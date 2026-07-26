import Foundation
import CoreGraphics

// Import/Re-declare or compile against sources to test
// Let's test JSON encoding of BidiGenerateContentSetup
struct BidiGenerateContentSetup: Codable, Equatable {
    struct ModelConfig: Codable, Equatable {
        struct GenerationConfig: Codable, Equatable {
            struct SpeechConfig: Codable, Equatable {
                struct VoiceConfig: Codable, Equatable {
                    struct PrebuiltVoiceConfig: Codable, Equatable {
                        let voiceName: String
                    }
                    let prebuiltVoiceConfig: PrebuiltVoiceConfig
                    init(voiceName: String) {
                        self.prebuiltVoiceConfig = PrebuiltVoiceConfig(voiceName: voiceName)
                    }
                }
                let voiceConfig: VoiceConfig
                init(voiceName: String) {
                    self.voiceConfig = VoiceConfig(voiceName: voiceName)
                }
            }
            let responseModalities: [String]
            let speechConfig: SpeechConfig
            init(responseModalities: [String] = ["AUDIO"], voiceName: String = "Puck") {
                self.responseModalities = responseModalities
                self.speechConfig = SpeechConfig(voiceName: voiceName)
            }
        }
        struct SystemInstruction: Codable, Equatable {
            struct Part: Codable, Equatable {
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

print("=== EMPIRICAL TEST RUNNER FOR CHALLENGER 1 ===")

// 1. Test BidiGenerateContentSetup JSON Encoding
let setupMsg = BidiGenerateContentSetup(model: "models/gemini-2.0-flash-exp", systemPrompt: "Hello world", voiceName: "Puck")
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
if let data = try? encoder.encode(setupMsg), let jsonStr = String(data: data, encoding: .utf8) {
    print("--- JSON Setup Message Structure ---")
    print(jsonStr)
} else {
    print("ERROR: Failed to encode BidiGenerateContentSetup")
}

// 2. Test Real Image scaling logic with binary image data
func mockResizeAndCompress(frameData: Data, maxWidth: CGFloat = 1024.0, compressionQuality: CGFloat = 0.7) -> Data {
    var inputWidth: CGFloat = maxWidth
    if let str = String(data: frameData, encoding: .utf8), str.contains("FRAME_") {
        let parts = str.components(separatedBy: "_")
        if parts.count >= 2, let w = Double(parts[1]) {
            inputWidth = CGFloat(w)
        }
    }
    
    let outputWidth = min(inputWidth, maxWidth)
    let processedString = "PROCESSED_FRAME_\(Int(outputWidth))_\(compressionQuality)"
    return processedString.data(using: .utf8) ?? frameData
}

print("\n--- Image Scaling Empirical Test ---")
// Test A: Text mock payload "FRAME_1920_1080"
let textPayload = "FRAME_1920_1080".data(using: .utf8)!
let resA = mockResizeAndCompress(frameData: textPayload)
print("Text payload input -> result: \(String(data: resA, encoding: .utf8) ?? "nil")")

// Test B: Binary raw image data (e.g. JPEG bytes / random binary bytes)
let binaryPayload = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01])
let resB = mockResizeAndCompress(frameData: binaryPayload)
print("Binary payload input -> result string: \(String(data: resB, encoding: .utf8) ?? "binary data untouched")")

print("\n=== Verification Completed ===")
