import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import AppKit
import CryptoKit

private final class ScreenCaptureStreamHandler: NSObject, SCStreamOutput, @unchecked Sendable {
    private let onFrame: @Sendable (Data) -> Void
    private weak var service: ScreenCaptureService?
    private let sharedContext = CIContext()

    init(service: ScreenCaptureService, onFrame: @escaping @Sendable (Data) -> Void) {
        self.service = service
        self.onFrame = onFrame
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = sharedContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        guard let service = service else { return }
        let compressed = service.processCGImage(cgImage, maxWidth: CGFloat(service.maxDimension), compressionQuality: 0.7)
        if service.shouldEmitFrame(jpegData: compressed) {
            onFrame(compressed)
        }
    }
}

public final class ScreenCaptureService: ScreenCaptureServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    public private(set) var isCapturing: Bool = false
    public private(set) var frameRate: Int = 1
    public private(set) var maxDimension: Int = 1024
    private var stream: SCStream?
    private var streamHandler: ScreenCaptureStreamHandler?
    private var lastFrameHash: String?
    private var lastFrameEmittedTime: Date?

    public init() {}

    public func checkPermission() -> Bool {
        if #available(macOS 14.0, *) {
            if CGPreflightScreenCaptureAccess() {
                return true
            }
        }
        if let cgImage = CGDisplayCreateImage(CGMainDisplayID()), cgImage.width > 1 {
            return true
        }
        return false
    }

    public func requestPermission() -> Bool {
        if checkPermission() {
            return true
        }
        if #available(macOS 14.0, *) {
            return CGRequestScreenCaptureAccess()
        }
        return true
    }

    public func openScreenCaptureSettings() {
        let _ = requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
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
        self.lastFrameHash = nil
        self.lastFrameEmittedTime = nil
    }

    public func getAvailableDisplays() async throws -> [DisplayInfo] {
        if checkPermission() {
            if let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) {
                let mainID = CGMainDisplayID()
                let displays = content.displays.enumerated().map { index, display in
                    let isMain = (display.displayID == mainID) || (index == 0)
                    let name = isMain ? "Main Display" : "Display \(index + 1)"
                    var thumbnail: NSImage? = nil
                    if let cgImage = CGDisplayCreateImage(display.displayID) {
                        let jpegData = processCGImage(cgImage, maxWidth: 320.0, compressionQuality: 0.7)
                        thumbnail = NSImage(data: jpegData)
                    }
                    return DisplayInfo(
                        id: display.displayID,
                        name: name,
                        width: display.width,
                        height: display.height,
                        isMain: isMain,
                        thumbnail: thumbnail
                    )
                }
                if !displays.isEmpty { return displays }
            }
        }

        // Quartz Display Services fallback (Always works for physical screen enumeration)
        var displayCount: UInt32 = 0
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        CGGetActiveDisplayList(16, &activeDisplays, &displayCount)

        let mainID = CGMainDisplayID()
        return (0..<Int(displayCount)).map { index in
            let id = activeDisplays[index]
            let isMain = (id == mainID)
            let bounds = CGDisplayBounds(id)
            let name = isMain ? "Main Display" : "Display \(index + 1)"
            var thumbnail: NSImage? = nil
            if let cgImage = CGDisplayCreateImage(id) {
                let jpegData = processCGImage(cgImage, maxWidth: 320.0, compressionQuality: 0.7)
                thumbnail = NSImage(data: jpegData)
            }
            return DisplayInfo(
                id: id,
                name: name,
                width: Int(bounds.width),
                height: Int(bounds.height),
                isMain: isMain,
                thumbnail: thumbnail
            )
        }
    }


    public func startCapture(displayID: CGDirectDisplayID? = nil, frameRate: Int = 1, maxDimension: Int = 1024, onFrame: @escaping @Sendable (Data) -> Void) async throws {
        guard checkPermission() else {
            throw ScreenCaptureError.permissionDenied
        }

        guard tryStartCapturing() else { return }

        self.frameRate = frameRate
        self.maxDimension = maxDimension

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        let targetDisplay: SCDisplay
        if let displayID = displayID, let matched = content.displays.first(where: { $0.displayID == displayID }) {
            targetDisplay = matched
        } else if let mainDisplay = content.displays.first {
            targetDisplay = mainDisplay
        } else {
            throw ScreenCaptureError.noDisplayAvailable
        }

        let targetDisplayID = targetDisplay.displayID
        let config = SCStreamConfiguration()
        let targetWidth: Int
        let targetHeight: Int
        if maxDimension > 0 && max(targetDisplay.width, targetDisplay.height) > maxDimension {
            let scale = CGFloat(maxDimension) / CGFloat(max(targetDisplay.width, targetDisplay.height))
            targetWidth = max(2, (Int(CGFloat(targetDisplay.width) * scale) / 2) * 2)
            targetHeight = max(2, (Int(CGFloat(targetDisplay.height) * scale) / 2) * 2)
        } else {
            targetWidth = max(2, (targetDisplay.width / 2) * 2)
            targetHeight = max(2, (targetDisplay.height / 2) * 2)
        }
        config.width = targetWidth
        config.height = targetHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(1, frameRate)))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let streamHandler = ScreenCaptureStreamHandler(service: self, onFrame: onFrame)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        try stream.addStreamOutput(streamHandler, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))
        try await stream.startCapture()

        finalizeCaptureStart(stream: stream, streamHandler: streamHandler)

        // Immediately capture and emit Initial Frame #1 via CGDisplayCreateImage
        if let initialCGImage = CGDisplayCreateImage(targetDisplayID) {
            let compressed = processCGImage(initialCGImage, maxWidth: CGFloat(maxDimension), compressionQuality: 0.7)
            if shouldEmitFrame(jpegData: compressed) {
                onFrame(compressed)
            }
        }

        // Quartz Fallback Timer for 100% continuous frame delivery
        let interval = 1.0 / Double(max(1, min(15, frameRate)))
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.fallbackTimer?.invalidate()
            self.fallbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self, self.isCapturing else { return }
                if let cgImage = CGDisplayCreateImage(targetDisplayID) {
                    let compressed = self.processCGImage(cgImage, maxWidth: CGFloat(self.maxDimension), compressionQuality: 0.7)
                    if self.shouldEmitFrame(jpegData: compressed) {
                        onFrame(compressed)
                    }
                }
            }
        }
    }

    public func startCapture(displayID: CGDirectDisplayID?, onFrame: @escaping @Sendable (Data) -> Void) async throws {
        try await startCapture(displayID: displayID, frameRate: 1, maxDimension: 1024, onFrame: onFrame)
    }

    public func startCapture(onFrame: @escaping @Sendable (Data) -> Void) async throws {
        try await startCapture(displayID: nil, frameRate: 1, maxDimension: 1024, onFrame: onFrame)
    }

    public func stopCapture() {
        lock.lock()
        let currentStream = stream
        stream = nil
        streamHandler = nil
        isCapturing = false
        lastFrameHash = nil
        lastFrameEmittedTime = nil
        let timer = fallbackTimer
        fallbackTimer = nil
        lock.unlock()

        DispatchQueue.main.async {
            timer?.invalidate()
        }
        currentStream?.stopCapture { _ in }
    }

    public func shouldEmitFrame(jpegData: Data, timestamp: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if frameRate > 1 {
            lastFrameEmittedTime = timestamp
            return true
        }

        let hash = SHA256.hash(data: jpegData).compactMap { String(format: "%02x", $0) }.joined()

        if let lastHash = lastFrameHash, lastHash == hash {
            if let lastTime = lastFrameEmittedTime, timestamp.timeIntervalSince(lastTime) < 5.0 {
                return false
            }
        }

        lastFrameHash = hash
        lastFrameEmittedTime = timestamp
        return true
    }

    public func processCGImage(_ cgImage: CGImage, maxWidth: CGFloat, compressionQuality: CGFloat) -> Data {
        let origWidth = CGFloat(cgImage.width)
        let origHeight = CGFloat(cgImage.height)

        let targetWidth: CGFloat
        let targetHeight: CGFloat

        if maxWidth <= 0 {
            targetWidth = origWidth
            targetHeight = origHeight
        } else {
            let maxDim = max(origWidth, origHeight)
            if maxDim > maxWidth {
                let scaleRatio = maxWidth / maxDim
                targetWidth = origWidth * scaleRatio
                targetHeight = origHeight * scaleRatio
            } else {
                targetWidth = origWidth
                targetHeight = origHeight
            }
        }

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

