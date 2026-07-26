import Foundation

public final class TestBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var internalValue: T

    public init(_ value: T) {
        self.internalValue = value
    }

    public var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return internalValue
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            internalValue = newValue
        }
    }
}

public protocol TestRunnable {
    @MainActor func runAllTests() async throws
}

#if canImport(XCTest)
import XCTest

final class AllTestsRunner: XCTestCase {
    func testAllSuites() async throws {
        await TestRunnerMain.runAllSuites()
    }
}
#else
open class XCTestCase {
    public init() {}
    @MainActor open func setUp() {}
    @MainActor open func tearDown() {}
    @MainActor open func setUpWithError() throws {}
    @MainActor open func tearDownWithError() throws {}
}

public func XCTAssertEqual<T: Equatable>(_ expression1: @autoclosure () throws -> T?, _ expression2: @autoclosure () throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let val1 = try expression1()
        let val2 = try expression2()
        if val1 != val2 {
            let msg = "\(val1 != nil ? String(describing: val1!) : "nil") != \(val2 != nil ? String(describing: val2!) : "nil"). \(message())"
            print("❌ Failure [\(file):\(line)]: \(msg)")
            XTestRunner.recordFailure(file: file, line: line, message: msg)
        }
    } catch {
        print("❌ Failure [\(file):\(line)]: Threw unexpected error: \(error)")
        XTestRunner.recordFailure(file: file, line: line, message: "Threw error: \(error)")
    }
}

public func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let val = try expression()
        if !val {
            print("❌ Failure [\(file):\(line)]: Expression is false. \(message())")
            XTestRunner.recordFailure(file: file, line: line, message: "Expression is false")
        }
    } catch {
        print("❌ Failure [\(file):\(line)]: Threw unexpected error: \(error)")
        XTestRunner.recordFailure(file: file, line: line, message: "Threw error: \(error)")
    }
}

public func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let val = try expression()
        if val {
            print("❌ Failure [\(file):\(line)]: Expression is true. \(message())")
            XTestRunner.recordFailure(file: file, line: line, message: "Expression is true")
        }
    } catch {
        print("❌ Failure [\(file):\(line)]: Threw unexpected error: \(error)")
        XTestRunner.recordFailure(file: file, line: line, message: "Threw error: \(error)")
    }
}

public func XCTAssertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let val = try expression()
        if val != nil {
            print("❌ Failure [\(file):\(line)]: Expected nil, got \(val!). \(message())")
            XTestRunner.recordFailure(file: file, line: line, message: "Expected nil")
        }
    } catch {
        print("❌ Failure [\(file):\(line)]: Threw unexpected error: \(error)")
        XTestRunner.recordFailure(file: file, line: line, message: "Threw error: \(error)")
    }
}

public func XCTAssertNotNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let val = try expression()
        if val == nil {
            print("❌ Failure [\(file):\(line)]: Expected non-nil, got nil. \(message())")
            XTestRunner.recordFailure(file: file, line: line, message: "Expected non-nil")
        }
    } catch {
        print("❌ Failure [\(file):\(line)]: Threw unexpected error: \(error)")
        XTestRunner.recordFailure(file: file, line: line, message: "Threw error: \(error)")
    }
}

public func XCTAssertLessThanOrEqual<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let val1 = try expression1()
        let val2 = try expression2()
        if val1 > val2 {
            print("❌ Failure [\(file):\(line)]: \(val1) > \(val2). \(message())")
            XTestRunner.recordFailure(file: file, line: line, message: "\(val1) > \(val2)")
        }
    } catch {
        print("❌ Failure [\(file):\(line)]: Threw unexpected error: \(error)")
        XTestRunner.recordFailure(file: file, line: line, message: "Threw error: \(error)")
    }
}

public func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", _ errorHandler: (Error) -> Void = { _ in }, file: StaticString = #filePath, line: UInt = #line) {
    do {
        _ = try expression()
        print("❌ Failure [\(file):\(line)]: Expected error to be thrown. \(message())")
        XTestRunner.recordFailure(file: file, line: line, message: "Expected error to be thrown")
    } catch {
        errorHandler(error)
    }
}

public func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        _ = try expression()
    } catch {
        print("❌ Failure [\(file):\(line)]: Expected no throw, got \(error). \(message())")
        XTestRunner.recordFailure(file: file, line: line, message: "Expected no throw")
    }
}

public struct XCTUnwrapError: Error, @unchecked Sendable {
    public init() {}
}

public func XCTUnwrap<T>(_ expression: @autoclosure () throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) throws -> T {
    do {
        if let val = try expression() {
            return val
        } else {
            let msg = "Expected non-nil value. \(message())"
            print("❌ Failure [\(file):\(line)]: \(msg)")
            XTestRunner.recordFailure(file: file, line: line, message: msg)
            throw XCTUnwrapError()
        }
    } catch {
        print("❌ Failure [\(file):\(line)]: Threw unexpected error: \(error)")
        XTestRunner.recordFailure(file: file, line: line, message: "Threw error: \(error)")
        throw error
    }
}

public func XCTFail(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    print("❌ Failure [\(file):\(line)]: \(message)")
    XTestRunner.recordFailure(file: file, line: line, message: message)
}
#endif

public enum XTestRunner {
    public static var failureCount: Int = 0
    public static func recordFailure(file: StaticString, line: UInt, message: String) {
        failureCount += 1
    }
}

public struct TestRunnerMain {
    @MainActor
    public static func runAllSuites() async {
        print("Testing started")
        let startTime = Date()

        let suites: [(String, TestRunnable)] = [
            ("KeychainTests", KeychainTests()),
            ("HotkeyTests", HotkeyTests()),
            ("ScreenCaptureTests", ScreenCaptureTests()),
            ("AudioEngineTests", AudioEngineTests()),
            ("GeminiLiveClientTests", GeminiLiveClientTests()),
            ("ViewModelTests", ViewModelTests()),
            ("ModelTests", ModelTests()),
            ("IntegrationTests", IntegrationTests()),
            ("Tier1FeatureCoverageTests", Tier1FeatureCoverageTests()),
            ("Tier2BoundaryCornerCaseTests", Tier2BoundaryCornerCaseTests()),
            ("Tier3CrossFeatureInteractionTests", Tier3CrossFeatureInteractionTests()),
            ("Tier4RealWorldScenarioTests", Tier4RealWorldScenarioTests())
        ]

        for (name, suite) in suites {
            do {
                try await suite.runAllTests()
            } catch {
                print("❌ Suite \(name) failed with error: \(error)")
                XTestRunner.failureCount += 1
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        if XTestRunner.failureCount == 0 {
            print(String(format: "Test Suite 'All tests' passed. Executed %d test suites, with 0 failures in %.3f seconds.", suites.count, duration))
        } else {
            print(String(format: "Test Suite 'All tests' failed with %d failures in %.3f seconds.", XTestRunner.failureCount, duration))
            exit(1)
        }
    }
}
