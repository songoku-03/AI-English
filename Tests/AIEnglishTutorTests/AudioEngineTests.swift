import Foundation
#if canImport(XCTest)
import XCTest
#endif
@testable import AIEnglishTutor

final class AudioEngineTests: XCTestCase, TestRunnable {
    var mockAudioEngineService: MockAudioEngineService!
    var realAudioEngineService: AudioEngineService!

    override func setUp() {
        super.setUp()
        mockAudioEngineService = MockAudioEngineService()
        realAudioEngineService = AudioEngineService()
    }

    override func tearDown() {
        mockAudioEngineService = nil
        realAudioEngineService = nil
        super.tearDown()
    }

    func testAudioInputStreamingAndPlaybackQueue() throws {
        let pcmDataReceived = TestBox<Data?>(nil)
        try mockAudioEngineService.startInputStreaming { data in
            pcmDataReceived.value = data
        }

        let testPCM = Data([0x01, 0x02, 0x03])
        mockAudioEngineService.simulateMicrophoneInput(pcmData: testPCM)
        XCTAssertEqual(pcmDataReceived.value, testPCM)

        let playbackChunk = Data([0xAA, 0xBB])
        mockAudioEngineService.playAudioChunk(data: playbackChunk)
        XCTAssertTrue(mockAudioEngineService.isPlaying)
        XCTAssertEqual(mockAudioEngineService.playbackQueueCount, 1)

        mockAudioEngineService.stopAudio()
        XCTAssertFalse(mockAudioEngineService.isPlaying)
        XCTAssertEqual(mockAudioEngineService.playbackQueueCount, 0)
    }

    func testAudioInterruptionFlushesQueue() {
        mockAudioEngineService.playAudioChunk(data: Data([0x01]))
        mockAudioEngineService.playAudioChunk(data: Data([0x02]))
        XCTAssertEqual(mockAudioEngineService.playbackQueueCount, 2)

        mockAudioEngineService.interruptPlayback()
        XCTAssertEqual(mockAudioEngineService.playbackQueueCount, 0)
        XCTAssertFalse(mockAudioEngineService.isPlaying)
    }

    func testRealAudioEngineServiceQueueManagementAndBargeIn() {
        XCTAssertEqual(realAudioEngineService.playbackQueueCount, 0)
        XCTAssertFalse(realAudioEngineService.isPlaying)

        // Queue audio chunks
        let chunk1 = Data([0x00, 0x01, 0x02, 0x03])
        let chunk2 = Data([0x04, 0x05, 0x06, 0x07])
        realAudioEngineService.playAudioChunk(data: chunk1)
        realAudioEngineService.playAudioChunk(data: chunk2)

        XCTAssertEqual(realAudioEngineService.playbackQueueCount, 2)

        // Interrupt / VAD barge-in flushes queue
        realAudioEngineService.interruptPlayback()
        XCTAssertEqual(realAudioEngineService.playbackQueueCount, 0)
        XCTAssertFalse(realAudioEngineService.isPlaying)

        // Stop audio clears everything
        realAudioEngineService.stopAudio()
        XCTAssertEqual(realAudioEngineService.playbackQueueCount, 0)
    }

    public func runAllTests() async throws {
        setUp()
        try testAudioInputStreamingAndPlaybackQueue()
        tearDown()

        setUp()
        testAudioInterruptionFlushesQueue()
        tearDown()

        setUp()
        testRealAudioEngineServiceQueueManagementAndBargeIn()
        tearDown()
    }
}
