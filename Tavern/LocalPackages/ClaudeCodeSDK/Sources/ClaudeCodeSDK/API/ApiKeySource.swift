//
//  ApiKeySource.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 6/17/25.
//

import Foundation

/// Represents the source of an API key used for authentication
public enum ApiKeySource: String, Codable {
  /// API key from user configuration
  case user = "user"
  
  /// API key from project configuration
  case project = "project"
  
  /// API key from organization configuration
  case org = "org"
  
  /// Temporary API key
  case temporary = "temporary"
}
