import Foundation
import Testing
@testable import TavernCore

@Suite("Core Slash Command Tests")
struct CoreCommandTests {

    // MARK: - /help

    @Test("/help lists all registered commands")
    @MainActor
    func helpListsCommands() async {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.registerAll([
            TestSlashCommand(name: "alpha", description: "First command"),
            TestSlashCommand(name: "beta", description: "Second command")
        ])
        let help = HelpCommand(dispatcher: dispatcher)
        dispatcher.register(help)

        let result = await help.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("/alpha"))
            #expect(text.contains("/beta"))
            #expect(text.contains("/help"))
            #expect(text.contains("First command"))
        } else {
            Issue.record("Expected message result")
        }
    }

    // MARK: - /cost

    @Test("/cost shows zero usage for fresh context")
    @MainActor
    func costShowsZeroUsage() async {
        let ctx = CommandContext()
        let cmd = CostCommand(context: ctx)

        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("Token Usage"))
            #expect(text.contains("Input tokens:"))
            #expect(text.contains("0"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("/cost reflects recorded usage")
    @MainActor
    func costReflectsUsage() async {
        let ctx = CommandContext()
        ctx.recordUsage(inputTokens: 1500, outputTokens: 500, costUSD: 0.0035)

        let cmd = CostCommand(context: ctx)
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("1.5K"))
            #expect(text.contains("500"))
            #expect(text.contains("$0.0035"))
        } else {
            Issue.record("Expected message result")
        }
    }

    // MARK: - /model

    @Test("/model shows current model when no args")
    @MainActor
    func modelShowsCurrent() async {
        let ctx = CommandContext()
        let cmd = ModelCommand(context: ctx)

        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("Current model:"))
            #expect(text.contains("SDK default"))
            #expect(text.contains("Available models:"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("/model changes model with argument")
    @MainActor
    func modelChangesModel() async {
        let ctx = CommandContext()
        let cmd = ModelCommand(context: ctx)

        let result = await cmd.execute(arguments: "claude-opus-4-6")
        if case .message(let text) = result {
            #expect(text.contains("Model changed to: claude-opus-4-6"))
        } else {
            Issue.record("Expected message result")
        }

        #expect(ctx.currentModel == "claude-opus-4-6")
    }

    @Test("/model shows active marker for current model")
    @MainActor
    func modelShowsActiveMarker() async {
        let ctx = CommandContext()
        ctx.currentModel = "claude-opus-4-6"
        let cmd = ModelCommand(context: ctx)

        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("claude-opus-4-6 (active)"))
        } else {
            Issue.record("Expected message result")
        }
    }

    // MARK: - /status

    @Test("/status shows version and model info")
    @MainActor
    func statusShowsInfo() async {
        let ctx = CommandContext()
        let cmd = StatusCommand(context: ctx)

        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("The Tavern at the Spillway"))
            #expect(text.contains("Version:"))
            #expect(text.contains("Model:"))
            #expect(text.contains("Session:"))
        } else {
            Issue.record("Expected message result")
        }
    }

    // MARK: - /context

    @Test("/context shows usage without window size")
    @MainActor
    func contextWithoutWindow() async {
        let ctx = CommandContext()
        ctx.recordUsage(inputTokens: 100, outputTokens: 50)

        let cmd = ContextCommand(context: ctx)
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("Context Window Usage"))
            #expect(text.contains("150"))
            #expect(text.contains("not yet reported"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("/context shows bar when window size known")
    @MainActor
    func contextWithWindow() async {
        let ctx = CommandContext()
        ctx.recordUsage(inputTokens: 50_000, outputTokens: 10_000, contextWindow: 200_000)

        let cmd = ContextCommand(context: ctx)
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("["))
            #expect(text.contains("30.0%"))
            #expect(text.contains("Remaining:"))
        } else {
            Issue.record("Expected message result")
        }
    }

    // MARK: - /stats

    @Test("/stats shows session statistics")
    @MainActor
    func statsShowsStatistics() async {
        let ctx = CommandContext()
        ctx.recordUsage(inputTokens: 2000, outputTokens: 1000, costUSD: 0.005)
        ctx.recordUsage(inputTokens: 1500, outputTokens: 800, costUSD: 0.003)

        let cmd = StatsCommand(context: ctx)
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("Session Statistics"))
            #expect(text.contains("Messages:        2"))
            #expect(text.contains("Token Distribution:"))
            #expect(text.contains("$0.0080"))
        } else {
            Issue.record("Expected message result")
        }
    }

    // MARK: - /compact

    @Test("/compact reports compaction request")
    @MainActor
    func compactReportsRequest() async {
        let ctx = CommandContext()
        let cmd = CompactCommand(context: ctx)

        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("Context compaction requested"))
            #expect(text.contains("next message"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("/compact shows usage when window known")
    @MainActor
    func compactShowsUsage() async {
        let ctx = CommandContext()
        ctx.recordUsage(inputTokens: 80_000, outputTokens: 20_000, contextWindow: 200_000)

        let cmd = CompactCommand(context: ctx)
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("50.0%"))
        } else {
            Issue.record("Expected message result")
        }
    }

    // MARK: - /thinking

    @Test("/thinking shows current setting")
    @MainActor
    func thinkingShowsCurrent() async {
        let ctx = CommandContext()
        let cmd = ThinkingCommand(context: ctx)

        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("SDK default"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("/thinking sets token count")
    @MainActor
    func thinkingSetsTokens() async {
        let ctx = CommandContext()
        let cmd = ThinkingCommand(context: ctx)

        let result = await cmd.execute(arguments: "10000")
        if case .message(let text) = result {
            #expect(text.contains("10.0K"))
        } else {
            Issue.record("Expected message result")
        }
        #expect(ctx.maxThinkingTokens == 10000)
    }

    @Test("/thinking off disables thinking")
    @MainActor
    func thinkingOff() async {
        let ctx = CommandContext()
        let cmd = ThinkingCommand(context: ctx)

        let result = await cmd.execute(arguments: "off")
        if case .message(let text) = result {
            #expect(text.contains("disabled"))
        } else {
            Issue.record("Expected message result")
        }
        #expect(ctx.maxThinkingTokens == 0)
    }

    @Test("/thinking default resets")
    @MainActor
    func thinkingDefault() async {
        let ctx = CommandContext()
        ctx.maxThinkingTokens = 5000

        let cmd = ThinkingCommand(context: ctx)
        let result = await cmd.execute(arguments: "default")
        if case .message(let text) = result {
            #expect(text.contains("reset"))
        } else {
            Issue.record("Expected message result")
        }
        #expect(ctx.maxThinkingTokens == nil)
    }

    @Test("/thinking rejects invalid input")
    @MainActor
    func thinkingRejectsInvalid() async {
        let ctx = CommandContext()
        let cmd = ThinkingCommand(context: ctx)

        let result = await cmd.execute(arguments: "abc")
        if case .error(let text) = result {
            #expect(text.contains("Invalid value"))
        } else {
            Issue.record("Expected error result")
        }
    }
}
