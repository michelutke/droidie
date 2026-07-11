import XCTest
@testable import DroidieCore

final class AdbPathResolverTests: XCTestCase {
    func test_resolve_overrideWins() {
        let r = AdbPathResolver(override: "/custom/adb", environment: [:], fileExists: { _ in true })
        XCTAssertEqual(r.resolve(), "/custom/adb")
    }

    func test_resolve_missingOverride_fallsThrough() {
        let r = AdbPathResolver(override: "/custom/adb", environment: [:],
                                fileExists: { $0 == "/opt/homebrew/bin/adb" })
        XCTAssertEqual(r.resolve(), "/opt/homebrew/bin/adb")
    }

    func test_resolve_pathSearch() {
        let r = AdbPathResolver(override: nil,
                                environment: ["PATH": "/a/bin:/b/bin"],
                                fileExists: { $0 == "/b/bin/adb" })
        XCTAssertEqual(r.resolve(), "/b/bin/adb")
    }

    func test_resolve_nothingFound_returnsNil() {
        let r = AdbPathResolver(override: nil, environment: ["PATH": "/a"], fileExists: { _ in false })
        XCTAssertNil(r.resolve())
    }
}
