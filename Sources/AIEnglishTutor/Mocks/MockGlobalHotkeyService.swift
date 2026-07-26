import Foundation

public final class MockGlobalHotkeyService: GlobalHotkeyServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()

    public private(set) var isRegistered: Bool = false
    public var shouldFailRegistration: Bool = false
    public var shouldFailToRegister: Bool {
        get { shouldFailRegistration }
        set { shouldFailRegistration = newValue }
    }

    public var muteToggleHandler: (@Sendable () -> Void)?
    public var sessionToggleHandler: (@Sendable () -> Void)?

    public init() {}

    public func registerHotkeys(
        onMuteToggle: @escaping @Sendable () -> Void,
        onSessionToggle: @escaping @Sendable () -> Void
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        if shouldFailRegistration {
            throw HotkeyError.registrationFailed("Mock hotkey registration failed")
        }

        self.muteToggleHandler = onMuteToggle
        self.sessionToggleHandler = onSessionToggle
        self.isRegistered = true
    }

    public func unregisterHotkeys() {
        lock.lock()
        defer { lock.unlock() }

        self.muteToggleHandler = nil
        self.sessionToggleHandler = nil
        self.isRegistered = false
    }

    public func triggerMuteHotkey() {
        simulateMuteHotkey()
    }

    public func simulateMuteHotkey() {
        let handler: (@Sendable () -> Void)?
        lock.lock()
        handler = muteToggleHandler
        lock.unlock()
        handler?()
    }

    public func triggerSessionHotkey() {
        simulateSessionHotkey()
    }

    public func simulateSessionHotkey() {
        let handler: (@Sendable () -> Void)?
        lock.lock()
        handler = sessionToggleHandler
        lock.unlock()
        handler?()
    }
}
