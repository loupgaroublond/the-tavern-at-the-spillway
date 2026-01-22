# ClaudeCodeSDK Example App

This example demonstrates how to use the ClaudeCodeSDK with MCP (Model Context Protocol) support.

## Features

- **Chat Interface**: Interactive chat with Claude Code
- **Session Management**: View and manage previous Claude Code sessions
- **MCP Configuration**: Enable and configure MCP servers

## Using MCP Configuration

1. Click the gear icon (⚙️) in the toolbar
2. Toggle "Enable MCP" to ON
3. Either:
   - Click "Load Example" to use the included `mcp-config-example.json`
   - Or provide your own path to an MCP configuration file

### Example MCP Config

The included `mcp-config-example.json` demonstrates integration with XcodeBuildMCP:

```json
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
```

This configuration enables Claude Code to interact with Xcode build tools.

### Creating Your Own MCP Config

You can create custom MCP configurations for different servers:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/path/to/allowed/files"
      ]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "your-github-token"
      }
    }
  }
}
```

## MCP Tool Naming Convention

When MCP is enabled, tools from MCP servers follow a specific naming pattern:
- `mcp__<serverName>__<toolName>`

For example, with the XcodeBuildMCP server, tools are available as:
- `mcp__XcodeBuildMCP__build`
- `mcp__XcodeBuildMCP__test`
- `mcp__XcodeBuildMCP__clean`

The example app automatically:
1. Reads your MCP configuration file
2. Extracts all server names
3. Generates wildcard patterns like `mcp__XcodeBuildMCP__*` to allow all tools from each server
4. Adds these patterns to the allowed tools list

## Important Notes

- MCP tools must be explicitly allowed using the correct naming convention
- Use wildcards like `mcp__<serverName>__*` to allow all tools from a server
- The SDK handles the tool naming automatically when you provide an MCP configuration

## Session Management

Click the list icon (📋) to view all your Claude Code sessions, including:
- Session IDs
- Creation and last active dates
- Total cost per session
- Associated project names