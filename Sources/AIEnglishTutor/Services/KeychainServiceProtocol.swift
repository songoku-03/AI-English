import Foundation

public enum KeychainError: Error, Equatable, Sendable {
    case emptyKey
    case emptyValue
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case unhandledError(message: String)
}

public protocol KeychainServiceProtocol: Sendable {
    func save(key: String, value: String) throws
    func retrieve(key: String) throws -> String?
    func delete(key: String) throws
}
