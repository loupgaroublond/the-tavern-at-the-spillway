//
//  Message.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation
import SwiftAnthropic

public struct UserMessage: Decodable {
  public let type: String
  public let sessionId: String
  public let message: UserMessageContent
  
  public struct UserMessageContent: Decodable {
    public let role: String
    public let content: [MessageResponse.Content]
  }
}

