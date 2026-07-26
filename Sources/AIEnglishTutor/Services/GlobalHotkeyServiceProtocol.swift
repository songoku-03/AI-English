import Foundation

public enum HotkeyError: Error, Equatable, Sendable {
    case registrationFailed(String)
    case alreadyRegistered
    case notRegistered
}

public protocol GlobalHotkeyServiceProtocol: Sendable {
    func registerHotkeys(
        onMuteToggle: @escaping @Sendable () -> Void,
        onSessionToggle: @escaping @Sendable () -> Void
    ) throws
    func unregisterHotkeys()
}
