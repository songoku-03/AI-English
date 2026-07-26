import Foundation
import CoreGraphics

public enum ScreenCaptureError: Error, Equatable, Sendable {
    case permissionDenied
    case captureFailed(String)
    case noDisplayAvailable
    case notCapturing
    case invalidFrameData
}

public protocol ScreenCaptureServiceProtocol: Sendable {
    func startCapture(onFrame: @escaping @Sendable (Data) -> Void) async throws
    func stopCapture()
    func checkPermission() -> Bool
    func resizeAndCompress(frameData: Data, maxWidth: CGFloat, compressionQuality: CGFloat) -> Data
    var isCapturing: Bool { get }
}
