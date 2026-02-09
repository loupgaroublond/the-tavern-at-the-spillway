import Foundation
import Testing
@testable import TavernCore

@Suite("PermissionMode Tests")
struct PermissionModeTests {

    @Test("All modes have display names")
    func allModesHaveDisplayNames() {
        for mode in PermissionMode.allCases {
            #expect(!mode.displayName.isEmpty)
        }
    }

    @Test("All modes have descriptions")
    func allModesHaveDescriptions() {
        for mode in PermissionMode.allCases {
            #expect(!mode.modeDescription.isEmpty)
        }
    }

    @Test("Mode raw values are correct")
    func modeRawValues() {
        #expect(PermissionMode.normal.rawValue == "normal")
        #expect(PermissionMode.acceptEdits.rawValue == "acceptEdits")
        #expect(PermissionMode.plan.rawValue == "plan")
        #expect(PermissionMode.bypassPermissions.rawValue == "bypassPermissions")
        #expect(PermissionMode.dontAsk.rawValue == "dontAsk")
    }

    @Test("Mode is codable round-trip")
    func modeCodableRoundTrip() throws {
        for mode in PermissionMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(PermissionMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    @Test("CaseIterable returns all 5 modes")
    func caseIterableCount() {
        #expect(PermissionMode.allCases.count == 5)
    }
}
