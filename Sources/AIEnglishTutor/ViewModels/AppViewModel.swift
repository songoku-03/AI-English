import Foundation
import CoreGraphics
import AppKit

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
    @Published public var availableDisplays: [DisplayInfo] = []
    @Published public var selectedDisplayID: CGDirectDisplayID? = nil
    @Published public var latestFrameImage: NSImage? = nil

    @Published public var savedSessions: [SessionRecord] = []
    @Published public var dailyQuizQuestions: [QuizQuestion] = []
    @Published public var selectedTab: Int = 0
    @Published public var showScreenPickerModal: Bool = false
    @Published public var hasScreenPermission: Bool = true
    @Published public var selectedFPS: Int = 1
    @Published public var selectedResolutionDimension: Int = 1280
    @Published public var audioLevel: Float = 0.0

    public var transcripts: [TranscriptEntry] {
        get { transcriptEntries }
        set { transcriptEntries = newValue }
    }

    public let keychainService: KeychainServiceProtocol
    public let hotkeyService: GlobalHotkeyServiceProtocol
    public let screenCaptureService: ScreenCaptureServiceProtocol
    public let audioEngineService: AudioEngineServiceProtocol
    public let geminiLiveClient: GeminiLiveClientProtocol
    public let sessionStorageService: SessionStorageServiceProtocol

    private var sessionStartTime: Date?
    private var permissionTimer: Timer?

    public init(
        config: AppConfig = AppConfig(),
        keychainService: KeychainServiceProtocol,
        hotkeyService: GlobalHotkeyServiceProtocol,
        screenCaptureService: ScreenCaptureServiceProtocol,
        audioEngineService: AudioEngineServiceProtocol,
        geminiLiveClient: GeminiLiveClientProtocol,
        sessionStorageService: SessionStorageServiceProtocol = SessionStorageService()
    ) {
        self.config = config
        self.keychainService = keychainService
        self.hotkeyService = hotkeyService
        self.screenCaptureService = screenCaptureService
        self.audioEngineService = audioEngineService
        self.geminiLiveClient = geminiLiveClient
        self.sessionStorageService = sessionStorageService
        self.hasScreenPermission = screenCaptureService.checkPermission()

        // Retrieve existing API Key from Keychain if available
        if let storedKey = try? keychainService.retrieve(key: "gemini_api_key"), !storedKey.isEmpty {
            self.config.apiKey = storedKey
        }

        setupServiceCallbacks()
        setupPermissionTimer()

        Task {
            await self.fetchAvailableDisplays()
            await self.loadSavedSessions()
        }
    }

    deinit {
        permissionTimer?.invalidate()
    }

    private func setupPermissionTimer() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let currentPermission = self.screenCaptureService.checkPermission()
                if !self.hasScreenPermission && currentPermission {
                    self.hasScreenPermission = true
                    await self.fetchAvailableDisplays()
                } else if self.hasScreenPermission != currentPermission {
                    self.hasScreenPermission = currentPermission
                }
            }
        }
    }

    public func fetchAvailableDisplays() async {
        if let displays = try? await screenCaptureService.getAvailableDisplays() {
            self.availableDisplays = displays
            if selectedDisplayID == nil, let first = displays.first {
                selectedDisplayID = first.id
            }
        }
    }

    public func loadSavedSessions() async {
        do {
            let sessions = try await sessionStorageService.loadAllSessions()
            self.savedSessions = sessions
            self.dailyQuizQuestions = QuizGeneratorService.generateQuiz(from: sessions)
        } catch {
            self.savedSessions = []
            self.dailyQuizQuestions = []
        }
    }

    public func deleteSession(id: UUID) async {
        try? await sessionStorageService.deleteSession(id: id)
        await loadSavedSessions()
    }

    public convenience init(
        config: AppConfig = AppConfig(),
        keychainService: KeychainServiceProtocol,
        hotkeyService: GlobalHotkeyServiceProtocol,
        screenCaptureService: ScreenCaptureServiceProtocol,
        audioEngineService: AudioEngineServiceProtocol,
        geminiClient: GeminiLiveClientProtocol,
        sessionStorageService: SessionStorageServiceProtocol = SessionStorageService()
    ) {
        self.init(
            config: config,
            keychainService: keychainService,
            hotkeyService: hotkeyService,
            screenCaptureService: screenCaptureService,
            audioEngineService: audioEngineService,
            geminiLiveClient: geminiClient,
            sessionStorageService: sessionStorageService
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

    public func openScreenCaptureSettings() {
        screenCaptureService.openScreenCaptureSettings()
    }

    public func startSession() {
        Task {
            await startSession()
        }
    }

    public func startSession() async {
        let _ = screenCaptureService.requestPermission()
        hasScreenPermission = screenCaptureService.checkPermission()

        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            isSessionActive = false
            isConnected = false
            statusMessage = "Error: API Key is required"
            return
        }

        if !isSessionActive {
            await fetchAvailableDisplays()
            showScreenPickerModal = true
        }
    }

    public func confirmScreenSelectionAndStartSession() {
        Task {
            await confirmScreenSelectionAndStartSession()
        }
    }

    public func confirmScreenSelectionAndStartSession() async {
        showScreenPickerModal = false

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
            isMuted = false
            var engine = audioEngineService
            engine.isMuted = false
            sessionStartTime = Date()

            try? audioEngineService.startInputStreaming(onPCMData: { [weak self] pcmData in
                Task { @MainActor [weak self] in
                    guard let self = self, !self.isMuted else { return }
                    self.geminiLiveClient.sendAudio(data: pcmData)
                }
            }, onAudioLevel: { [weak self] level in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.audioLevel = level
                }
            })

            try? await screenCaptureService.startCapture(
                displayID: selectedDisplayID,
                frameRate: selectedFPS,
                maxDimension: selectedResolutionDimension
            ) { [weak self] frameData in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isSessionActive else { return }
                    if let image = NSImage(data: frameData) {
                        self.latestFrameImage = image
                    }
                    let base64 = frameData.base64EncodedString()
                    self.geminiLiveClient.sendImage(base64JPEG: base64)
                }
            }

            isCapturing = screenCaptureService.isCapturing
            statusMessage = "Session Active"

            // Trigger AI Tutor initial interactive greeting
            appendTranscript(TranscriptEntry(
                speaker: "Tutor",
                text: "Hello! I am your AI English Tutor. I can see your screen live and hear your voice. What would you like to practice today?"
            ))
            if let mock = geminiLiveClient as? MockGeminiLiveClient {
                mock.simulateServerTranscript(
                    speaker: "Tutor",
                    text: "I am ready to help you improve your English accent, vocabulary, and grammar in real-time."
                )
            }
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
        let duration = sessionStartTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
        sessionStartTime = nil
        latestFrameImage = nil

        screenCaptureService.stopCapture()
        audioEngineService.stopAudio()
        geminiLiveClient.disconnect()

        isSessionActive = false
        isConnected = false
        isCapturing = false
        statusMessage = "Session Stopped"

        if !transcriptEntries.isEmpty {
            let extractedErrors = extractGrammarErrors(from: transcriptEntries)
            let record = SessionRecord(
                date: Date(),
                durationSeconds: max(1, duration),
                transcripts: transcriptEntries,
                extractedErrors: extractedErrors
            )
            try? await sessionStorageService.saveSession(record)
            await loadSavedSessions()
        }
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

    public func extractGrammarErrors(from entries: [TranscriptEntry]) -> [ExtractedErrorItem] {
        var errors: [ExtractedErrorItem] = []

        for entry in entries {
            let text = entry.text

            if text.contains("Correction:") || text.contains("Instead of") || text.contains("Original:") {
                if let errorItem = parseErrorItem(from: text) {
                    errors.append(errorItem)
                    continue
                }
            }

            if entry.speaker.lowercased().contains("tutor") || entry.speaker.lowercased().contains("gemini") {
                let regex = try? NSRegularExpression(pattern: "\"([^\"]+)\"[^\"\\n]*->[^\"\\n]*\"([^\"]+)\"", options: [])
                let nsString = text as NSString
                let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
                for match in matches {
                    if match.numberOfRanges >= 3 {
                        let original = nsString.substring(with: match.range(at: 1))
                        let corrected = nsString.substring(with: match.range(at: 2))
                        errors.append(ExtractedErrorItem(
                            originalSentence: original,
                            correctedSentence: corrected,
                            explanation: text,
                            category: "Grammar"
                        ))
                    }
                }
            }
        }

        return errors
    }

    private func parseErrorItem(from text: String) -> ExtractedErrorItem? {
        if text.contains("Original:") && text.contains("Corrected:") {
            let components = text.components(separatedBy: "Corrected:")
            if components.count == 2 {
                let origComp = components[0].replacingOccurrences(of: "Original:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let corrComp = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                return ExtractedErrorItem(
                    originalSentence: origComp,
                    correctedSentence: corrComp,
                    explanation: "Grammar correction from tutor",
                    category: "Grammar"
                )
            }
        }

        if text.contains("Instead of") {
            let pattern = "Instead of \"([^\"]+)\", (?:say|use) \"([^\"]+)\""
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = text as NSString
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
                   match.numberOfRanges >= 3 {
                    let orig = nsString.substring(with: match.range(at: 1))
                    let corr = nsString.substring(with: match.range(at: 2))
                    return ExtractedErrorItem(
                        originalSentence: orig,
                        correctedSentence: corr,
                        explanation: text,
                        category: "Grammar"
                    )
                }
            }
        }

        if text.contains("Correction:") {
            let cleaned = text.replacingOccurrences(of: "Correction:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = cleaned.components(separatedBy: "->")
            if parts.count == 2 {
                let orig = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let corr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return ExtractedErrorItem(
                    originalSentence: orig,
                    correctedSentence: corr,
                    explanation: "Correction identified during session",
                    category: "Grammar"
                )
            }
        }

        return nil
    }
}

