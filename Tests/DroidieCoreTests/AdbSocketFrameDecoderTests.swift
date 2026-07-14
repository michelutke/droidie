import XCTest
@testable import DroidieCore

final class AdbSocketFrameDecoderTests: XCTestCase {
    func test_feed_singleCompleteFrame() {
        var d = AdbSocketFrameDecoder()
        XCTAssertEqual(d.feed(Data("0005hello".utf8)), ["hello"])
    }

    func test_feed_partialThenRest() {
        var d = AdbSocketFrameDecoder()
        XCTAssertEqual(d.feed(Data("0005he".utf8)), [])
        XCTAssertEqual(d.feed(Data("llo".utf8)), ["hello"])
    }

    func test_feed_twoFramesInOneChunk() {
        var d = AdbSocketFrameDecoder()
        XCTAssertEqual(d.feed(Data("0002hi0003abc".utf8)), ["hi", "abc"])
    }

    func test_feed_emptyFrame() {
        var d = AdbSocketFrameDecoder()
        XCTAssertEqual(d.feed(Data("0000".utf8)), [""])
    }

    func test_encodeRequest_prefixesHexLength() {
        XCTAssertEqual(AdbSocketFrameDecoder.encodeRequest("host:track-devices-l"),
                       Data("0014host:track-devices-l".utf8))
    }
}
