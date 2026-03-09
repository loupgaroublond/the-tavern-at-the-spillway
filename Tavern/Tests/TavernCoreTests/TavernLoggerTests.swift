// MARK: - Provenance: REQ-OBS-008, REQ-OBS-009

import os.log
import Testing
@testable import TavernCore

@Suite("TavernLogger Tests", .tags(.reqOBS008, .reqOBS009), .timeLimit(.minutes(2)))
struct TavernLoggerTests {

    // MARK: - Category Existence (REQ-OBS-008)

    @Test("All 7 logging categories exist")
    func allCategoriesExist() {
        // Each static property must resolve to a CategoryLogger instance.
        // A missing property would be a compile error; at runtime we verify
        // they resolve to valid CategoryLogger values and we have exactly 7.
        let loggers: [String: CategoryLogger] = [
            "agents": TavernLogger.agents,
            "chat": TavernLogger.chat,
            "coordination": TavernLogger.coordination,
            "claude": TavernLogger.claude,
            "resources": TavernLogger.resources,
            "permissions": TavernLogger.permissions,
            "commands": TavernLogger.commands,
        ]

        #expect(loggers.count == 7, "Expected exactly 7 logging categories")
    }

    @Test("All categories are distinct CategoryLogger instances")
    func categoriesAreDistinct() {
        // CategoryLogger instances with distinct categories should have
        // distinct category strings.
        let loggers: [CategoryLogger] = [
            TavernLogger.agents,
            TavernLogger.chat,
            TavernLogger.coordination,
            TavernLogger.claude,
            TavernLogger.resources,
            TavernLogger.permissions,
            TavernLogger.commands,
        ]

        let categories = loggers.map { $0.category }
        let unique = Set(categories)
        #expect(unique.count == 7, "All 7 loggers must be distinct (got \(unique.count))")
    }

    // MARK: - Subsystem and Category Verification (REQ-OBS-008)

    @Test("All loggers have non-empty category names")
    func loggersHaveCategories() {
        let loggers: [(String, CategoryLogger)] = [
            ("agents", TavernLogger.agents),
            ("chat", TavernLogger.chat),
            ("coordination", TavernLogger.coordination),
            ("claude", TavernLogger.claude),
            ("resources", TavernLogger.resources),
            ("permissions", TavernLogger.permissions),
            ("commands", TavernLogger.commands),
        ]

        for (expectedCategory, logger) in loggers {
            #expect(
                logger.category == expectedCategory,
                "Logger category should be '\(expectedCategory)' but was '\(logger.category)'"
            )
        }
    }

    // MARK: - Debug Extension Methods (REQ-OBS-009)

    @Test("debugError method can be called on any CategoryLogger")
    func debugErrorCallable() {
        let logger = TavernLogger.agents
        logger.debugError("Test error message")
    }

    @Test("debugInfo method can be called on any CategoryLogger")
    func debugInfoCallable() {
        let logger = TavernLogger.chat
        logger.debugInfo("Test info message")
    }

    @Test("debugLog method can be called on any CategoryLogger")
    func debugLogCallable() {
        let logger = TavernLogger.coordination
        logger.debugLog("Test debug message")
    }

    @Test("Debug methods work on all category loggers")
    func debugMethodsWorkOnAllCategories() {
        let loggers: [CategoryLogger] = [
            TavernLogger.agents,
            TavernLogger.chat,
            TavernLogger.coordination,
            TavernLogger.claude,
            TavernLogger.resources,
            TavernLogger.permissions,
            TavernLogger.commands,
        ]

        for logger in loggers {
            logger.debugError("error from test")
            logger.debugInfo("info from test")
            logger.debugLog("debug from test")
        }
    }

    // MARK: - Enum Shape (REQ-OBS-008)

    @Test("TavernLogger is a caseless enum (non-instantiable namespace)")
    func tavernLoggerIsNamespace() {
        // TavernLogger is declared as `enum TavernLogger` with no cases.
        // This means it cannot be instantiated — it serves purely as a namespace.
        // We verify the type exists and its static members are accessible.
        // If someone accidentally added a case, the type would become instantiable,
        // which would change its semantics. The compiler enforces this at the
        // declaration site, but we document the expectation here.
        let _: CategoryLogger = TavernLogger.agents
        let _: CategoryLogger = TavernLogger.chat
        let _: CategoryLogger = TavernLogger.coordination
        let _: CategoryLogger = TavernLogger.claude
        let _: CategoryLogger = TavernLogger.resources
        let _: CategoryLogger = TavernLogger.permissions
        let _: CategoryLogger = TavernLogger.commands
    }
}
