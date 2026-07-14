import XCTest
@testable import DroidieCore

final class ProgressParserTests: XCTestCase {
    func test_percent_singleLine() {
        XCTAssertEqual(ProgressParser.percent(in: "[ 42%] /sdcard/Download/video.mp4"), 42)
    }

    func test_percent_lastOfMultipleCarriageReturnUpdates() {
        XCTAssertEqual(ProgressParser.percent(in: "[  5%] a.mp4\r[ 17%] a.mp4\r[100%] a.mp4"), 100)
    }

    func test_percent_noMatch_returnsNil() {
        XCTAssertNil(ProgressParser.percent(in: "video.mp4: 1 file pushed, 0 skipped."))
        XCTAssertNil(ProgressParser.percent(in: ""))
    }
}
