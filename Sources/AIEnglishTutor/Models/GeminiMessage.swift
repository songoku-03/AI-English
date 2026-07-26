import Foundation

/// WebSocket JSON message models for Google Gemini Live API.
public struct GeminiMessage: Codable, Equatable, Sendable {
    public var setup: SetupConfig?
    public var realtimeInput: RealtimeInput?
    public var clientContent: ClientContent?
    public var serverContent: ServerContent?
    public var setupComplete: SetupComplete?

    public init(
        setup: SetupConfig? = nil,
        realtimeInput: RealtimeInput? = nil,
        clientContent: ClientContent? = nil,
        serverContent: ServerContent? = nil,
        setupComplete: SetupComplete? = nil
    ) {
        self.setup = setup
        self.realtimeInput = realtimeInput
        self.clientContent = clientContent
        self.serverContent = serverContent
        self.setupComplete = setupComplete
    }
}

public typealias GeminiLiveMessage = GeminiMessage

public struct BidiGenerateContentSetup: Codable, Equatable, Sendable {
    public var model: String
    public var systemPrompt: String
    public var voiceName: String

    public init(model: String, systemPrompt: String = AppConfig.defaultSystemPrompt, voiceName: String = "Puck") {
        self.model = model
        self.systemPrompt = systemPrompt
        self.voiceName = voiceName
    }
}

public struct BidiGenerateContentRealtimeInput: Codable, Equatable, Sendable {
    public var mimeType: String
    public var base64Data: String

    public init(mimeType: String, base64Data: String) {
        self.mimeType = mimeType
        self.base64Data = base64Data
    }
}

// MARK: - Setup Models

public struct SetupConfig: Codable, Equatable, Sendable {
    public var model: String
    public var generationConfig: GenerationConfig?
    public var systemInstruction: SystemInstruction?

    public init(
        model: String = AppConfig.defaultPrimaryModel,
        generationConfig: GenerationConfig? = nil,
        systemInstruction: SystemInstruction? = nil
    ) {
        self.model = model
        self.generationConfig = generationConfig
        self.systemInstruction = systemInstruction
    }
}

public struct GenerationConfig: Codable, Equatable, Sendable {
    public var responseModalities: [String]?
    public var speechConfig: SpeechConfig?

    public init(
        responseModalities: [String]? = ["AUDIO"],
        speechConfig: SpeechConfig? = nil
    ) {
        self.responseModalities = responseModalities
        self.speechConfig = speechConfig
    }
}

public struct SpeechConfig: Codable, Equatable, Sendable {
    public var voiceConfig: VoiceConfig?

    public init(voiceConfig: VoiceConfig? = nil) {
        self.voiceConfig = voiceConfig
    }
}

public struct VoiceConfig: Codable, Equatable, Sendable {
    public var prebuiltVoiceConfig: PrebuiltVoiceConfig?

    public init(prebuiltVoiceConfig: PrebuiltVoiceConfig? = nil) {
        self.prebuiltVoiceConfig = prebuiltVoiceConfig
    }
}

public struct PrebuiltVoiceConfig: Codable, Equatable, Sendable {
    public var voiceName: String

    public init(voiceName: String) {
        self.voiceName = voiceName
    }
}

public struct SystemInstruction: Codable, Equatable, Sendable {
    public var parts: [TextPart]

    public init(parts: [TextPart]) {
        self.parts = parts
    }
}

public struct TextPart: Codable, Equatable, Sendable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}

// MARK: - Realtime Input Models

public struct RealtimeInput: Codable, Equatable, Sendable {
    public var mediaChunks: [MediaChunk]

    public init(mediaChunks: [MediaChunk]) {
        self.mediaChunks = mediaChunks
    }
}

public struct MediaChunk: Codable, Equatable, Sendable {
    public var mimeType: String
    public var data: String

    public init(mimeType: String, data: String) {
        self.mimeType = mimeType
        self.data = data
    }
}

// MARK: - Client Content Models

public struct ClientContent: Codable, Equatable, Sendable {
    public var turns: [ContentTurn]
    public var turnComplete: Bool?

    public init(turns: [ContentTurn], turnComplete: Bool? = true) {
        self.turns = turns
        self.turnComplete = turnComplete
    }
}

public struct ContentTurn: Codable, Equatable, Sendable {
    public var role: String
    public var parts: [ContentPart]

    public init(role: String, parts: [ContentPart]) {
        self.role = role
        self.parts = parts
    }
}

public struct ContentPart: Codable, Equatable, Sendable {
    public var text: String?
    public var inlineData: MediaChunk?

    public init(text: String? = nil, inlineData: MediaChunk? = nil) {
        self.text = text
        self.inlineData = inlineData
    }
}

// MARK: - Server Content Models

public struct ServerContent: Codable, Equatable, Sendable {
    public var modelTurn: ContentTurn?
    public var turnComplete: Bool?
    public var interrupted: Bool?

    public init(modelTurn: ContentTurn? = nil, turnComplete: Bool? = nil, interrupted: Bool? = nil) {
        self.modelTurn = modelTurn
        self.turnComplete = turnComplete
        self.interrupted = interrupted
    }
}

public struct SetupComplete: Codable, Equatable, Sendable {
    public init() {}
}

// MARK: - Helper Constructors

extension GeminiMessage {
    public static func makeSetup(
        model: String = AppConfig.defaultPrimaryModel,
        voiceName: String = "Puck",
        systemPrompt: String
    ) -> GeminiMessage {
        let voiceConfig = VoiceConfig(prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: voiceName))
        let speechConfig = SpeechConfig(voiceConfig: voiceConfig)
        let genConfig = GenerationConfig(responseModalities: ["AUDIO"], speechConfig: speechConfig)
        let sysInstruction = SystemInstruction(parts: [TextPart(text: systemPrompt)])
        let setup = SetupConfig(model: model, generationConfig: genConfig, systemInstruction: sysInstruction)
        return GeminiMessage(setup: setup)
    }

    public static func pcmAudioInput(base64Data: String, sampleRate: Int = 16000) -> GeminiMessage {
        let chunk = MediaChunk(mimeType: "audio/pcm;rate=\(sampleRate)", data: base64Data)
        return GeminiMessage(realtimeInput: RealtimeInput(mediaChunks: [chunk]))
    }

    public static func jpegImageInput(base64Data: String) -> GeminiMessage {
        let chunk = MediaChunk(mimeType: "image/jpeg", data: base64Data)
        return GeminiMessage(realtimeInput: RealtimeInput(mediaChunks: [chunk]))
    }

    public static func textInput(text: String, role: String = "user") -> GeminiMessage {
        let part = ContentPart(text: text)
        let turn = ContentTurn(role: role, parts: [part])
        return GeminiMessage(clientContent: ClientContent(turns: [turn], turnComplete: true))
    }
}
