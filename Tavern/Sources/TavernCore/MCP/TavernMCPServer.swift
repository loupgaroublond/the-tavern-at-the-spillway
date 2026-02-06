import Foundation
import ClodKit
import os.log

/// Creates the Tavern's MCP server with tools for Jake to manage servitors.
///
/// Phase 1: summon + dismiss only (messaging/forwarding/reuse later)
///
/// - Parameters:
///   - spawner: The ServitorSpawner for creating/dismissing servitors
///   - onSummon: Callback when a servitor is summoned (for UI updates)
///   - onDismiss: Callback when a servitor is dismissed (for UI updates)
/// - Returns: An SDKMCPServer configured with Tavern tools
public func createTavernMCPServer(
    spawner: ServitorSpawner,
    onSummon: @escaping @Sendable (Servitor) async -> Void,
    onDismiss: @escaping @Sendable (UUID) async -> Void
) -> SDKMCPServer {
    SDKMCPServer(
        name: "tavern",
        version: "1.0.0",
        tools: [
            MCPTool(
                name: "summon_servitor",
                description: "Summon one of your Regulars to handle work. Auto-generates a name. Usually call with no params.",
                inputSchema: JSONSchema(
                    properties: [
                        "assignment": .string("What you need them for (optional)"),
                        "name": .string("Specific name (rare)")
                    ]
                ),
                handler: { args in
                    let assignment = args["assignment"] as? String
                    let name = args["name"] as? String

                    TavernLogger.coordination.info("MCP summon_servitor: assignment=\(assignment ?? "<none>"), name=\(name ?? "<auto>")")

                    do {
                        let servitor: Servitor
                        if let name = name {
                            servitor = try spawner.summon(name: name, assignment: assignment)
                        } else if let assignment = assignment {
                            servitor = try spawner.summon(assignment: assignment)
                        } else {
                            servitor = try spawner.summon()
                        }

                        await onSummon(servitor)

                        TavernLogger.coordination.info("MCP summon_servitor: summoned \(servitor.name) (id: \(servitor.id))")
                        return .text("Summoned \(servitor.name) (id: \(servitor.id))")
                    } catch {
                        TavernLogger.coordination.error("MCP summon_servitor failed: \(error.localizedDescription)")
                        return .error("Failed to summon servitor: \(error.localizedDescription)")
                    }
                }
            ),

            MCPTool(
                name: "dismiss_servitor",
                description: "Send a Regular home. They're off-duty, not fired.",
                inputSchema: JSONSchema(
                    properties: [
                        "id": .string("Servitor UUID")
                    ],
                    required: ["id"]
                ),
                handler: { args in
                    guard let idString = args["id"] as? String,
                          let id = UUID(uuidString: idString) else {
                        TavernLogger.coordination.error("MCP dismiss_servitor: invalid servitor ID")
                        return .error("Invalid servitor ID")
                    }

                    TavernLogger.coordination.info("MCP dismiss_servitor: id=\(id)")

                    do {
                        try spawner.dismiss(id: id)
                        await onDismiss(id)

                        TavernLogger.coordination.info("MCP dismiss_servitor: dismissed \(id)")
                        return .text("Dismissed servitor \(id)")
                    } catch {
                        TavernLogger.coordination.error("MCP dismiss_servitor failed: \(error.localizedDescription)")
                        return .error("Failed to dismiss servitor: \(error.localizedDescription)")
                    }
                }
            )
        ]
    )
}
