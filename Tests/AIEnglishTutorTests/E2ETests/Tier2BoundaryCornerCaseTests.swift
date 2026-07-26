import Foundation
#if canImport(XCTest)
import XCTest
#endif
import AppKit
@testable import AIEnglishTutor

@MainActor
final class Tier2BoundaryCornerCaseTests: XCTestCase, TestRunnable {
    var keychain: MockKeychainService!
    var hotkeys: MockGlobalHotkeyService!
    var screenCap: MockScreenCaptureService!
    var audioEngine: MockAudioEngineService!
    var geminiClient: MockGeminiLiveClient!
    var viewModel: AppViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        keychain = MockKeychainService()
        hotkeys = MockGlobalHotkeyService()
        screenCap = MockScreenCaptureService()
        audioEngine = MockAudioEngineService()
        geminiClient = MockGeminiLiveClient()

        viewModel = AppViewModel(
            keychainService: keychain,
            hotkeyService: hotkeys,
            screenCaptureService: screenCap,
            audioEngineService: audioEngine,
            geminiLiveClient: geminiClient
        )
    }

    @MainActor
    override func tearDown() {
        viewModel = nil
        geminiClient = nil
        audioEngine = nil
        screenCap = nil
        hotkeys = nil
        keychain = nil
        super.tearDown()
    }

    // 1. Empty API Key Validation
    func testEmptyApiKeyValidation() async {
        viewModel.config.apiKey = ""
        await viewModel.startSession()

        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.statusMessage, "Error: API Key is required")

        XCTAssertThrowsError(try viewModel.saveApiKey("   ")) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.emptyKey)
        }
    }

    // 2. Invalid API Key Format Validation (Key length < 8)
    func testInvalidApiKeyFormatValidation() async {
        let shortKey = "short"
        keychain.errorToThrow = KeychainError.unhandledError(message: "Invalid format")
        XCTAssertThrowsError(try keychain.save(key: "gemini_api_key", value: shortKey))

        // Test client rejection
        do {
            try await geminiClient.connect(apiKey: shortKey)
            XCTFail("Should have thrown invalidApiKeyFormat")
        } catch {
            XCTAssertEqual(error as? GeminiLiveError, GeminiLiveError.invalidApiKeyFormat)
        }
    }

    private func createTestImageData(width: Int, height: Int) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return Data()
        }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        guard let cgImage = context.makeImage() else {
            return Data()
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 1.0]) ?? Data()
    }


    // 3. Screen Capture Frame Resize Boundary (1024px vs >1024px vs <1024px)
    func testScreenCaptureFrameResizeBoundaries() {
        // Boundary 1: Exactly 1024px (No scaling down beyond 1024)
        let exact1024Frame = createTestImageData(width: 1024, height: 768)
        _ = screenCap.resizeAndCompress(frameData: exact1024Frame, maxWidth: 1024.0, compressionQuality: 0.7)
        XCTAssertEqual(screenCap.lastProcessedWidth, 1024.0)

        // Boundary 2: >1024px (3840x2160 4K frame downscaled to 1024)
        let largeFrame = createTestImageData(width: 3840, height: 2160)
        _ = screenCap.resizeAndCompress(frameData: largeFrame, maxWidth: 1024.0, compressionQuality: 0.7)
        XCTAssertEqual(screenCap.lastProcessedWidth, 1024.0)

        // Boundary 3: <1024px (800x600 retained without upscale)
        let smallFrame = createTestImageData(width: 800, height: 600)
        _ = screenCap.resizeAndCompress(frameData: smallFrame, maxWidth: 1024.0, compressionQuality: 0.7)
        XCTAssertEqual(screenCap.lastProcessedWidth, 800.0)
    }

    // 4. Audio Buffer Edge Cases (Overflow / Underflow)
    func testAudioBufferOverflowAndUnderflow() {
        // Underflow test: play request on empty queue
        audioEngine.stopAudio()
        XCTAssertEqual(audioEngine.playbackQueueCount, 0)
        XCTAssertFalse(audioEngine.isPlaying)

        // Overflow test: exceed maximum capacity
        audioEngine.maxBufferCapacity = 3
        audioEngine.playAudioChunk(data: Data([0x01]))
        audioEngine.playAudioChunk(data: Data([0x02]))
        audioEngine.playAudioChunk(data: Data([0x03]))
        audioEngine.playAudioChunk(data: Data([0x04])) // overflow chunk dropped

        XCTAssertEqual(audioEngine.playbackQueueCount, 3)
    }

    // 5. WebSocket Connection Drop & Automatic Reconnect Retry (3x limit)
    func testWebSocketReconnectRetryThreshold() throws {
        geminiClient.isConnected = true
        geminiClient.maxRetriesBeforeFail = 3

        // Drop #1 -> Retry #1 (Succeeds)
        try geminiClient.simulateConnectionDrop()
        XCTAssertTrue(geminiClient.isConnected)
        XCTAssertEqual(geminiClient.reconnectAttempts, 1)

        // Drop #2 -> Retry #2 (Succeeds)
        try geminiClient.simulateConnectionDrop()
        XCTAssertTrue(geminiClient.isConnected)
        XCTAssertEqual(geminiClient.reconnectAttempts, 2)

        // Drop #3 -> Retry #3 (Succeeds)
        try geminiClient.simulateConnectionDrop()
        XCTAssertTrue(geminiClient.isConnected)
        XCTAssertEqual(geminiClient.reconnectAttempts, 3)

        // Drop #4 -> Retries Exceeded (Fails)
        XCTAssertThrowsError(try geminiClient.simulateConnectionDrop()) { error in
            XCTAssertEqual(error as? GeminiLiveError, GeminiLiveError.maxReconnectAttemptsExceeded)
        }
        XCTAssertFalse(geminiClient.isConnected)
    }

    @MainActor
    public func runAllTests() async throws {
        setUp()
        await testEmptyApiKeyValidation()
        tearDown()

        setUp()
        await testInvalidApiKeyFormatValidation()
        tearDown()

        setUp()
        testScreenCaptureFrameResizeBoundaries()
        tearDown()

        setUp()
        testAudioBufferOverflowAndUnderflow()
        tearDown()

        setUp()
        try testWebSocketReconnectRetryThreshold()
        tearDown()
    }
}
