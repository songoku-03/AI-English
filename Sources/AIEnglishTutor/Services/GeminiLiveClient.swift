import Foundation

public final class GeminiLiveClient: GeminiLiveClientProtocol, @unchecked Sendable {
    private let lock = NSLock()

    public var onTranscript: ((_ speaker: String, _ text: String) -> Void)?
    public var onAudioReceived: ((_ pcmData: Data) -> Void)?
    public var onError: ((_ error: Error) -> Void)?
    public var onInterrupted: (() -> Void)?

    private var currentModelInternal: String = AppConfig.defaultPrimaryModel
    public var currentModel: String {
        lock.lock()
        defer { lock.unlock() }
        return currentModelInternal
    }

    public private(set) var reconnectAttempts: Int = 0

    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnectedInternal: Bool = false
    private var activeApiKey: String = ""

    public init() {}

    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isConnectedInternal
    }

    private func updateCurrentModel(_ model: String) {
        lock.lock()
        defer { lock.unlock() }
        self.currentModelInternal = model
    }

    private func setWebSocketTask(_ task: URLSessionWebSocketTask?) {
        lock.lock()
        defer { lock.unlock() }
        self.webSocketTask = task
        self.isConnectedInternal = (task != nil)
    }

    public func connect(apiKey: String) async throws {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw GeminiLiveError.emptyApiKey
        }

        self.activeApiKey = cleanKey
        self.reconnectAttempts = 0

        // Attempt connection with primary model first, fallback on failure
        do {
            try await establishConnection(model: AppConfig.defaultPrimaryModel, apiKey: cleanKey)
            updateCurrentModel(AppConfig.defaultPrimaryModel)
        } catch {
            // Fallback model attempt
            do {
                try await establishConnection(model: AppConfig.defaultFallbackModel, apiKey: cleanKey)
                updateCurrentModel(AppConfig.defaultFallbackModel)
            } catch {
                throw GeminiLiveError.connectionFailed(error.localizedDescription)
            }
        }
    }

    private func establishConnection(model: String, apiKey: String) async throws {
        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiLiveError.connectionFailed("Invalid WebSocket URL")
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        task.resume()

        setWebSocketTask(task)

        // Send Setup Message
        let setupMsg = GeminiMessage.makeSetup(
            model: model,
            voiceName: "Puck",
            systemPrompt: AppConfig.defaultSystemPrompt
        )
        let data = try JSONEncoder().encode(setupMsg)
        if let jsonString = String(data: data, encoding: .utf8) {
            try await task.send(.string(jsonString))
        }

        // Start Receive Loop
        listenForMessages(task: task)
    }

    private func listenForMessages(task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleIncomingWebSocketMessage(message)
                self.listenForMessages(task: task)

            case .failure(let error):
                self.handleConnectionDrop(error: error)
            }
        }
    }

    private func handleIncomingWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        var dataPayload: Data?

        switch message {
        case .string(let text):
            dataPayload = text.data(using: .utf8)
        case .data(let data):
            dataPayload = data
        @unknown default:
            break
        }

        guard let data = dataPayload,
              let geminiMsg = try? JSONDecoder().decode(GeminiMessage.self, from: data) else {
            return
        }

        if let serverContent = geminiMsg.serverContent {
            if serverContent.interrupted == true {
                onInterrupted?()
            }

            if let modelTurn = serverContent.modelTurn {
                for part in modelTurn.parts {
                    if let text = part.text, !text.isEmpty {
                        onTranscript?("Tutor", text)
                    }
                    if let inlineData = part.inlineData,
                       let pcmData = Data(base64Encoded: inlineData.data) {
                        onAudioReceived?(pcmData)
                    }
                }
            }
        }
    }

    private func handleConnectionDrop(error: Error) {
        lock.lock()
        let canRetry = isConnectedInternal && reconnectAttempts < 3
        if canRetry {
            reconnectAttempts += 1
        }
        isConnectedInternal = false
        let key = activeApiKey
        let model = currentModelInternal
        let attempts = reconnectAttempts
        lock.unlock()

        if canRetry {
            let backoffSeconds = UInt64(pow(2.0, Double(attempts - 1))) * 1_000_000_000
            Task {
                try? await Task.sleep(nanoseconds: backoffSeconds)
                do {
                    try await self.establishConnection(model: model, apiKey: key)
                } catch {
                    self.onError?(error)
                }
            }
        } else {
            onError?(GeminiLiveError.maxReconnectAttemptsExceeded)
        }
    }

    public func sendAudio(data: Data) {
        guard isConnected else { return }
        let base64 = data.base64EncodedString()
        let msg = GeminiMessage.pcmAudioInput(base64Data: base64)
        sendGeminiMessage(msg)
    }

    public func sendImage(base64JPEG: String) {
        guard isConnected else { return }
        let msg = GeminiMessage.jpegImageInput(base64Data: base64JPEG)
        sendGeminiMessage(msg)
    }

    private func sendGeminiMessage(_ msg: GeminiMessage) {
        guard let data = try? JSONEncoder().encode(msg),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        lock.lock()
        let task = webSocketTask
        lock.unlock()

        task?.send(.string(jsonString)) { _ in }
    }

    public func disconnect() {
        setWebSocketTask(nil)
    }
}
