//
//  AssistantMessage.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation
import SwiftAnthropic

public struct AssistantMessage: Decodable {
  public let type: String
  public let sessionId: String
  public let message: MessageResponse
}
