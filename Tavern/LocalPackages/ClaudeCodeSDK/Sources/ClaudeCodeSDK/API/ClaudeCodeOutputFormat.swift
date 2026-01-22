//
//  File.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation

public enum ClaudeCodeOutputFormat: String {
  /// Plain text output (default)
  case text
  
  /// JSON formatted output
  case json
  
  /// Streaming JSON output
  case streamJson = "stream-json"
  
  /// Command line argument
  var commandArgument: String {
    return "--output-format \(rawValue)"
  }
}
