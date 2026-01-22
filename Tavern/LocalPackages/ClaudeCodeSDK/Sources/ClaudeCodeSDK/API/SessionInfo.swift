//
//  SessionInfo.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation

/// Information about a Claude Code session
public struct SessionInfo: Codable, Identifiable {
  public let id: String
  public let created: String?
  public let lastActive: String?
  public let totalCostUsd: Double?
  public let project: String?
  
  private enum CodingKeys: String, CodingKey {
    case id
    case created
    case lastActive = "last_active"
    case totalCostUsd = "total_cost_usd"
    case project
  }
}
