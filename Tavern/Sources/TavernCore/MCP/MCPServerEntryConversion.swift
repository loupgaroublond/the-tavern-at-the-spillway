import Foundation
import ClodKit

// MARK: - Provenance: REQ-ARCH-009

// MARK: - MCPServerEntry → MCPServerConfig Conversion

extension MCPServerEntry {
    /// Convert to ClodKit's MCPServerConfig for use in QueryOptions.
    public func toMCPServerConfig() -> MCPServerConfig {
        MCPServerConfig(command: command, args: args, env: env)
    }
}

extension Dictionary where Key == String, Value == MCPServerEntry {
    /// Convert all entries to ClodKit MCPServerConfig dictionary.
    public func toMCPServerConfigs() -> [String: MCPServerConfig] {
        mapValues { $0.toMCPServerConfig() }
    }
}
