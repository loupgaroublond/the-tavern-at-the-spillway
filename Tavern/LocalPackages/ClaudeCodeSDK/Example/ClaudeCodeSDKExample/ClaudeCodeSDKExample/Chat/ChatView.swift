//
//  ChatView.swift
//  ClaudeCodeSDKExample
//
//  Created by James Rochabrun on 5/20/25.
//

import ClaudeCodeSDK
import Foundation
import SwiftUI

struct ChatView: View {
  
  @State var viewModel = ChatViewModel(claudeClient: ClaudeCodeClient(debug: true))
  @State private var messageText: String = ""
  @FocusState private var isTextFieldFocused: Bool
  @State private var showingSessions = false
  @State private var showingMCPConfig = false
  
  var body: some View {
    VStack {
      // Top button bar
      HStack {
        // List sessions button
        Button(action: {
          viewModel.listSessions()
          showingSessions = true
        }) {
          Image(systemName: "list.bullet.rectangle")
            .font(.title2)
        }
        
        // MCP Config button
        Button(action: {
          showingMCPConfig = true
        }) {
          Image(systemName: "gearshape")
            .font(.title2)
            .foregroundColor(viewModel.isMCPEnabled ? .green : .primary)
        }
        
        Spacer()
        
        Button(action: {
          clearChat()
        }) {
          Image(systemName: "trash")
            .font(.title2)
        }
        .disabled(viewModel.messages.isEmpty)
      }
      .padding(.horizontal)
      .padding(.top, 8)
      
      // Chat messages list
      ScrollViewReader { scrollView in
        List {
          ForEach(viewModel.messages) { message in
            MessageRow(message: message)
              .id(message.id)
          }
        }
        .onChange(of: viewModel.messages) { _, newMessages in
          // Scroll to bottom when new messages are added
          if let lastMessage = viewModel.messages.last {
            withAnimation {
              scrollView.scrollTo(lastMessage.id, anchor: .bottom)
            }
          }
        }
      }
      .listStyle(PlainListStyle())
      
      // Error message if present
      if let error = viewModel.error {
        Text(error.localizedDescription)
          .foregroundColor(.red)
          .padding()
      }
      // Input area
      HStack {
        TextEditor(text: $messageText)
          .padding(8)
          .frame(minHeight: 36, maxHeight: 90)
          .cornerRadius(20)
          .focused($isTextFieldFocused)
          .overlay(
            HStack {
              if messageText.isEmpty {
                Text("Type a message...")
                  .foregroundColor(.gray)
                  .padding(.leading, 12)
                  .padding(.top, 8)
                Spacer()
              }
            },
            alignment: .topLeading
          )
          .onKeyPress(.return) {
            sendMessage()
            return .ignored
          }
        
        if viewModel.isLoading {
          Button(action: {
            viewModel.cancelRequest()
          }) {
            Image(systemName: "stop.fill")
          }
          .padding(10)
        } else {
          Button(action: {
            sendMessage()
          }) {
            Image(systemName: "arrow.up.circle.fill")
              .foregroundColor(.blue)
              .font(.title2)
          }
          .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
    .navigationTitle("Claude Code Chat")
    .sheet(isPresented: $showingSessions) {
      SessionsListView(sessions: viewModel.sessions, isPresented: $showingSessions)
        .frame(minWidth: 500, minHeight: 500)
    }
    .sheet(isPresented: $showingMCPConfig) {
      MCPConfigView(
        isMCPEnabled: $viewModel.isMCPEnabled,
        mcpConfigPath: $viewModel.mcpConfigPath,
        isPresented: $showingMCPConfig
      )
      .frame(minWidth: 500, minHeight: 500)
    }
  }
  
  private func sendMessage() {
    let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    
    // Remove focus first
    viewModel.sendMessage(text)
    DispatchQueue.main.async {
      messageText = ""
    }
  }
  
  private func clearChat() {
    viewModel.clearConversation()
  }
}
