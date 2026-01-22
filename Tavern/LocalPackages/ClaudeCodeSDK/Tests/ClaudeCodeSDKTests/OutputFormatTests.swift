//
//  OutputFormatTests.swift
//  ClaudeCodeSDKTests
//
//  Created by ClaudeCodeSDK Tests
//

import XCTest
@testable import ClaudeCodeSDK
import Foundation

final class OutputFormatTests: XCTestCase {
  
  func testOutputFormatCommandArguments() {
    // Test that output formats produce correct command arguments
    XCTAssertEqual(ClaudeCodeOutputFormat.text.commandArgument, "--output-format text")
    XCTAssertEqual(ClaudeCodeOutputFormat.json.commandArgument, "--output-format json")
    XCTAssertEqual(ClaudeCodeOutputFormat.streamJson.commandArgument, "--output-format stream-json")
  }
  
  func testResultTypeMatching() {
    // Test result type creation for different output formats
    let textContent = "Hello, world!"
    let textResult = ClaudeCodeResult.text(textContent)
    
    if case .text(let content) = textResult {
      XCTAssertEqual(content, textContent)
    } else {
      XCTFail("Expected text result")
    }
    
    // Test JSON result - ResultMessage is complex and requires all fields
    // For now, we'll just verify the enum case works
    // In real usage, ResultMessage would be decoded from JSON
  }
}