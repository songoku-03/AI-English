import Foundation
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
        let frameReceived = TestBox(false)
        try await mockScreenCaptureService.startCapture { _ in
            frameReceived.value = true
        }

        XCTAssertTrue(mockScreenCaptureService.isCapturing)
        mockScreenCaptureService.emitMockFrame(data: Data([0x01, 0x02]))
        XCTAssertTrue(frameReceived.value)

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

    func testMockScreenCaptureServiceImageResizingAndCompression() {
        let size = NSSize(width: 1920, height: 1080)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            XCTFail("Failed to create test CGImage")
            return
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let inputData = rep.representation(using: .jpeg, properties: [.compressionFactor: 1.0]) else {
            XCTFail("Failed to create JPEG data")
            return
        }

        let processedData = mockScreenCaptureService.resizeAndCompress(frameData: inputData, maxWidth: 1024.0, compressionQuality: 0.7)
        XCTAssertEqual(mockScreenCaptureService.lastProcessedWidth, 1024.0)
        XCTAssertFalse(processedData.isEmpty)

        if let outputImage = NSImage(data: processedData),
           let outputCG = outputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            XCTAssertLessThanOrEqual(outputCG.width, 1024)
        } else {
            XCTFail("Output should be valid JPEG data")
        }

        // Test non-image binary raw data numeric scaling fallback
        let rawBuffer = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let scaledRaw = mockScreenCaptureService.resizeAndCompress(frameData: rawBuffer, maxWidth: 1024.0, compressionQuality: 0.7)
        XCTAssertEqual(mockScreenCaptureService.lastProcessedWidth, 1024.0)
        XCTAssertFalse(scaledRaw.isEmpty)
    }

    func testFrameDeduplicationAndHeartbeat() {
        let data1 = Data([0x01, 0x02, 0x03, 0x04])
        let data2 = Data([0x05, 0x06, 0x07, 0x08])

        let start = Date()
        // 1. Initial frame should be emitted
        XCTAssertTrue(realScreenCaptureService.shouldEmitFrame(jpegData: data1, timestamp: start))

        // 2. Identical frame within 5s (1s later) should be skipped
        XCTAssertFalse(realScreenCaptureService.shouldEmitFrame(jpegData: data1, timestamp: start.addingTimeInterval(1.0)))

        // 3. Identical frame within 5s (4.9s later) should be skipped
        XCTAssertFalse(realScreenCaptureService.shouldEmitFrame(jpegData: data1, timestamp: start.addingTimeInterval(4.9)))

        // 4. Identical frame after 5s (5.0s later) should be emitted as heartbeat
        XCTAssertTrue(realScreenCaptureService.shouldEmitFrame(jpegData: data1, timestamp: start.addingTimeInterval(5.0)))

        // 5. Different frame 1s after heartbeat should be emitted immediately
        XCTAssertTrue(realScreenCaptureService.shouldEmitFrame(jpegData: data2, timestamp: start.addingTimeInterval(6.0)))
    }

    func testGetAvailableDisplaysAndOpenSettings() async throws {
        let displays = try await mockScreenCaptureService.getAvailableDisplays()
        XCTAssertEqual(displays.count, 2)
        XCTAssertTrue(displays[0].isMain)
        XCTAssertFalse(displays[1].isMain)
        XCTAssertEqual(displays[0].name, "Mock Main Display")

        mockScreenCaptureService.openScreenCaptureSettings()
        XCTAssertTrue(mockScreenCaptureService.openScreenCaptureSettingsCalled)
    }

    func testConfigurableFPSAndResolution() async throws {
        // Test MockScreenCaptureService stores configured frameRate and maxDimension
        try await mockScreenCaptureService.startCapture(displayID: 1, frameRate: 5, maxDimension: 1280) { _ in }
        XCTAssertTrue(mockScreenCaptureService.isCapturing)
        XCTAssertEqual(mockScreenCaptureService.frameRate, 5)
        XCTAssertEqual(mockScreenCaptureService.maxDimension, 1280)
        mockScreenCaptureService.stopCapture()

        // Test default parameters (frameRate = 1, maxDimension = 1024)
        try await mockScreenCaptureService.startCapture { _ in }
        XCTAssertEqual(mockScreenCaptureService.frameRate, 1)
        XCTAssertEqual(mockScreenCaptureService.maxDimension, 1024)
        mockScreenCaptureService.stopCapture()

        // Test RealScreenCaptureService processCGImage with maxDimension scaling (HD 1280, Full HD 1920, Original 0)
        let size = NSSize(width: 1920, height: 1080)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.green.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            XCTFail("Failed to create test CGImage")
            return
        }

        // HD: maxDimension = 1280 -> 1280x720
        let hdData = realScreenCaptureService.processCGImage(cgImage, maxWidth: 1280.0, compressionQuality: 0.7)
        if let hdImage = NSImage(data: hdData),
           let hdCG = hdImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            XCTAssertEqual(hdCG.width, 1280)
            XCTAssertEqual(hdCG.height, 720)
        } else {
            XCTFail("Failed to decode HD JPEG")
        }

        // Full HD: maxDimension = 1920 -> 1920x1080
        let fhdData = realScreenCaptureService.processCGImage(cgImage, maxWidth: 1920.0, compressionQuality: 0.7)
        if let fhdImage = NSImage(data: fhdData),
           let fhdCG = fhdImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            XCTAssertEqual(fhdCG.width, 1920)
            XCTAssertEqual(fhdCG.height, 1080)
        } else {
            XCTFail("Failed to decode Full HD JPEG")
        }

        // Original: maxDimension = 0 -> 1920x1080
        let origData = realScreenCaptureService.processCGImage(cgImage, maxWidth: 0.0, compressionQuality: 0.7)
        if let origImage = NSImage(data: origData),
           let origCG = origImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            XCTAssertEqual(origCG.width, 1920)
            XCTAssertEqual(origCG.height, 1080)
        } else {
            XCTFail("Failed to decode original JPEG")
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

        setUp()
        testMockScreenCaptureServiceImageResizingAndCompression()
        tearDown()

        setUp()
        testFrameDeduplicationAndHeartbeat()
        tearDown()

        setUp()
        try await testGetAvailableDisplaysAndOpenSettings()
        tearDown()

        setUp()
        try await testConfigurableFPSAndResolution()
        tearDown()
    }
}

