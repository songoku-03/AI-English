import Foundation

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var config: AppConfig
    @Published public var isSessionActive: Bool = false
    @Published public var isConnected: Bool = false
    @Published public var isMuted: Bool = false
    @Published public var isCapturing: Bool = false
    @Published public var liveSubtitle: String = ""
    @Published public var statusMessage: String = "Ready"
    @Published public var currentModel: String = AppConfig.defaultPrimaryModel
    @Published public var transcriptEntries: [TranscriptEntry] = []

    public var transcripts: [TranscriptEntry] {
        get { transcriptEntries }
        set { transcriptEntries = newValue }
    }

    public let keychainService: KeychainServiceProtocol
    public let hotkeyService: GlobalHotkeyServiceProtocol
    public let screenCaptureService: ScreenCaptureServiceProtocol
    public let audioEngineService: AudioEngineServiceProtocol
    public let geminiLiveClient: GeminiLiveClientProtocol

    public init(
        config: AppConfig = AppConfig(),
        keychainService: KeychainServiceProtocol,
        hotkeyService: GlobalHotkeyServiceProtocol,
        screenCaptureService: ScreenCaptureServiceProtocol,
        audioEngineService: AudioEngineServiceProtocol,
        geminiLiveClient: GeminiLiveClientProtocol
    ) {
        self.config = config
        self.keychainService = keychainService
        self.hotkeyService = hotkeyService
        self.screenCaptureService = screenCaptureService
        self.audioEngineService = audioEngineService
        self.geminiLiveClient = geminiLiveClient

        // Retrieve existing API Key from Keychain if available
        if let storedKey = try? keychainService.retrieve(key: "gemini_api_key"), !storedKey.isEmpty {
            self.config.apiKey = storedKey
        }

        setupServiceCallbacks()
    }

    public convenience init(
        config: AppConfig = AppConfig(),
        keychainService: KeychainServiceProtocol,
        hotkeyService: GlobalHotkeyServiceProtocol,
        screenCaptureService: ScreenCaptureServiceProtocol,
        audioEngineService: AudioEngineServiceProtocol,
        geminiClient: GeminiLiveClientProtocol
    ) {
        self.init(
            config: config,
            keychainService: keychainService,
            hotkeyService: hotkeyService,
            screenCaptureService: screenCaptureService,
            audioEngineService: audioEngineService,
            geminiLiveClient: geminiClient
        )
    }

    private func setupServiceCallbacks() {
        // Register Global Hotkeys
        try? hotkeyService.registerHotkeys(
            onMuteToggle: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.toggleMute()
                }
            },
            onSessionToggle: { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.toggleSession()
                }
            }
        )

        // Gemini Callbacks - Protocol abstraction only, no downcasts!
        let client = geminiLiveClient
        client.onTranscript = { [weak self] speaker, text in
            Task { @MainActor [weak self] in
                self?.liveSubtitle = text
                self?.appendTranscript(TranscriptEntry(speaker: speaker, text: text))
            }
        }

        client.onAudioReceived = { [weak self] pcmData in
            Task { @MainActor [weak self] in
                self?.audioEngineService.playAudioChunk(data: pcmData)
            }
        }

        client.onInterrupted = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleBargeIn()
            }
        }
    }

    public func saveApiKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KeychainError.emptyKey
        }

        try keychainService.save(key: "gemini_api_key", value: trimmed)
        config.apiKey = trimmed
        statusMessage = "API Key Saved"
    }

    public func saveAPIKey(_ key: String) throws {
        try saveApiKey(key)
    }

    public func toggleSession() async {
        if isSessionActive {
            await stopSession()
        } else {
            await startSession()
        }
    }

    public func startSession() {
        Task {
            await startSession()
        }
    }

    public func startSession() async {
        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            isSessionActive = false
            isConnected = false
            statusMessage = "Error: API Key is required"
            return
        }

        do {
            try await geminiLiveClient.connect(apiKey: key)
            currentModel = geminiLiveClient.currentModel
            isConnected = true
            isSessionActive = true

            try? audioEngineService.startInputStreaming { [weak self] pcmData in
                Task { @MainActor [weak self] in
                    guard let self = self, !self.isMuted else { return }
                    self.geminiLiveClient.sendAudio(data: pcmData)
                }
            }

            try? await screenCaptureService.startCapture { [weak self] frameData in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isSessionActive else { return }
                    let base64 = frameData.base64EncodedString()
                    self.geminiLiveClient.sendImage(base64JPEG: base64)
                }
            }

            isCapturing = screenCaptureService.isCapturing
            statusMessage = "Session Active"
        } catch {
            isSessionActive = false
            isConnected = false
            isCapturing = false
            statusMessage = "Session Start Failed: \(error.localizedDescription)"
        }
    }

    public func stopSession() {
        Task {
            await stopSession()
        }
    }

    public func stopSession() async {
        screenCaptureService.stopCapture()
        audioEngineService.stopAudio()
        geminiLiveClient.disconnect()

        isSessionActive = false
        isConnected = false
        isCapturing = false
        statusMessage = "Session Stopped"
    }

    public func toggleMute() {
        isMuted.toggle()
        var engine = audioEngineService
        engine.isMuted = isMuted
        statusMessage = isMuted ? "Microphone Muted" : "Microphone Active"
    }

    public func handleBargeIn() {
        audioEngineService.interruptPlayback()
        appendTranscript(TranscriptEntry(speaker: "System", text: "[User Interrupted AI Playback]"))
    }

    public func appendTranscript(_ entry: TranscriptEntry) {
        transcriptEntries.append(entry)
    }

    public func clearTranscripts() {
        transcriptEntries.removeAll()
        liveSubtitle = ""
    }

    public func exportTranscript() -> String {
        return transcriptEntries.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
    }
}
