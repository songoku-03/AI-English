import Foundation
import CoreGraphics
import AppKit

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

    private func setCaptureState(isCapturing: Bool, handler: (@Sendable (Data) -> Void)?) {
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

        if let image = NSImage(data: frameData),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
           cgImage.width > 0 {
            let origWidth = Double(cgImage.width)
            lastProcessedWidth = min(origWidth, Double(maxWidth))
            let scaleRatio = CGFloat(lastProcessedWidth / origWidth)
            let targetWidth = CGFloat(lastProcessedWidth)
            let targetHeight = CGFloat(cgImage.height) * scaleRatio

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            if let context = CGContext(
                data: nil,
                width: max(1, Int(targetWidth)),
                height: max(1, Int(targetHeight)),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) {
                context.interpolationQuality = .high
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
                if let resizedCG = context.makeImage() {
                    let rep = NSBitmapImageRep(cgImage: resizedCG)
                    if let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) {
                        return jpegData
                    }
                }
            }
        }

        // Numeric scaling fallback for raw non-image binary data
        lastProcessedWidth = Double(maxWidth)
        guard !frameData.isEmpty else { return Data() }
        let scaleRatio = min(1.0, Double(maxWidth) / 1024.0)
        let targetLength = max(1, Int(Double(frameData.count) * scaleRatio))
        return frameData.prefix(targetLength)
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
