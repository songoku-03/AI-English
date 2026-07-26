#if canImport(XCTest)
import XCTest
#endif
import AppKit
@testable import AIEnglishTutor

final class ScreenCaptureTests: XCTestCase, TestRunnable {
    var mockScreenCaptureService: MockScreenCaptureService!
    var realScreenCaptureService: ScreenCaptureService!

    override func setUp() {
        super.setUp()
        mockScreenCaptureService = MockScreenCaptureService()
        realScreenCaptureService = ScreenCaptureService()
    }

    override func tearDown() {
        mockScreenCaptureService = nil
        realScreenCaptureService = nil
        super.tearDown()
    }

    func testStartAndStopCapture() async throws {
        var frameReceived = false
        try await mockScreenCaptureService.startCapture { _ in
            frameReceived = true
        }

        XCTAssertTrue(mockScreenCaptureService.isCapturing)
        mockScreenCaptureService.emitMockFrame(data: Data([0x01, 0x02]))
        XCTAssertTrue(frameReceived)

        mockScreenCaptureService.stopCapture()
        XCTAssertFalse(mockScreenCaptureService.isCapturing)
    }

    func testPermissionDeniedThrowsError() async {
        mockScreenCaptureService.hasPermission = false

        do {
            try await mockScreenCaptureService.startCapture { _ in }
            XCTFail("Should fail with permissionDenied")
        } catch {
            XCTAssertEqual(error as? ScreenCaptureError, ScreenCaptureError.permissionDenied)
        }
    }

    func testRealScreenCaptureServiceImageResizingAndCompression() {
        // Create a 1920x1080 test image bitmap
        let size = NSSize(width: 1920, height: 1080)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            XCTFail("Failed to create test CGImage")
            return
        }

        let compressedData = realScreenCaptureService.processCGImage(cgImage, maxWidth: 1024.0, compressionQuality: 0.7)
        XCTAssertFalse(compressedData.isEmpty)

        // Verify output is a valid JPEG image and has width <= 1024
        if let outputImage = NSImage(data: compressedData),
           let outputCGImage = outputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            XCTAssertLessThanOrEqual(outputCGImage.width, 1024)
            // Verify aspect ratio preservation: 1920/1080 = 1.777, 1024/576 = 1.777
            XCTAssertEqual(outputCGImage.height, 576)
        } else {
            XCTFail("Failed to decode processed JPEG data")
        }
    }

    public func runAllTests() async throws {
        setUp()
        try await testStartAndStopCapture()
        tearDown()

        setUp()
        await testPermissionDeniedThrowsError()
        tearDown()

        setUp()
        testRealScreenCaptureServiceImageResizingAndCompression()
        tearDown()
    }
}
