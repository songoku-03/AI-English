import Foundation
import CoreGraphics
import AppKit

public struct DisplayInfo: Identifiable, Equatable, Hashable, Sendable {
    public let id: CGDirectDisplayID
    public let name: String
    public let width: Int
    public let height: Int
    public var isMain: Bool
    public var thumbnail: NSImage?

    public init(id: CGDirectDisplayID, name: String, width: Int, height: Int, isMain: Bool = false, thumbnail: NSImage? = nil) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.isMain = isMain
        self.thumbnail = thumbnail
    }

    public var displayName: String {
        "\(name) (\(width)x\(height))"
    }

    public static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.width == rhs.width && lhs.height == rhs.height && lhs.isMain == rhs.isMain
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(isMain)
    }
}

public enum ScreenCaptureError: Error, Equatable, Sendable {
    case permissionDenied
    case captureFailed(String)
    case noDisplayAvailable
    case notCapturing
    case invalidFrameData
}

public protocol ScreenCaptureServiceProtocol: Sendable {
    func getAvailableDisplays() async throws -> [DisplayInfo]
    func startCapture(displayID: CGDirectDisplayID?, frameRate: Int, maxDimension: Int, onFrame: @escaping @Sendable (Data) -> Void) async throws
    func startCapture(displayID: CGDirectDisplayID?, onFrame: @escaping @Sendable (Data) -> Void) async throws
    func startCapture(onFrame: @escaping @Sendable (Data) -> Void) async throws
    func stopCapture()
    func checkPermission() -> Bool
    func requestPermission() -> Bool
    func openScreenCaptureSettings()
    func resizeAndCompress(frameData: Data, maxWidth: CGFloat, compressionQuality: CGFloat) -> Data
    var isCapturing: Bool { get }
}

public extension ScreenCaptureServiceProtocol {
    func startCapture(displayID: CGDirectDisplayID? = nil, frameRate: Int = 1, maxDimension: Int = 1024, onFrame: @escaping @Sendable (Data) -> Void) async throws {
        try await startCapture(displayID: displayID, frameRate: frameRate, maxDimension: maxDimension, onFrame: onFrame)
    }

    func startCapture(displayID: CGDirectDisplayID?, onFrame: @escaping @Sendable (Data) -> Void) async throws {
        try await startCapture(displayID: displayID, frameRate: 1, maxDimension: 1024, onFrame: onFrame)
    }

    func startCapture(onFrame: @escaping @Sendable (Data) -> Void) async throws {
        try await startCapture(displayID: nil, frameRate: 1, maxDimension: 1024, onFrame: onFrame)
    }
}


