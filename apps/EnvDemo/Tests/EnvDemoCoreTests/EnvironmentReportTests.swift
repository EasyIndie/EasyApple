import XCTest
@testable import EnvDemoCore

final class EnvironmentReportTests: XCTestCase {

    func testFormatBytes() {
        XCTAssertEqual(formatBytes(0), "0.00 B")
        XCTAssertEqual(formatBytes(1024), "1.00 KB")
        XCTAssertEqual(formatBytes(17_179_869_184), "16.00 GB")
        XCTAssertEqual(formatBytes(549_755_813_888), "512.00 GB")
    }

    func testFormatAsTextContainsKeyFields() {
        let report = EnvironmentReport(
            model: "Mac14,2",
            osName: "macOS",
            osVersion: "27.0",
            isSimulator: false,
            architecture: "arm64",
            screenWidthPoints: 1512,
            screenHeightPoints: 982,
            physicalMemoryBytes: 17_179_869_184,
            storageTotalBytes: 549_755_813_888,
            gpuName: "Apple M1"
        )
        let text = report.formatAsText()
        XCTAssertTrue(text.contains("型号: Mac14,2"))
        XCTAssertTrue(text.contains("系统: macOS 27.0"))
        XCTAssertTrue(text.contains("模拟器: 否"))
        XCTAssertTrue(text.contains("架构: arm64"))
        XCTAssertTrue(text.contains("屏幕: 1512 x 982 pt"))
        XCTAssertTrue(text.contains("内存: 16.00 GB"))
        XCTAssertTrue(text.contains("存储: 512.00 GB"))
        XCTAssertTrue(text.contains("GPU: Apple M1"))
    }

    func testFormatAsTextOmitsScreenWhenZero() {
        let report = EnvironmentReport(
            model: "X",
            osName: "macOS",
            osVersion: "1",
            isSimulator: false,
            architecture: "arm64",
            screenWidthPoints: 0,
            screenHeightPoints: 0,
            physicalMemoryBytes: 0,
            storageTotalBytes: 0,
            gpuName: ""
        )
        let text = report.formatAsText()
        XCTAssertFalse(text.contains("屏幕:"))
    }
}
