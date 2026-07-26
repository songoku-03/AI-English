import Foundation

#if canImport(XCTest)
import XCTest
#else
open class XCTestCase {
    public init() {}
    open func setUp() {}
    open func tearDown() {}
    open func setUpWithError() throws {}
    open func tearDownWithError() throws {}
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

public func XCTFail(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    print("❌ Failure [\(file):\(line)]: \(message)")
    XTestRunner.recordFailure(file: file, line: line, message: message)
}

public enum XTestRunner {
    public static var failureCount: Int = 0
    public static func recordFailure(file: StaticString, line: UInt, message: String) {
        failureCount += 1
    }
}
#endif
