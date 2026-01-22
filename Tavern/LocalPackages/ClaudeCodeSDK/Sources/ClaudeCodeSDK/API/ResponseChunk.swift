//
//  ResponseChunk.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation

public enum ResponseChunk {
  case initSystem(InitSystemMessage)
  case user(UserMessage)
  case assistant(AssistantMessage)
  case result(ResultMessage)
  
  public var sessionId: String {
    switch self {
    case .initSystem(let msg): return msg.sessionId
    case .user(let msg): return msg.sessionId
    case .assistant(let msg): return msg.sessionId
    case .result(let msg): return msg.sessionId
    }
  }
}
