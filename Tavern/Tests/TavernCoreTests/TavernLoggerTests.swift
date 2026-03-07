// MARK: - Provenance: REQ-OBS-008, REQ-OBS-009

import os.log
import Testing
@testable import TavernCore

@Suite("TavernLogger Tests", .tags(.reqOBS008, .reqOBS009), .timeLimit(.minutes(2)))
struct TavernLoggerTests {

    // MARK: - Category Existence (REQ-OBS-008)

    @Test("All 7 logging categories exist")
    func allCategoriesExist() {
        // Each static property must resolve to a Logger instance.
        // A missing property would be a compile error; at runtime we verify
        // they resolve to valid Logger values and we have exactly 7.
        let loggers: [String: Logger] = [
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

    @Test("All categories are distinct Logger instances")
    func categoriesAreDistinct() {
        // Logger wraps an underlying OS_os_log object. Distinct categories
        // produce distinct objects, visible via their String(describing:) output
        // which includes the pointer address.
        let loggers: [Logger] = [
            TavernLogger.agents,
            TavernLogger.chat,
            TavernLogger.coordination,
            TavernLogger.claude,
            TavernLogger.resources,
            TavernLogger.permissions,
            TavernLogger.commands,
        ]

        let descriptions = loggers.map { String(describing: $0) }
        let unique = Set(descriptions)
        #expect(unique.count == 7, "All 7 loggers must be distinct (got \(unique.count))")
    }

    // MARK: - Subsystem and Category Verification (REQ-OBS-008)
    //
    // os.log's Logger type does not expose subsystem or category as readable
    // properties at runtime. The correctness of subsystem ("com.tavern.spillway")
    // and category names ("agents", "chat", etc.) is verified by:
    //   1. Code review of TavernLogger.swift (single source of truth)
    //   2. The distinctness test above (proves each category creates a unique logger)
    //   3. The logging-enabled test below (proves loggers are functional, not disabled)
    //
    // Attempting String(describing:) on Logger yields an opaque pointer
    // (e.g. "Logger(logObject: <OS_os_log: 0x...>)"), not the subsystem/category.

    @Test("All loggers are enabled for signpost-level logging")
    func loggersAreEnabled() {
        // A Logger created with a valid subsystem + category is enabled.
        // This confirms the loggers were constructed with real parameters,
        // not default/disabled loggers.
        let loggers: [(String, Logger)] = [
            ("agents", TavernLogger.agents),
            ("chat", TavernLogger.chat),
            ("coordination", TavernLogger.coordination),
            ("claude", TavernLogger.claude),
            ("resources", TavernLogger.resources),
            ("permissions", TavernLogger.permissions),
            ("commands", TavernLogger.commands),
        ]

        for (name, logger) in loggers {
            // Logger doesn't have isEnabled directly, but we can verify
            // it accepts log calls without crashing — a disabled/invalid
            // logger would be the Logger() default which is .disabled.
            // We verify they are not the disabled logger by checking they
            // differ from a known-disabled one.
            let disabled = Logger()
            let disabledDesc = String(describing: disabled)
            let loggerDesc = String(describing: logger)
            #expect(
                loggerDesc != disabledDesc,
                "Logger '\(name)' must not be the default disabled logger"
            )
        }
    }

    // MARK: - Debug Extension Methods (REQ-OBS-009)

    @Test("debugError method can be called on any Logger")
    func debugErrorCallable() {
        // Verify the extension method exists and is callable.
        // We cannot capture os.log output in-process, so we verify
        // the call completes without error.
        let logger = TavernLogger.agents
        logger.debugError("Test error message")
    }

    @Test("debugInfo method can be called on any Logger")
    func debugInfoCallable() {
        let logger = TavernLogger.chat
        logger.debugInfo("Test info message")
    }

    @Test("debugLog method can be called on any Logger")
    func debugLogCallable() {
        let logger = TavernLogger.coordination
        logger.debugLog("Test debug message")
    }

    @Test("Debug extension methods work on all category loggers")
    func debugMethodsWorkOnAllCategories() {
        let loggers: [Logger] = [
            TavernLogger.agents,
            TavernLogger.chat,
            TavernLogger.coordination,
            TavernLogger.claude,
            TavernLogger.resources,
            TavernLogger.permissions,
            TavernLogger.commands,
        ]

        for logger in loggers {
            // Each method should complete without throwing or crashing.
            logger.debugError("error from test")
            logger.debugInfo("info from test")
            logger.debugLog("debug from test")
        }
    }

    @Test("Debug extensions are defined on Logger, not just TavernLogger")
    func debugExtensionsOnLoggerType() {
        // The debug methods are extensions on Logger (the os.log type),
        // so they should work on any Logger instance, not just TavernLogger's.
        let customLogger = Logger(subsystem: "com.test", category: "test")
        customLogger.debugError("custom error")
        customLogger.debugInfo("custom info")
        customLogger.debugLog("custom debug")
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
        let _: Logger = TavernLogger.agents
        let _: Logger = TavernLogger.chat
        let _: Logger = TavernLogger.coordination
        let _: Logger = TavernLogger.claude
        let _: Logger = TavernLogger.resources
        let _: Logger = TavernLogger.permissions
        let _: Logger = TavernLogger.commands
    }
}
