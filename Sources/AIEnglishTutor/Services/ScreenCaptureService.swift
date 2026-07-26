import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import AppKit

private final class ScreenCaptureStreamHandler: NSObject, SCStreamOutput, @unchecked Sendable {
    private let onFrame: @Sendable (Data) -> Void
    private weak var service: ScreenCaptureService?

    init(service: ScreenCaptureService, onFrame: @escaping @Sendable (Data) -> Void) {
        self.service = service
        self.onFrame = onFrame
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        if let compressed = service?.processCGImage(cgImage, maxWidth: 1024.0, compressionQuality: 0.7) {
            onFrame(compressed)
        }
    }
}

public final class ScreenCaptureService: ScreenCaptureServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    public private(set) var isCapturing: Bool = false
    private var stream: SCStream?
    private var streamHandler: ScreenCaptureStreamHandler?

    public init() {}

    public func checkPermission() -> Bool {
        if #available(macOS 14.0, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    private func tryStartCapturing() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if isCapturing { return false }
        return true
    }

    private func finalizeCaptureStart(stream: SCStream, streamHandler: ScreenCaptureStreamHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.stream = stream
        self.streamHandler = streamHandler
        self.isCapturing = true
    }

    public func startCapture(onFrame: @escaping @Sendable (Data) -> Void) async throws {
        guard checkPermission() else {
            throw ScreenCaptureError.permissionDenied
        }

        guard tryStartCapturing() else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let mainDisplay = content.displays.first else {
            throw ScreenCaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: mainDisplay, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = mainDisplay.width
        config.height = mainDisplay.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1fps
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let streamHandler = ScreenCaptureStreamHandler(service: self, onFrame: onFrame)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        try stream.addStreamOutput(streamHandler, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))
        try await stream.startCapture()

        finalizeCaptureStart(stream: stream, streamHandler: streamHandler)
    }

    public func stopCapture() {
        lock.lock()
        let currentStream = stream
        stream = nil
        streamHandler = nil
        isCapturing = false
        lock.unlock()

        currentStream?.stopCapture { _ in }
    }

    public func processCGImage(_ cgImage: CGImage, maxWidth: CGFloat, compressionQuality: CGFloat) -> Data {
        let origWidth = CGFloat(cgImage.width)
        let origHeight = CGFloat(cgImage.height)

        let targetWidth = min(origWidth, maxWidth)
        let scaleRatio = targetWidth / origWidth
        let targetHeight = origHeight * scaleRatio

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: Int(targetWidth),
            height: Int(targetHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) ?? Data()
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let resizedCGImage = context.makeImage() else {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) ?? Data()
        }

        let bitmapRep = NSBitmapImageRep(cgImage: resizedCGImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) ?? Data()
    }

    public func resizeAndCompress(frameData: Data, maxWidth: CGFloat, compressionQuality: CGFloat) -> Data {
        if let nsImage = NSImage(data: frameData),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return processCGImage(cgImage, maxWidth: maxWidth, compressionQuality: compressionQuality)
        }
        return frameData
    }
}
