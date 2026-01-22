//
//  CancellationTests.swift
//  ClaudeCodeSDKTests
//
//  Created by ClaudeCodeSDK Tests
//

import XCTest
@testable import ClaudeCodeSDK
import Foundation

final class CancellationTests: XCTestCase {
  
  func testAbortControllerInitialization() {
    // Test AbortController creation
    let abortController = AbortController()
    
    XCTAssertNotNil(abortController)
    XCTAssertFalse(abortController.signal.aborted)
  }
  
  func testAbortControllerAbort() {
    // Test abort functionality
    let abortController = AbortController()
    
    XCTAssertFalse(abortController.signal.aborted)
    
    abortController.abort()
    
    XCTAssertTrue(abortController.signal.aborted)
  }
  
  func testAbortControllerInOptions() {
    // Test AbortController in options as shown in README
    var options = ClaudeCodeOptions()
    let abortController = AbortController()
    options.abortController = abortController
    
    XCTAssertNotNil(options.abortController)
    XCTAssertFalse(options.abortController?.signal.aborted ?? true)
    
    // Simulate cancellation
    abortController.abort()
    
    XCTAssertTrue(options.abortController?.signal.aborted ?? false)
  }
  
  func testMultipleAborts() {
    // Test that multiple aborts are handled gracefully
    let abortController = AbortController()
    
    abortController.abort()
    XCTAssertTrue(abortController.signal.aborted)
    
    // Second abort should not cause issues
    abortController.abort()
    XCTAssertTrue(abortController.signal.aborted)
  }
  
  func testAbortSignalFunctionality() {
    // Test abort signal functionality
    let abortController = AbortController()
    
    // Should not be aborted initially
    XCTAssertFalse(abortController.signal.aborted)
    
    // Test onAbort callback
    var callbackCalled = false
    abortController.signal.onAbort {
      callbackCalled = true
    }
    
    // Abort the controller
    abortController.abort()
    
    // Should be aborted and callback should be called
    XCTAssertTrue(abortController.signal.aborted)
    XCTAssertTrue(callbackCalled)
  }
  
  func testCancellationPatternFromReadme() async throws {
    // Test the cancellation pattern from README
    var options = ClaudeCodeOptions()
    let abortController = AbortController()
    options.abortController = abortController
    
    // Simulate starting an operation in a task
    let operationTask = Task<String, Error> {
      // Simulate a long-running operation that checks for cancellation
      for _ in 0..<10 {
        if abortController.signal.aborted {
          throw ClaudeCodeError.cancelled
        }
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
      }
      return "Completed"
    }
    
    // Let it run briefly
    try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    
    // Cancel when needed
    abortController.abort()
    
    // The operation should fail with cancellation error
    do {
      _ = try await operationTask.value
      XCTFail("Expected cancellation error")
    } catch ClaudeCodeError.cancelled {
      // Expected
    } catch {
      XCTFail("Expected ClaudeCodeError.cancelled, got \(error)")
    }
  }
}