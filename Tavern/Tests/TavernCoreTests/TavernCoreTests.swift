import Testing
@testable import TavernCore

@Suite("TavernCore Tests")
struct TavernCoreTests {

    @Test("Version is set")
    func versionIsSet() {
        #expect(TavernCore.version == "0.1.0")
    }
}
