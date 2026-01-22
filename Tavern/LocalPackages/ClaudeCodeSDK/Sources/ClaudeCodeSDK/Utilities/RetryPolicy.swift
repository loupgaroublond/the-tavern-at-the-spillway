//
//  RetryPolicy.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 6/17/25.
//

import Foundation
import OSLog

/// Configuration for retry behavior
public struct RetryPolicy: Sendable {
  /// Maximum number of retry attempts
  public let maxAttempts: Int
  
  /// Initial delay between retries in seconds
  public let initialDelay: TimeInterval
  
  /// Maximum delay between retries in seconds
  public let maxDelay: TimeInterval
  
  /// Multiplier for exponential backoff
  public let backoffMultiplier: Double
  
  /// Whether to add jitter to retry delays
  public let useJitter: Bool
  
  /// Default retry policy with reasonable defaults
  public static let `default` = RetryPolicy(
    maxAttempts: 3,
    initialDelay: 1.0,
    maxDelay: 60.0,
    backoffMultiplier: 2.0,
    useJitter: true
  )
  
  /// Conservative retry policy for rate-limited operations
  public static let conservative = RetryPolicy(
    maxAttempts: 5,
    initialDelay: 5.0,
    maxDelay: 300.0,
    backoffMultiplier: 2.0,
    useJitter: true
  )
  
  /// Aggressive retry policy for transient failures
  public static let aggressive = RetryPolicy(
    maxAttempts: 10,
    initialDelay: 0.5,
    maxDelay: 30.0,
    backoffMultiplier: 1.5,
    useJitter: true
  )
  
  public init(
    maxAttempts: Int,
    initialDelay: TimeInterval,
    maxDelay: TimeInterval,
    backoffMultiplier: Double,
    useJitter: Bool
  ) {
    self.maxAttempts = maxAttempts
    self.initialDelay = initialDelay
    self.maxDelay = maxDelay
    self.backoffMultiplier = backoffMultiplier
    self.useJitter = useJitter
  }
  
  /// Calculate delay for a given attempt number
  func delay(for attempt: Int) -> TimeInterval {
    let exponentialDelay = initialDelay * pow(backoffMultiplier, Double(attempt - 1))
    var delay = min(exponentialDelay, maxDelay)
    
    if useJitter {
      // Add random jitter (±25% of delay)
      let jitter = delay * 0.25 * (Double.random(in: -1...1))
      delay = max(0, delay + jitter)
    }
    
    return delay
  }
}

/// Retry handler for ClaudeCode operations
public final class RetryHandler {
  private let policy: RetryPolicy
  private let logger: Logger?
  
  public init(policy: RetryPolicy = .default, logger: Logger? = nil) {
    self.policy = policy
    self.logger = logger
  }
  
  /// Execute an operation with retry logic
  public func execute<T>(
    operation: String,
    task: () async throws -> T
  ) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...policy.maxAttempts {
      do {
        let log = "Attempting \(operation) (attempt \(attempt)/\(policy.maxAttempts))"
        logger?.debug("\(log)")
        return try await task()
      } catch let error as ClaudeCodeError {
        lastError = error
        
        // Check if error is retryable
        guard error.isRetryable else {
          logger?.error("\(operation) failed with non-retryable error: \(error.localizedDescription)")
          throw error
        }
        
        // Don't retry on last attempt
        guard attempt < policy.maxAttempts else {
          let log = "\(operation) failed after \(policy.maxAttempts) attempts"
          logger?.error("\(log)")
          throw error
        }
        
        // Calculate delay
        let baseDelay = policy.delay(for: attempt)
        let delay = error.suggestedRetryDelay ?? baseDelay
        
        let log = "\(operation) failed (attempt \(attempt)/\(policy.maxAttempts)), retrying in \(Int(delay))s: \(error.localizedDescription)"
        logger?.info("\(log)")
        
        // Wait before retry
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
      } catch {
        // Non-ClaudeCodeError, don't retry
        let log = "\(operation) failed with unexpected error: \(error.localizedDescription)"
        logger?.error("\(log)")
        throw error
      }
    }
    
    // Should never reach here, but just in case
    throw lastError ?? ClaudeCodeError.executionFailed("Retry logic error")
  }
}

/// Extension to add retry support to ClaudeCode protocol
public extension ClaudeCode {
  /// Run a single prompt with retry logic
  func runSinglePromptWithRetry(
    prompt: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions? = nil,
    retryPolicy: RetryPolicy = .default
  ) async throws -> ClaudeCodeResult {
    let handler = RetryHandler(policy: retryPolicy)
    return try await handler.execute(operation: "runSinglePrompt") {
      try await self.runSinglePrompt(
        prompt: prompt,
        outputFormat: outputFormat,
        options: options
      )
    }
  }
  
  /// Continue conversation with retry logic
  func continueConversationWithRetry(
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions? = nil,
    retryPolicy: RetryPolicy = .default
  ) async throws -> ClaudeCodeResult {
    let handler = RetryHandler(policy: retryPolicy)
    return try await handler.execute(operation: "continueConversation") {
      try await self.continueConversation(
        prompt: prompt,
        outputFormat: outputFormat,
        options: options
      )
    }
  }
  
  /// Resume conversation with retry logic
  func resumeConversationWithRetry(
    sessionId: String,
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions? = nil,
    retryPolicy: RetryPolicy = .default
  ) async throws -> ClaudeCodeResult {
    let handler = RetryHandler(policy: retryPolicy)
    return try await handler.execute(operation: "resumeConversation") {
      try await self.resumeConversation(
        sessionId: sessionId,
        prompt: prompt,
        outputFormat: outputFormat,
        options: options
      )
    }
  }
}
