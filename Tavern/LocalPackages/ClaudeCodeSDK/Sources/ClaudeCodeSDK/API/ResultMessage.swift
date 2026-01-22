//
//  ResultMessage.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation

public struct ResultMessage: Codable {
  public let type: String
  public let subtype: String
  public let totalCostUsd: Double
  public let durationMs: Int
  public let durationApiMs: Int
  public let isError: Bool
  public let numTurns: Int
  public let result: String?
  public let sessionId: String
  public let usage: Usage?
  
  /// Returns a formatted description of the result message with key information
  public func description() -> String {
    let resultText = result ?? "No result available"
    let durationSeconds = Double(durationMs) / 1000.0
    let durationApiSeconds = Double(durationApiMs) / 1000.0
    
    return """
        Result: \(resultText) \n\n
        Subtype: \(subtype), 
        Cost: $\(String(format: "%.6f", totalCostUsd)),
        Duration: \(String(format: "%.2f", durationSeconds))s, 
        API Duration: \(String(format: "%.2f", durationApiSeconds))s
        Error: \(isError ? "Yes" : "No")
        Number of Turns: \(numTurns)
        Total Cost: $\(String(format: "%.6f", totalCostUsd))
        """
  }
}

// Usage struct to handle the nested usage data
public struct Usage: Codable {
  public let inputTokens: Int
  public let cacheCreationInputTokens: Int
  public let cacheReadInputTokens: Int
  public let outputTokens: Int
  public let serverToolUse: ServerToolUse
}

public struct ServerToolUse: Codable {
  public let webSearchRequests: Int
}
