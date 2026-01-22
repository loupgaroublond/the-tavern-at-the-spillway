//
//  ConfigScope.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 6/17/25.
//

import Foundation

/// Represents the scope of configuration settings
public enum ConfigScope: String, Codable {
  /// Local configuration (current directory)
  case local = "local"
  
  /// User-level configuration
  case user = "user"
  
  /// Project-level configuration
  case project = "project"
}
