//
//  ClaudeCodeResult.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Combine
import Foundation

// MARK: - ClaudeCodeResult

/// Represents the different types of results that can be returned by Claude Code.
@frozen public enum ClaudeCodeResult {
  /// Plain text result
  case text(String)
  
  /// JSON result
  case json(ResultMessage)
  
  /// Streaming publisher for response chunks
  case stream(AnyPublisher<ResponseChunk, Error>)
  
  /// Session ID for resumed or continued conversations
  public var sessionId: String? {
    switch self {
    case .json(let result):
      return result.sessionId
    default:
      return nil
    }
  }
}
