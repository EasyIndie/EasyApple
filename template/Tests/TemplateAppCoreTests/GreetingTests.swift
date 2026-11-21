import XCTest
@testable import TemplateAppCore

final class GreetingTests: XCTestCase {

    func testGreetingUsesAppName() {
        XCTAssertEqual(Greeting(appName: "TemplateApp").text, "Hello, TemplateApp")
    }

    func testGreetingIsEquatable() {
        XCTAssertEqual(Greeting(appName: "A"), Greeting(appName: "A"))
        XCTAssertNotEqual(Greeting(appName: "A"), Greeting(appName: "B"))
    }
}
