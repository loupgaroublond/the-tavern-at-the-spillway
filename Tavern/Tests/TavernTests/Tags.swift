import Testing

// MARK: - Provenance: REQ-FID-002, REQ-FID-003, REQ-FID-007

// Tag declarations for provenance tracking (ADR-007).
// Convention: REQ-AGT-001 → .reqAGT001
extension Tag {
    // 014-view-architecture (wiring tests)
    @Tag static var reqVIW004: Self

    // 013-user-experience (wiring tests)
    @Tag static var reqUX002: Self
    @Tag static var reqUX003: Self

    // 016-quality (view wiring tests)
    @Tag static var reqQA003: Self
}
