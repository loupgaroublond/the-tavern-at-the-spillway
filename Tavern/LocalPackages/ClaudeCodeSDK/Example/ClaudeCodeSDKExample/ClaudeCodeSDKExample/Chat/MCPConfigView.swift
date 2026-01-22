//
//  MCPConfigView.swift
//  ClaudeCodeSDKExample
//
//  Created by Assistant on 6/17/25.
//

import SwiftUI

struct MCPConfigView: View {
  @Binding var isMCPEnabled: Bool
  @Binding var mcpConfigPath: String
  @Binding var isPresented: Bool
  
  var body: some View {
    Form {
      Section(header: Text("MCP Configuration")) {
        Toggle("Enable MCP", isOn: $isMCPEnabled)
        
        if isMCPEnabled {
          VStack(alignment: .leading, spacing: 8) {
            Text("Config File Path")
              .font(.caption)
              .foregroundColor(.secondary)
            
            HStack {
              TextField("e.g., /path/to/mcp-config.json", text: $mcpConfigPath)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disableAutocorrection(true)
              
              Button("Load Example") {
                // Get the absolute path to the example file
                let absolutePath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Example/ClaudeCodeSDKExample/mcp-config-example.json"
                
                // Check if file exists at the absolute path
                if FileManager.default.fileExists(atPath: absolutePath) {
                  mcpConfigPath = absolutePath
                } else {
                  // Try to find it relative to the app bundle (for when running from Xcode)
                  if let bundlePath = Bundle.main.resourcePath {
                    let bundleExamplePath = "\(bundlePath)/mcp-config-example.json"
                    if FileManager.default.fileExists(atPath: bundleExamplePath) {
                      mcpConfigPath = bundleExamplePath
                    } else {
                      // Show an error or use a placeholder
                      mcpConfigPath = "Error: Could not find mcp-config-example.json"
                    }
                  }
                }
              }
              .buttonStyle(.bordered)
            }
          }
        }
      }
      
      if isMCPEnabled {
        Section(header: Text("Example Configuration")) {
          Text(exampleConfig)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        
        Section(header: Text("Notes")) {
          Text("• MCP tools must be explicitly allowed using allowedTools")
            .font(.caption)
          Text("• MCP tool names follow the pattern: mcp__<serverName>__<toolName>")
            .font(.caption)
          Text("• Use mcp__<serverName> to allow all tools from a server")
            .font(.caption)
        }
        
        Section(header: Text("XcodeBuildMCP Features")) {
          Text("The example XcodeBuildMCP server provides tools for:")
            .font(.caption)
            .fontWeight(.semibold)
          Text("• Xcode project management")
            .font(.caption)
          Text("• iOS/macOS simulator management")
            .font(.caption)
          Text("• Building and running apps")
            .font(.caption)
          Text("• Managing provisioning profiles")
            .font(.caption)
        }
      }
    }
    .navigationTitle("MCP Settings")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button("Done") {
          isPresented = false
        }
      }
    }
  }
  
  private var exampleConfig: String {
    """
    {
      "mcpServers": {
        "XcodeBuildMCP": {
          "command": "npx",
          "args": [
            "-y",
            "xcodebuildmcp@latest"
          ]
        }
      }
    }
    """
  }
}
