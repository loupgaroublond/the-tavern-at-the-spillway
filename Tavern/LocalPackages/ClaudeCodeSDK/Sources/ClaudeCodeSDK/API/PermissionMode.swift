//
//  PermissionMode.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 6/17/25.
//

import Foundation

/// Represents the permission mode for Claude Code operations
public enum PermissionMode: String, Codable, Sendable {
    /// Default permission mode - asks for user confirmation
    case `default` = "default"
    
    /// Automatically accepts edit operations
    case acceptEdits = "acceptEdits"
    
    /// Bypasses all permission checks (use with caution)
    case bypassPermissions = "bypassPermissions"
    
    /// Plan mode - creates a plan before executing
    case plan = "plan"
}
