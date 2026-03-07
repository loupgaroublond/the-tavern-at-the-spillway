import Foundation
import ClodKit

// MARK: - Provenance: REQ-ARCH-009

/// Tavern-owned value type representing account and session metadata.
/// Maps from ClodKit's `AccountInfo` and `SDKControlInitializeResponse`
/// so the rest of the codebase never depends on ClodKit types directly.
public struct TavernAccountInfo: Sendable, Equatable {

    /// Account email address.
    public let email: String?

    /// Organization name.
    public let organization: String?

    /// Subscription type (e.g., "pro", "team", "enterprise").
    public let subscriptionType: String?

    /// Available model identifiers.
    public let availableModels: [String]

    /// Timestamp when this info was fetched.
    public let fetchedAt: Date

    public init(
        email: String? = nil,
        organization: String? = nil,
        subscriptionType: String? = nil,
        availableModels: [String] = [],
        fetchedAt: Date = Date()
    ) {
        self.email = email
        self.organization = organization
        self.subscriptionType = subscriptionType
        self.availableModels = availableModels
        self.fetchedAt = fetchedAt
    }

    /// Create from ClodKit's AccountInfo and optional initialization result.
    static func from(
        account: AccountInfo,
        initResult: SDKControlInitializeResponse? = nil,
        fetchedAt: Date = Date()
    ) -> TavernAccountInfo {
        TavernAccountInfo(
            email: account.email,
            organization: account.organization,
            subscriptionType: account.subscriptionType,
            availableModels: initResult?.models.map(\.value) ?? [],
            fetchedAt: fetchedAt
        )
    }
}
