import Foundation

public final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var internalStore: [String: String] = [:]

    public var storage: [String: String] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return internalStore
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            internalStore = newValue
        }
    }

    public var shouldFailSave: Bool = false
    public var shouldFailRetrieve: Bool = false
    public var shouldFail: Bool = false
    public var errorToThrow: KeychainError?

    public init(initialStore: [String: String] = [:]) {
        self.internalStore = initialStore
    }

    public func save(key: String, value: String) throws {
        lock.lock()
        defer { lock.unlock() }

        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw KeychainError.emptyKey
        }

        if let error = errorToThrow {
            throw error
        }
        if shouldFail || shouldFailSave {
            throw KeychainError.unhandledError(message: "Mock save failure")
        }

        internalStore[key] = value
    }

    public func retrieve(key: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }

        if let error = errorToThrow {
            throw error
        }
        if shouldFail || shouldFailRetrieve {
            throw KeychainError.unhandledError(message: "Mock retrieve failure")
        }

        return internalStore[key]
    }

    public func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        if let error = errorToThrow {
            throw error
        }
        if shouldFail {
            throw KeychainError.unhandledError(message: "Mock delete failure")
        }

        internalStore.removeValue(forKey: key)
    }

    public func contains(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return internalStore[key] != nil
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        internalStore.removeAll()
    }
}
