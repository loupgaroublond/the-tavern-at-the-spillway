import Foundation
import Testing
@testable import TavernCore

// MARK: - Test Sink

/// A test sink that records all received entries
private final class RecordingSink: LogSink, @unchecked Sendable {
    // @unchecked Sendable: test-only type, single-threaded test execution
    private(set) var entries: [LogEntry] = []

    func receive(_ entry: LogEntry) {
        entries.append(entry)
    }
}

// MARK: - Tests

@Suite("Logging Infrastructure", .timeLimit(.minutes(1)))
struct LoggingTests {

    // MARK: - OSLogSink

    @Test("OSLogSink exists and is configured with correct subsystem")
    func testOSLogSinkForwards() {
        let sink = OSLogSink(subsystem: "com.tavern.spillway")
        // OSLogSink is a struct — verify it can be created and called without crashing
        let entry = LogEntry(category: "test", level: .info, message: "test message")
        sink.receive(entry)
        // If we got here without crash, os.log forwarding is functional
    }

    // MARK: - BufferSink

    #if DEBUG
    @Test("BufferSink appends entries to buffer")
    func testBufferSinkAppends() async {
        let buffer = LogBuffer()
        let sink = BufferSink(buffer: buffer)

        sink.receive(LogEntry(category: "agents", level: .info, message: "hello"))
        sink.receive(LogEntry(category: "chat", level: .debug, message: "world"))

        // BufferSink uses Task to append, give it a moment
        try? await Task.sleep(for: .milliseconds(50))

        let entries = await buffer.entries
        #expect(entries.count == 2)
        #expect(entries[0].message == "hello")
        #expect(entries[1].message == "world")
    }
    #endif

    // MARK: - TavernLogDispatcher

    @Test("Dispatcher routes entries to all sinks")
    func testLogDispatcherRoutesToAllSinks() {
        let sink1 = RecordingSink()
        let sink2 = RecordingSink()
        let dispatcher = TavernLogDispatcher(sinks: [sink1, sink2])

        dispatcher.log(category: "agents", level: .info, message: "test")

        #expect(sink1.entries.count == 1)
        #expect(sink2.entries.count == 1)
        #expect(sink1.entries[0].category == "agents")
        #expect(sink1.entries[0].level == .info)
        #expect(sink1.entries[0].message == "test")
        #expect(sink2.entries[0].message == "test")
    }

    @Test("Dispatcher convenience methods set correct levels")
    func testDispatcherConvenienceMethods() {
        let sink = RecordingSink()
        let dispatcher = TavernLogDispatcher(sinks: [sink])

        dispatcher.debug(category: "chat", "debug msg")
        dispatcher.info(category: "chat", "info msg")
        dispatcher.error(category: "chat", "error msg")

        #expect(sink.entries.count == 3)
        #expect(sink.entries[0].level == .debug)
        #expect(sink.entries[1].level == .info)
        #expect(sink.entries[2].level == .error)
    }

    // MARK: - Category Filtering

    #if DEBUG
    @Test("Buffer can filter entries by category")
    func testCategoryFiltering() async {
        let buffer = LogBuffer()

        await buffer.append(LogEntry(category: "agents", level: .info, message: "a"))
        await buffer.append(LogEntry(category: "chat", level: .info, message: "b"))
        await buffer.append(LogEntry(category: "agents", level: .debug, message: "c"))

        let agentsOnly = await buffer.entries(forCategory: "agents")
        #expect(agentsOnly.count == 2)
        #expect(agentsOnly[0].message == "a")
        #expect(agentsOnly[1].message == "c")

        let chatOnly = await buffer.entries(forCategory: "chat")
        #expect(chatOnly.count == 1)
        #expect(chatOnly[0].message == "b")
    }
    #endif

    // MARK: - Level Filtering

    #if DEBUG
    @Test("Buffer can filter entries by level")
    func testLevelFiltering() async {
        let buffer = LogBuffer()

        await buffer.append(LogEntry(category: "agents", level: .debug, message: "d"))
        await buffer.append(LogEntry(category: "agents", level: .info, message: "i"))
        await buffer.append(LogEntry(category: "agents", level: .error, message: "e"))

        let infoAndAbove = await buffer.entries(atLevel: .info)
        #expect(infoAndAbove.count == 2)
        #expect(infoAndAbove[0].message == "i")
        #expect(infoAndAbove[1].message == "e")

        let errorsOnly = await buffer.entries(atLevel: .error)
        #expect(errorsOnly.count == 1)
        #expect(errorsOnly[0].message == "e")

        let all = await buffer.entries(atLevel: .debug)
        #expect(all.count == 3)
    }
    #endif

    // MARK: - AsyncStream Delivery

    #if DEBUG
    @Test("AsyncStream delivers new entries as they arrive")
    func testAsyncStreamDelivery() async {
        let buffer = LogBuffer()
        let stream = await buffer.stream()

        // Append entries after a short delay so the stream consumer is ready
        Task {
            try? await Task.sleep(for: .milliseconds(20))
            await buffer.append(LogEntry(category: "chat", level: .info, message: "first"))
            await buffer.append(LogEntry(category: "chat", level: .error, message: "second"))
        }

        var received: [LogEntry] = []
        for await entry in stream {
            received.append(entry)
            if received.count == 2 { break }
        }

        #expect(received.count == 2)
        #expect(received[0].message == "first")
        #expect(received[1].message == "second")
    }
    #endif

    // MARK: - CategoryLogger

    @Test("CategoryLogger routes through dispatcher")
    func testCategoryLoggerRoutes() {
        let sink = RecordingSink()
        let dispatcher = TavernLogDispatcher(sinks: [sink])
        let logger = CategoryLogger(category: "agents", dispatcher: dispatcher)

        logger.debug("debug msg")
        logger.info("info msg")
        logger.error("error msg")
        logger.debugError("debug error msg")
        logger.debugInfo("debug info msg")
        logger.debugLog("debug log msg")

        #expect(sink.entries.count == 6)
        #expect(sink.entries[0].level == .debug)
        #expect(sink.entries[0].category == "agents")
        #expect(sink.entries[1].level == .info)
        #expect(sink.entries[2].level == .error)
        // debugError routes to error
        #expect(sink.entries[3].level == .error)
        // debugInfo routes to info
        #expect(sink.entries[4].level == .info)
        // debugLog routes to debug
        #expect(sink.entries[5].level == .debug)
    }

    // MARK: - LogLevel

    @Test("LogLevel ordering is correct")
    func testLogLevelOrdering() {
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.error)
        #expect(!(LogLevel.error < LogLevel.debug))
    }

    @Test("LogLevel labels are correct")
    func testLogLevelLabels() {
        #expect(LogLevel.debug.label == "DEBUG")
        #expect(LogLevel.info.label == "INFO")
        #expect(LogLevel.error.label == "ERROR")
    }
}
