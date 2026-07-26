#if canImport(XCTest)
import XCTest
#endif
@testable import AIEnglishTutor

final class HotkeyTests: XCTestCase, TestRunnable {
    var mockHotkeyService: MockGlobalHotkeyService!
    var realHotkeyService: GlobalHotkeyService!

    override func setUp() {
        super.setUp()
        mockHotkeyService = MockGlobalHotkeyService()
        realHotkeyService = GlobalHotkeyService()
    }

    override func tearDown() {
        mockHotkeyService = nil
        realHotkeyService = nil
        super.tearDown()
    }

    func testHotkeyRegistrationAndTriggers() throws {
        var muteToggled = false
        var sessionToggled = false

        try mockHotkeyService.registerHotkeys(
            onMuteToggle: { muteToggled = true },
            onSessionToggle: { sessionToggled = true }
        )

        XCTAssertTrue(mockHotkeyService.isRegistered)

        mockHotkeyService.triggerMuteHotkey()
        XCTAssertTrue(muteToggled)

        mockHotkeyService.triggerSessionHotkey()
        XCTAssertTrue(sessionToggled)
    }

    func testHotkeyUnregistration() throws {
        try mockHotkeyService.registerHotkeys(onMuteToggle: {}, onSessionToggle: {})
        XCTAssertTrue(mockHotkeyService.isRegistered)

        mockHotkeyService.unregisterHotkeys()
        XCTAssertFalse(mockHotkeyService.isRegistered)
    }

    func testRealGlobalHotkeyServiceUnregister() {
        realHotkeyService.unregisterHotkeys()
        XCTAssertFalse(realHotkeyService.isRegistered)
    }

    public func runAllTests() async throws {
        setUp()
        try testHotkeyRegistrationAndTriggers()
        tearDown()

        setUp()
        try testHotkeyUnregistration()
        tearDown()

        setUp()
        testRealGlobalHotkeyServiceUnregister()
        tearDown()
    }
}
