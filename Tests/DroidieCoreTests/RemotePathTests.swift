import XCTest
@testable import DroidieCore

final class RemotePathTests: XCTestCase {
    func test_quoted_plainPath() {
        XCTAssertEqual(RemotePath.quoted("/sdcard/Download"), "'/sdcard/Download'")
    }

    func test_quoted_pathWithSpacesAndUmlauts() {
        XCTAssertEqual(RemotePath.quoted("/sdcard/Mürren fotos"), "'/sdcard/Mürren fotos'")
    }

    func test_quoted_pathWithSingleQuote() {
        XCTAssertEqual(RemotePath.quoted("/sdcard/it's"), "'/sdcard/it'\\''s'")
    }

    func test_join_handlesTrailingSlash() {
        XCTAssertEqual(RemotePath.join("/sdcard/Download", "a.jpg"), "/sdcard/Download/a.jpg")
        XCTAssertEqual(RemotePath.join("/sdcard/Download/", "a.jpg"), "/sdcard/Download/a.jpg")
    }
}
