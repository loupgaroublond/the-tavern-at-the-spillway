import Foundation
import Testing
import ClodKit
@testable import TavernCore
@testable import TavernKit

// MARK: - Provenance: REQ-COST-001

@Suite("Per-Model Usage Breakdown", .timeLimit(.minutes(1)))
struct PerModelUsageTests {

    // MARK: - Helpers

    /// Build an SDKMessage simulating a result message with the given raw JSON.
    private static func resultMessage(with json: [String: JSONValue]) -> SDKMessage {
        SDKMessage(type: "result", rawJSON: json)
    }

    /// Build a usage JSON object from individual values.
    private static func usageJSON(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheRead: Int = 0,
        cacheCreation: Int = 0,
        webSearchRequests: Int = 0,
        costUsd: Double = 0
    ) -> JSONValue {
        .object([
            "input_tokens": .int(inputTokens),
            "output_tokens": .int(outputTokens),
            "cache_read_input_tokens": .int(cacheRead),
            "cache_creation_input_tokens": .int(cacheCreation),
            "web_search_requests": .int(webSearchRequests),
            "cost_usd": .double(costUsd)
        ])
    }

    // MARK: - parseCompletionInfo per-model parsing

    @Test("parseCompletionInfo extracts per-model usage from result message")
    func parsePerModelUsage() {
        let msg = Self.resultMessage(with: [
            "session_id": .string("sess-1"),
            "usage": Self.usageJSON(inputTokens: 500, outputTokens: 200, costUsd: 0.05),
            "modelUsage": .object([
                "claude-sonnet-4-20250514": Self.usageJSON(
                    inputTokens: 300, outputTokens: 100,
                    cacheRead: 50, cacheCreation: 10,
                    webSearchRequests: 2, costUsd: 0.02
                ),
                "claude-haiku-3-20250307": Self.usageJSON(
                    inputTokens: 200, outputTokens: 100,
                    costUsd: 0.03
                )
            ]),
            "total_cost_usd": .double(0.05),
            "duration_ms": .int(1500),
            "num_turns": .int(3),
            "stop_reason": .string("end_turn")
        ])

        let info = LiveMessenger.parseCompletionInfo(from: msg)

        // Aggregate usage
        #expect(info.usage?.inputTokens == 500)
        #expect(info.usage?.outputTokens == 200)

        // Per-model usage
        #expect(info.perModelUsage != nil)
        #expect(info.perModelUsage?.count == 2)

        let sonnet = info.perModelUsage?["claude-sonnet-4-20250514"]
        #expect(sonnet?.inputTokens == 300)
        #expect(sonnet?.outputTokens == 100)
        #expect(sonnet?.cacheReadInputTokens == 50)
        #expect(sonnet?.cacheCreationInputTokens == 10)
        #expect(sonnet?.webSearchRequests == 2)
        #expect(sonnet?.costUsd == 0.02)

        let haiku = info.perModelUsage?["claude-haiku-3-20250307"]
        #expect(haiku?.inputTokens == 200)
        #expect(haiku?.outputTokens == 100)
        #expect(haiku?.costUsd == 0.03)
        #expect(haiku?.webSearchRequests == 0) // defaults to 0
    }

    @Test("parseCompletionInfo handles missing modelUsage gracefully")
    func emptyModelUsageHandled() {
        let msg = Self.resultMessage(with: [
            "session_id": .string("sess-2"),
            "usage": Self.usageJSON(inputTokens: 100, outputTokens: 50),
            "total_cost_usd": .double(0.01)
        ])

        let info = LiveMessenger.parseCompletionInfo(from: msg)

        #expect(info.perModelUsage == nil)
        #expect(info.usage?.inputTokens == 100)
    }

    @Test("parseCompletionInfo handles empty modelUsage dictionary")
    func emptyModelUsageDictionary() {
        let msg = Self.resultMessage(with: [
            "session_id": .string("sess-3"),
            "usage": Self.usageJSON(inputTokens: 100, outputTokens: 50),
            "modelUsage": .object([:])
        ])

        let info = LiveMessenger.parseCompletionInfo(from: msg)

        #expect(info.perModelUsage != nil)
        #expect(info.perModelUsage?.isEmpty == true)
    }

    @Test("Single model per-model usage matches aggregate when only one model used")
    func singleModelUsageMatchesAggregate() {
        let sharedUsage = Self.usageJSON(
            inputTokens: 250, outputTokens: 75,
            cacheRead: 30, cacheCreation: 5,
            webSearchRequests: 1, costUsd: 0.015
        )

        let msg = Self.resultMessage(with: [
            "session_id": .string("sess-4"),
            "usage": sharedUsage,
            "modelUsage": .object([
                "claude-sonnet-4-20250514": sharedUsage
            ]),
            "total_cost_usd": .double(0.015)
        ])

        let info = LiveMessenger.parseCompletionInfo(from: msg)

        let aggregate = info.usage
        let perModel = info.perModelUsage?["claude-sonnet-4-20250514"]

        #expect(aggregate != nil)
        #expect(perModel != nil)
        #expect(aggregate == perModel)
    }

    // MARK: - CompletionInfo struct tests

    @Test("CompletionInfo perModelUsage defaults to nil")
    func completionInfoDefaultsNilPerModel() {
        let info = CompletionInfo()
        #expect(info.perModelUsage == nil)
    }

    @Test("CompletionInfo carries perModelUsage when provided")
    func completionInfoCarriesPerModelUsage() {
        let modelA = SessionUsage(inputTokens: 100, outputTokens: 50, costUsd: 0.01)
        let modelB = SessionUsage(inputTokens: 200, outputTokens: 80, webSearchRequests: 3, costUsd: 0.02)

        let info = CompletionInfo(
            sessionId: "sess-5",
            perModelUsage: ["model-a": modelA, "model-b": modelB]
        )

        #expect(info.perModelUsage?.count == 2)
        #expect(info.perModelUsage?["model-a"]?.inputTokens == 100)
        #expect(info.perModelUsage?["model-b"]?.webSearchRequests == 3)
    }

    @Test("CompletionInfo equatable includes perModelUsage")
    func completionInfoEquatableWithPerModel() {
        let usage = SessionUsage(inputTokens: 10, outputTokens: 5)
        let a = CompletionInfo(perModelUsage: ["m": usage])
        let b = CompletionInfo(perModelUsage: ["m": usage])
        let c = CompletionInfo(perModelUsage: nil)

        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - SessionUsage webSearchRequests

    @Test("SessionUsage carries webSearchRequests")
    func sessionUsageWebSearchRequests() {
        let usage = SessionUsage(inputTokens: 10, outputTokens: 5, webSearchRequests: 7, costUsd: 0.01)
        #expect(usage.webSearchRequests == 7)
    }

    @Test("SessionUsage webSearchRequests defaults to zero")
    func sessionUsageWebSearchRequestsDefault() {
        let usage = SessionUsage(inputTokens: 10, outputTokens: 5)
        #expect(usage.webSearchRequests == 0)
    }

    @Test("parseCompletionInfo extracts webSearchRequests from aggregate usage")
    func parseAggregateWebSearchRequests() {
        let msg = Self.resultMessage(with: [
            "usage": Self.usageJSON(
                inputTokens: 100, outputTokens: 50,
                webSearchRequests: 4, costUsd: 0.01
            ),
            "total_cost_usd": .double(0.01)
        ])

        let info = LiveMessenger.parseCompletionInfo(from: msg)
        #expect(info.usage?.webSearchRequests == 4)
    }
}
