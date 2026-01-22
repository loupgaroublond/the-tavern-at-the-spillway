//
//  RetryLogicTests.swift
//  ClaudeCodeSDKTests
//
//  Created by ClaudeCodeSDK Tests
//

import XCTest
@testable import ClaudeCodeSDK
import Foundation

final class RetryLogicTests: XCTestCase {
  
  func testDefaultRetryPolicy() {
    // Test default retry policy as shown in README
    let defaultPolicy = RetryPolicy.default
    
    XCTAssertEqual(defaultPolicy.maxAttempts, 3)
    XCTAssertEqual(defaultPolicy.initialDelay, 1.0)
    XCTAssertEqual(defaultPolicy.maxDelay, 60.0)
    XCTAssertEqual(defaultPolicy.backoffMultiplier, 2.0)
    XCTAssertTrue(defaultPolicy.useJitter)
  }
  
  func testCustomRetryPolicy() {
    // Test custom retry policy from README
    let conservativePolicy = RetryPolicy(
      maxAttempts: 5,
      initialDelay: 5.0,
      maxDelay: 300.0,
      backoffMultiplier: 2.0,
      useJitter: true
    )
    
    XCTAssertEqual(conservativePolicy.maxAttempts, 5)
    XCTAssertEqual(conservativePolicy.initialDelay, 5.0)
    XCTAssertEqual(conservativePolicy.maxDelay, 300.0)
    XCTAssertEqual(conservativePolicy.backoffMultiplier, 2.0)
    XCTAssertTrue(conservativePolicy.useJitter)
  }
  
  func testExponentialBackoffCalculation() {
    // Test exponential backoff calculation
    let policy = RetryPolicy(
      maxAttempts: 5,
      initialDelay: 1.0,
      maxDelay: 100.0,
      backoffMultiplier: 2.0,
      useJitter: false // Disable jitter for predictable testing
    )
    
    // Test delay calculation for each attempt (attempt numbers start at 1)
    XCTAssertEqual(policy.delay(for: 1), 1.0)  // First attempt: 1s
    XCTAssertEqual(policy.delay(for: 2), 2.0)  // Second attempt: 2s
    XCTAssertEqual(policy.delay(for: 3), 4.0)  // Third attempt: 4s
    XCTAssertEqual(policy.delay(for: 4), 8.0)  // Fourth attempt: 8s
    XCTAssertEqual(policy.delay(for: 5), 16.0) // Fifth attempt: 16s
    
    // Test max delay capping
    let bigAttempt = 10
    XCTAssertEqual(policy.delay(for: bigAttempt), 100.0) // Should be capped at maxDelay
  }
  
  func testJitterApplication() {
    // Test that jitter adds randomness
    let policy = RetryPolicy(
      maxAttempts: 3,
      initialDelay: 10.0,
      maxDelay: 100.0,
      backoffMultiplier: 2.0,
      useJitter: true
    )
    
    // Get multiple delays for the same attempt
    let delays = (0..<10).map { _ in policy.delay(for: 1) }
    
    // With jitter, delays should vary
    let uniqueDelays = Set(delays)
    XCTAssertGreaterThan(uniqueDelays.count, 1, "Jitter should produce varying delays")
    
    // All delays should be within expected range (50% to 100% of calculated delay)
    let expectedBase = 20.0 // 10 * 2^1
    for delay in delays {
      XCTAssertGreaterThanOrEqual(delay, expectedBase * 0.5)
      XCTAssertLessThanOrEqual(delay, expectedBase)
    }
  }
  
  func testRetryPolicyMaxAttempts() {
    // Test max attempts configuration
    let policy = RetryPolicy(maxAttempts: 3, initialDelay: 1.0, maxDelay: 10.0, backoffMultiplier: 2.0, useJitter: false)
    
    XCTAssertEqual(policy.maxAttempts, 3)
    
    // Test that delay calculation works for different attempts
    XCTAssertEqual(policy.delay(for: 1), 1.0)
    XCTAssertEqual(policy.delay(for: 2), 2.0) 
    XCTAssertEqual(policy.delay(for: 3), 4.0)
  }
  
  func testNoRetryPolicy() {
    // Test policy with no retries
    let noRetryPolicy = RetryPolicy(maxAttempts: 1, initialDelay: 1.0, maxDelay: 1.0, backoffMultiplier: 1.0, useJitter: false)
    
    XCTAssertEqual(noRetryPolicy.maxAttempts, 1)
  }
  
  func testAggressiveRetryPolicy() {
    // Test aggressive retry policy
    let aggressivePolicy = RetryPolicy.aggressive
    
    XCTAssertEqual(aggressivePolicy.maxAttempts, 5)
    XCTAssertEqual(aggressivePolicy.initialDelay, 0.5)
    XCTAssertEqual(aggressivePolicy.maxDelay, 30.0)
    XCTAssertEqual(aggressivePolicy.backoffMultiplier, 1.5)
  }
}