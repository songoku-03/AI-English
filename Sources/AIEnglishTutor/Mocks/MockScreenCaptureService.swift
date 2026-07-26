import Foundation
import CoreGraphics

public final class MockScreenCaptureService: ScreenCaptureServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()

    public private(set) var isCapturing: Bool = false
    public var hasPermission: Bool = true
    public var shouldFailToStart: Bool = false
    public private(set) var lastProcessedWidth: Double = 0.0

    public var onFrameCallback: (@Sendable (Data) -> Void)?

    public init(hasPermission: Bool = true) {
        self.hasPermission = hasPermission
    }

    public func checkPermission() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return hasPermission
    }

    private func setCaptureState(isCapturing: Bool, handler: ((Data) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        self.isCapturing = isCapturing
        self.onFrameCallback = handler
    }

    public func startCapture(onFrame: @escaping @Sendable (Data) -> Void) async throws {
        guard checkPermission() else {
            throw ScreenCaptureError.permissionDenied
        }

        if shouldFailToStart {
            throw ScreenCaptureError.captureFailed("Mock start capture failed")
        }

        setCaptureState(isCapturing: true, handler: onFrame)
    }

    public func stopCapture() {
        setCaptureState(isCapturing: false, handler: nil)
    }

    public func resizeAndCompress(frameData: Data, maxWidth: CGFloat, compressionQuality: CGFloat) -> Data {
        lock.lock()
        defer { lock.unlock() }

        let frameString = String(data: frameData, encoding: .utf8) ?? ""
        if frameString.contains("1920_1080") || frameString.contains("3840_2160") || frameString.contains("2560_1440") {
            lastProcessedWidth = min(Double(maxWidth), 1024.0)
        } else if frameString.contains("800_600") {
            lastProcessedWidth = 800.0
        } else {
            lastProcessedWidth = Double(maxWidth)
        }

        let outputStr = "PROCESSED_FRAME_\(Int(lastProcessedWidth))_\(compressionQuality)"
        return outputStr.data(using: .utf8) ?? frameData
    }

    public func emitMockFrame(data: Data) {
        let processed = resizeAndCompress(frameData: data, maxWidth: 1024.0, compressionQuality: 0.7)
        simulateFrame(data: processed)
    }

    public func simulateFrame(data: Data) {
        let handler: (@Sendable (Data) -> Void)?
        lock.lock()
        handler = onFrameCallback
        lock.unlock()
        handler?(data)
    }

    public func simulateFrameWithSampleData() {
        let dummyJPEGData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0xFF, 0xD9])
        simulateFrame(data: dummyJPEGData)
    }
}
