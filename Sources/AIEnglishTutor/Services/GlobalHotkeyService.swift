import Foundation
import Carbon

private struct HotkeyTarget {
    static var onMuteToggle: (@Sendable () -> Void)?
    static var onSessionToggle: (@Sendable () -> Void)?
}

private func hotkeyEventHandlerProc(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )

    guard status == noErr else { return status }

    if hotkeyID.id == 1 {
        HotkeyTarget.onMuteToggle?()
        return noErr
    } else if hotkeyID.id == 2 {
        HotkeyTarget.onSessionToggle?()
        return noErr
    }

    return OSStatus(eventNotHandledErr)
}

public final class GlobalHotkeyService: GlobalHotkeyServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var isRegisteredInternal = false

    private var muteHotkeyRef: EventHotKeyRef?
    private var sessionHotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    public init() {}

    public var isRegistered: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRegisteredInternal
    }

    public func registerHotkeys(
        onMuteToggle: @escaping @Sendable () -> Void,
        onSessionToggle: @escaping @Sendable () -> Void
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isRegisteredInternal else {
            throw HotkeyError.alreadyRegistered
        }

        HotkeyTarget.onMuteToggle = onMuteToggle
        HotkeyTarget.onSessionToggle = onSessionToggle

        // Install Event Handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandlerProc,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            throw HotkeyError.registrationFailed("Failed to install Carbon event handler (OSStatus: \(installStatus))")
        }

        let modifiers = UInt32(controlKey | optionKey)

        // Register ⌃⌥M (Control + Option + M, KeyCode 46)
        var muteID = EventHotKeyID(signature: OSType(1001), id: 1)
        let muteStatus = RegisterEventHotKey(
            UInt32(46), // 'M'
            modifiers,
            muteID,
            GetApplicationEventTarget(),
            0,
            &muteHotkeyRef
        )

        // Register ⌃⌥S (Control + Option + S, KeyCode 1)
        var sessionID = EventHotKeyID(signature: OSType(1002), id: 2)
        let sessionStatus = RegisterEventHotKey(
            UInt32(1), // 'S'
            modifiers,
            sessionID,
            GetApplicationEventTarget(),
            0,
            &sessionHotkeyRef
        )

        if muteStatus != noErr || sessionStatus != noErr {
            unregisterInternal()
            throw HotkeyError.registrationFailed("Failed to register Carbon global hotkeys")
        }

        isRegisteredInternal = true
    }

    public func unregisterHotkeys() {
        lock.lock()
        defer { lock.unlock() }
        unregisterInternal()
    }

    private func unregisterInternal() {
        if let muteRef = muteHotkeyRef {
            UnregisterEventHotKey(muteRef)
            muteHotkeyRef = nil
        }
        if let sessionRef = sessionHotkeyRef {
            UnregisterEventHotKey(sessionRef)
            sessionHotkeyRef = nil
        }
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
            eventHandlerRef = nil
        }

        HotkeyTarget.onMuteToggle = nil
        HotkeyTarget.onSessionToggle = nil
        isRegisteredInternal = false
    }

    deinit {
        unregisterHotkeys()
    }
}
