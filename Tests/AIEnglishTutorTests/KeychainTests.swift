#if canImport(XCTest)
import XCTest
#endif
@testable import AIEnglishTutor

final class KeychainTests: XCTestCase, TestRunnable {
    var mockKeychainService: MockKeychainService!
    var realKeychainService: KeychainService!

    override func setUp() {
        super.setUp()
        mockKeychainService = MockKeychainService()
        realKeychainService = KeychainService(serviceName: "com.aienglishtutor.unittest.\(UUID().uuidString)")
    }

    override func tearDown() {
        if let service = realKeychainService {
            try? service.delete(key: "test_key")
        }
        mockKeychainService = nil
        realKeychainService = nil
        super.tearDown()
    }

    func testMockSaveAndRetrieveApiKey() throws {
        let keyName = "gemini_api_key"
        let secretValue = "AIzaSyDummyTestKey_123456789"

        try mockKeychainService.save(key: keyName, value: secretValue)
        let retrieved = try mockKeychainService.retrieve(key: keyName)

        XCTAssertEqual(retrieved, secretValue)
    }

    func testMockDeleteApiKey() throws {
        let keyName = "gemini_api_key"
        try mockKeychainService.save(key: keyName, value: "test")

        try mockKeychainService.delete(key: keyName)
        let retrieved = try mockKeychainService.retrieve(key: keyName)

        XCTAssertNil(retrieved)
    }

    func testSaveEmptyKeyThrowsError() {
        XCTAssertThrowsError(try mockKeychainService.save(key: "", value: "val")) { error in
            XCTAssertEqual(error as? KeychainError, KeychainError.emptyKey)
        }
    }

    func testRealKeychainServiceSaveRetrieveDelete() throws {
        let testKey = "test_key"
        let testValue = "test_value_secret_123"

        // Save
        try realKeychainService.save(key: testKey, value: testValue)

        // Retrieve
        let fetched = try realKeychainService.retrieve(key: testKey)
        XCTAssertEqual(fetched, testValue)

        // Update
        let updatedValue = "updated_value_456"
        try realKeychainService.save(key: testKey, value: updatedValue)
        let fetchedUpdated = try realKeychainService.retrieve(key: testKey)
        XCTAssertEqual(fetchedUpdated, updatedValue)

        // Delete
        try realKeychainService.delete(key: testKey)
        let fetchedAfterDelete = try realKeychainService.retrieve(key: testKey)
        XCTAssertNil(fetchedAfterDelete)
    }

    public func runAllTests() async throws {
        setUp()
        try testMockSaveAndRetrieveApiKey()
        tearDown()

        setUp()
        try testMockDeleteApiKey()
        tearDown()

        setUp()
        testSaveEmptyKeyThrowsError()
        tearDown()

        setUp()
        try testRealKeychainServiceSaveRetrieveDelete()
        tearDown()
    }
}
