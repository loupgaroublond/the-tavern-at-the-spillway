import Testing

// Tag declarations for provenance tracking (ADR-007).
// Convention: REQ-AGT-001 → .reqAGT001
extension Tag {
    // 016-quality (stress tests)
    @Tag static var reqQA006: Self

    // 003-system-architecture (concurrency stress)
    @Tag static var reqARCH007: Self
}
