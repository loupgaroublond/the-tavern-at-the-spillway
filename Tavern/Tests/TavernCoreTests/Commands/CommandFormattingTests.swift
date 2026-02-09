import Foundation
import Testing
@testable import TavernCore

@Suite("CommandFormatting Tests")
struct CommandFormattingTests {

    // MARK: - formatTokens

    @Test("formatTokens returns raw number below 1000")
    func formatTokensBelowThreshold() {
        #expect(CommandFormatting.formatTokens(0) == "0")
        #expect(CommandFormatting.formatTokens(1) == "1")
        #expect(CommandFormatting.formatTokens(999) == "999")
    }

    @Test("formatTokens formats thousands with K suffix")
    func formatTokensThousands() {
        #expect(CommandFormatting.formatTokens(1000) == "1.0K")
        #expect(CommandFormatting.formatTokens(1500) == "1.5K")
        #expect(CommandFormatting.formatTokens(999_999) == "1000.0K")
    }

    @Test("formatTokens formats millions with M suffix")
    func formatTokensMillions() {
        #expect(CommandFormatting.formatTokens(1_000_000) == "1.0M")
        #expect(CommandFormatting.formatTokens(2_500_000) == "2.5M")
        #expect(CommandFormatting.formatTokens(10_000_000) == "10.0M")
    }

    @Test("formatTokens boundary at 1000")
    func formatTokensBoundaryThousand() {
        #expect(CommandFormatting.formatTokens(999) == "999")
        #expect(CommandFormatting.formatTokens(1000) == "1.0K")
    }

    @Test("formatTokens boundary at 1000000")
    func formatTokensBoundaryMillion() {
        #expect(CommandFormatting.formatTokens(999_999) == "1000.0K")
        #expect(CommandFormatting.formatTokens(1_000_000) == "1.0M")
    }

    // MARK: - makeBar

    @Test("makeBar at 0% is all empty")
    func makeBarZero() {
        let bar = CommandFormatting.makeBar(filled: 0, width: 10)
        #expect(bar == "[          ]")
    }

    @Test("makeBar at 100% is all filled")
    func makeBarFull() {
        let bar = CommandFormatting.makeBar(filled: 100, width: 10)
        #expect(bar == "[==========]")
    }

    @Test("makeBar at 50% is half filled")
    func makeBarHalf() {
        let bar = CommandFormatting.makeBar(filled: 50, width: 10)
        #expect(bar == "[=====     ]")
    }

    @Test("makeBar clamps negative to 0%")
    func makeBarNegative() {
        let bar = CommandFormatting.makeBar(filled: -10, width: 10)
        #expect(bar == "[          ]")
    }

    @Test("makeBar clamps above 100%")
    func makeBarOver100() {
        let bar = CommandFormatting.makeBar(filled: 150, width: 10)
        #expect(bar == "[==========]")
    }

    @Test("makeBar with width 0 produces empty bar")
    func makeBarZeroWidth() {
        let bar = CommandFormatting.makeBar(filled: 50, width: 0)
        #expect(bar == "[]")
    }

    @Test("makeBar with width 1")
    func makeBarWidthOne() {
        #expect(CommandFormatting.makeBar(filled: 0, width: 1) == "[ ]")
        #expect(CommandFormatting.makeBar(filled: 100, width: 1) == "[=]")
    }
}
