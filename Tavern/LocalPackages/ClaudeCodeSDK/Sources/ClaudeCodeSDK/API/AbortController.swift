//
//  AbortController.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 6/17/25.
//

import Foundation

/// Controller for aborting operations
/// Similar to the web AbortController API
public final class AbortController: Sendable {
  /// Signal that can be used to check if operation was aborted
  public let signal: AbortSignal
  
  public init() {
    self.signal = AbortSignal()
  }
  
  /// Abort the operation
  public func abort() {
    signal.abort()
  }
}

/// Signal that indicates if an operation was aborted
public final class AbortSignal: @unchecked Sendable {
  private var _aborted = false
  private var callbacks: [() -> Void] = []
  private let queue = DispatchQueue(label: "com.claudecode.abortsignal")
  
  /// Whether the operation has been aborted
  public var aborted: Bool {
    queue.sync { _aborted }
  }
  
  /// Add a callback to be called when aborted
  public func onAbort(_ callback: @escaping () -> Void) {
    queue.sync {
      if _aborted {
        callback()
      } else {
        callbacks.append(callback)
      }
    }
  }
  
  internal func abort() {
    queue.sync {
      guard !_aborted else { return }
      _aborted = true
      callbacks.forEach { $0() }
      callbacks.removeAll()
    }
  }
}
