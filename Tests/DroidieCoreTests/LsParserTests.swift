import XCTest
@testable import DroidieCore

final class LsParserTests: XCTestCase {
    let sample = """
    total 128
    drwxrwx--x  2 u0_a123 media_rw    4096 2026-07-01 12:00 .
    drwxrwx--x 40 root    media_rw    4096 2026-06-01 09:00 ..
    -rw-rw----  1 u0_a123 media_rw 1048576 2026-07-08 21:14 holiday video.mp4
    drwxrwx--x  2 u0_a123 media_rw    4096 2026-07-01 12:00 Documents
    -rw-rw----  1 u0_a123 media_rw     512 2026-07-09 10:00 a.txt
    """

    func test_parse_skipsTotalAndDotEntries() {
        XCTAssertEqual(LsParser.parse(sample).count, 3)
    }

    func test_parse_directoriesFirstThenAlphabetical() {
        let names = LsParser.parse(sample).map(\.name)
        XCTAssertEqual(names, ["Documents", "a.txt", "holiday video.mp4"])
    }

    func test_parse_nameWithSpaces_andSize() {
        let file = LsParser.parse(sample).first { $0.name == "holiday video.mp4" }
        XCTAssertEqual(file?.size, 1_048_576)
        XCTAssertEqual(file?.isDirectory, false)
    }

    func test_parse_emptyOrGarbage_returnsEmpty() {
        XCTAssertEqual(LsParser.parse(""), [])
        XCTAssertEqual(LsParser.parse("ls: /nope: No such file or directory"), [])
    }
}
