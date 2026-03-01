import Testing

// MARK: - Provenance: REQ-FID-002, REQ-FID-003, REQ-FID-007

// Tag declarations for provenance tracking (ADR-007).
// Convention: REQ-AGT-001 → .reqAGT001
extension Tag {
    // 016-quality (stress tests)
    @Tag static var reqQA006: Self
    @Tag static var reqQA014: Self

    // 003-system-architecture (concurrency stress)
    @Tag static var reqARCH007: Self
}
