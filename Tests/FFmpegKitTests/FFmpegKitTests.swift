import XCTest
@testable import ffmpegkit

private final class MockBackend: ExecutionBackend {
    var isLinked = true
    var returnCode: Int32 = 0
    var cancelledSessionIds: [Int64] = []
    var output = ""

    func execute(kind: CommandKind, session: AbstractSession) -> Int32 {
        if !output.isEmpty {
            session.addLog(Log(session.getSessionId(), Level.avLogInfo.rawValue, output))
        }
        if let ffmpegSession = session as? FFmpegSession {
            ffmpegSession.addStatistics(
                Statistics(
                    session.getSessionId(),
                    videoFrameNumber: 10,
                    videoFps: 30,
                    videoQuality: 20,
                    size: 1_024,
                    time: 1,
                    bitrate: 8,
                    speed: 2
                )
            )
        }
        return returnCode
    }

    func cancel(sessionId: Int64) {
        cancelledSessionIds.append(sessionId)
    }
}

final class FFmpegKitTests: XCTestCase {
    private var backend: MockBackend!

    override func setUp() {
        super.setUp()
        backend = MockBackend()
        ExecutionRuntime.backend = backend
        FFmpegKitConfig.clearSessions()
    }

    func testCommandParsingPreservesQuotedArguments() {
        let arguments = FFmpegKitConfig.parseArguments("-i \"input file.mp4\" -metadata 'title=My Video' output.mp4")
        XCTAssertEqual(arguments, ["-i", "input file.mp4", "-metadata", "title=My Video", "output.mp4"])
        XCTAssertEqual(FFmpegKitConfig.parseArguments(FFmpegKitConfig.argumentsToString(arguments)), arguments)
    }

    func testSynchronousAPIKeepsLegacySurface() {
        backend.output = "encoded"
        let session = FFmpegKit.execute("-i input.mp4 output.mov")

        XCTAssertEqual(session.getArguments(), ["-i", "input.mp4", "output.mov"])
        XCTAssertEqual(session.getState(), .completed)
        XCTAssertTrue(ReturnCode.isSuccess(session.getReturnCode()))
        XCTAssertEqual(session.getOutput(), "encoded")
        XCTAssertEqual(session.getLastReceivedStatistics()?.getVideoFrameNumber(), 10)
        XCTAssertEqual(FFmpegKit.listSessions().map { $0.getSessionId() }, [session.getSessionId()])
    }

    func testAsynchronousCompletionCallback() {
        let completed = expectation(description: "completion callback")
        let session = FFmpegKit.executeAsync("-version") { result in
            XCTAssertTrue(ReturnCode.isSuccess(result.getReturnCode()))
            completed.fulfill()
        }

        wait(for: [completed], timeout: 2)
        XCTAssertEqual(session.getState(), .completed)
    }

    func testMediaInformationParsing() throws {
        backend.output = """
        {"streams":[{"index":0,"codec_type":"video","codec_name":"h264","width":1920}],"chapters":[],"format":{"filename":"movie.mp4","duration":"1.5"}}
        """
        let session = FFprobeKit.getMediaInformation("movie.mp4")
        let information = try XCTUnwrap(session.getMediaInformation())

        XCTAssertEqual(information.getFilename(), "movie.mp4")
        XCTAssertEqual(information.getDuration(), "1.5")
        XCTAssertEqual(information.getStreams().first?.getCodec(), "h264")
        XCTAssertEqual(information.getStreams().first?.getWidth(), 1920)
    }

    func testCancelUsesSessionIdentifier() {
        let session = FFmpegSession.create(["-version"])
        session.cancel()
        XCTAssertEqual(backend.cancelledSessionIds, [session.getSessionId()])
    }
}
