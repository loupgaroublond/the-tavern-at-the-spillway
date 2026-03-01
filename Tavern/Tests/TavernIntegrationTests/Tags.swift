import Testing

// MARK: - Provenance: REQ-FID-002, REQ-FID-003, REQ-FID-007

// Tag declarations for provenance tracking (ADR-007).
// Convention: REQ-AGT-001 → .reqAGT001
extension Tag {
    // 017-v1-scope (integration tests)
    @Tag static var reqV1001: Self
    @Tag static var reqV1002: Self
    @Tag static var reqV1003: Self
    @Tag static var reqV1005: Self
    @Tag static var reqV1006: Self

    @Tag static var reqV1016: Self

    // 016-quality (integration tests)
    @Tag static var reqQA004: Self
    @Tag static var reqQA009: Self
    @Tag static var reqQA012: Self
}
