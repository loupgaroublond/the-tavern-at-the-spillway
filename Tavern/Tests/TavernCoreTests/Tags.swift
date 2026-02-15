import Testing

// Tag declarations for provenance tracking (ADR-007).
// Convention: REQ-AGT-001 → .reqAGT001
extension Tag {
    // 004-agents
    @Tag static var reqAGT001: Self
    @Tag static var reqAGT002: Self
    @Tag static var reqAGT005: Self
    @Tag static var reqAGT007: Self
    @Tag static var reqAGT008: Self
    @Tag static var reqAGT009: Self
    @Tag static var reqAGT010: Self

    // 005-spawning
    @Tag static var reqSPN001: Self
    @Tag static var reqSPN002: Self
    @Tag static var reqSPN003: Self
    @Tag static var reqSPN004: Self
    @Tag static var reqSPN005: Self
    @Tag static var reqSPN006: Self
    @Tag static var reqSPN007: Self
    @Tag static var reqSPN009: Self
    @Tag static var reqSPN010: Self

    // 008-deterministic-shell
    @Tag static var reqDET004: Self
    @Tag static var reqDET005: Self

    // 010-doc-store
    @Tag static var reqDOC001: Self
    @Tag static var reqDOC002: Self
    @Tag static var reqDOC003: Self

    // 002-invariants
    @Tag static var reqINV003: Self
    @Tag static var reqINV005: Self
    @Tag static var reqINV007: Self

    // 006-lifecycle
    @Tag static var reqLCM004: Self

    // 009-communication
    @Tag static var reqCOM008: Self

    // 015-observability
    @Tag static var reqOBS005: Self
    @Tag static var reqOBS006: Self

    // 003-system-architecture
    @Tag static var reqARCH003: Self
    @Tag static var reqARCH006: Self
    @Tag static var reqARCH007: Self
    @Tag static var reqARCH009: Self

    // 007-operating-modes
    @Tag static var reqOPM001: Self
    @Tag static var reqOPM002: Self
    @Tag static var reqOPM004: Self
    @Tag static var reqOPM005: Self

    // 014-view-architecture
    @Tag static var reqVIW001: Self
    @Tag static var reqVIW003: Self
    @Tag static var reqVIW004: Self
    @Tag static var reqVIW005: Self

    // 013-user-experience
    @Tag static var reqUX002: Self
    @Tag static var reqUX003: Self
    @Tag static var reqUX005: Self
    @Tag static var reqUX006: Self
    @Tag static var reqUX009: Self
}
