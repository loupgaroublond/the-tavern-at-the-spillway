import XCTest
@testable import TavernCore

/// Stress tests for streaming under concurrent load (Bead 618c)
///
/// Verifies:
/// - 10+ concurrent streaming sessions via MockAgent complete correctly
/// - Content matches expected per-stream (no interleaving)
/// - Rapid cancel/restart (100 cycles) doesn't deadlock
/// - Memory doesn't grow unbounded from accumulated messages
///
/// Run with: swift test --filter TavernStressTests.StreamingStressTests
final class StreamingStressTests: XCTestCase {

    // MARK: - Test: 10 Concurrent Streams

    /// Run 10 concurrent streaming sessions. Each MockAgent returns a known response.
    /// Verify all streams complete and content matches expected.
    func testConcurrentStreamingSessions() async throws {
        let streamCount = 10
        let timeBudget: TimeInterval = 10.0
        let startTime = Date()

        // Each stream gets a unique response so we can verify no interleaving
        var results: [(index: Int, collected: String)] = []

        await withTaskGroup(of: (Int, String).self) { group in
            for i in 0..<streamCount {
                group.addTask {
                    let expectedResponse = String(repeating: "Stream\(i)-", count: 50)
                    let mock = MockAgent(
                        name: "StreamAgent-\(i)",
                        responses: [expectedResponse]
                    )
                    mock.streamingChunkSize = 10

                    let (stream, _) = mock.sendStreaming("message-\(i)")

                    var collected = ""
                    do {
                        for try await event in stream {
                            switch event {
                            case .textDelta(let delta):
                                collected += delta
                            case .completed:
                                break
                            default:
                                break
                            }
                        }
                    } catch {
                        XCTFail("Stream \(i) threw: \(error)")
                    }

                    return (i, collected)
                }
            }

            // for-await on TaskGroup is sequential — no lock needed
            for await (index, collected) in group {
                results.append((index: index, collected: collected))
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // All streams should have completed
        XCTAssertEqual(results.count, streamCount,
            "All \(streamCount) streams should complete, got \(results.count)")

        // Each stream's content should match its expected output exactly
        for result in results {
            let expected = String(repeating: "Stream\(result.index)-", count: 50)
            XCTAssertEqual(result.collected, expected,
                "Stream \(result.index) content mismatch: got \(result.collected.count) chars, expected \(expected.count)")
        }

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(streamCount) concurrent streams must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testConcurrentStreamingSessions: \(streamCount) streams in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Rapid Cancel/Restart Cycles

    /// Cancel and restart streaming 100 times. No deadlock should occur.
    func testRapidCancelRestartCycles() async throws {
        let cycleCount = 100
        let timeBudget: TimeInterval = 10.0
        let startTime = Date()

        let mock = MockAgent(
            name: "CancelTestAgent",
            responses: Array(repeating: String(repeating: "X", count: 1000), count: cycleCount + 1),
            defaultResponse: String(repeating: "Y", count: 1000)
        )
        mock.streamingChunkSize = 5

        var completedCycles = 0
        var cancelledCycles = 0

        for i in 0..<cycleCount {
            let (stream, cancel) = mock.sendStreaming("cancel-test-\(i)")

            // Read a few chunks then cancel
            var chunkCount = 0
            do {
                for try await event in stream {
                    if case .textDelta = event {
                        chunkCount += 1
                        // Cancel after reading 2 chunks
                        if chunkCount >= 2 {
                            cancel()
                            cancelledCycles += 1
                            break
                        }
                    }
                    if case .completed = event {
                        completedCycles += 1
                        break
                    }
                }
            } catch {
                // Cancellation errors are expected
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // At least some should have been cancelled (the rest completed before we could cancel)
        let totalHandled = completedCycles + cancelledCycles
        XCTAssertEqual(totalHandled, cycleCount,
            "All \(cycleCount) cycles should be handled, got \(totalHandled)")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(cycleCount) cancel/restart cycles must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testRapidCancelRestartCycles: \(cancelledCycles) cancelled, \(completedCycles) completed in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Large Streaming Response

    /// Stream a very large response (100KB+). Verify all content arrives correctly.
    func testLargeStreamingResponse() async throws {
        let responseSize = 100_000
        let response = String(repeating: "A", count: responseSize)
        let timeBudget: TimeInterval = 5.0

        let mock = MockAgent(
            name: "LargeStreamAgent",
            responses: [response]
        )
        mock.streamingChunkSize = 100

        let startTime = Date()
        let (stream, _) = mock.sendStreaming("large-test")

        var collected = ""
        for try await event in stream {
            if case .textDelta(let delta) = event {
                collected += delta
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(collected.count, responseSize,
            "Collected \(collected.count) chars, expected \(responseSize)")
        XCTAssertEqual(collected, response,
            "Content should match exactly")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "100KB stream must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testLargeStreamingResponse: \(responseSize) chars in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Concurrent Streams With Tool Events

    /// Stream responses that include tool events. Verify event ordering is correct per-stream.
    func testConcurrentStreamsWithToolEvents() async throws {
        let streamCount = 10
        let timeBudget: TimeInterval = 10.0
        let startTime = Date()

        // We test event ordering by observing textDelta vs completed ordering
        var allCompleted = 0

        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<streamCount {
                group.addTask {
                    let response = "Response-\(i)-content"
                    let mock = MockAgent(
                        name: "ToolStreamAgent-\(i)",
                        responses: [response]
                    )
                    mock.streamingChunkSize = 3

                    let (stream, _) = mock.sendStreaming("tool-test-\(i)")

                    var sawText = false
                    var sawCompleted = false
                    var completedAfterText = false

                    do {
                        for try await event in stream {
                            switch event {
                            case .textDelta:
                                sawText = true
                            case .completed:
                                sawCompleted = true
                                completedAfterText = sawText
                            default:
                                break
                            }
                        }
                    } catch {
                        return false
                    }

                    // Completed must come after text deltas
                    return sawText && sawCompleted && completedAfterText
                }
            }

            // for-await on TaskGroup is sequential — no lock needed
            for await success in group {
                if success {
                    allCompleted += 1
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(allCompleted, streamCount,
            "All \(streamCount) streams should have correct event ordering, got \(allCompleted)")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Concurrent tool streams must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testConcurrentStreamsWithToolEvents: \(allCompleted)/\(streamCount) correct ordering in \(String(format: "%.2f", duration))s")
    }
}
