//
//  SessionsListView.swift
//  ClaudeCodeSDKExample
//
//  Created by Assistant on 6/17/25.
//

import SwiftUI
import ClaudeCodeSDK

struct SessionsListView: View {
  let sessions: [SessionInfo]
  @Binding var isPresented: Bool
  
  var body: some View {
    NavigationView {
      VStack {
        if sessions.isEmpty {
          Text("No sessions found")
            .foregroundColor(.secondary)
            .padding()
        } else {
          List(sessions, id: \.id) { session in
            VStack(alignment: .leading, spacing: 4) {
              Text(session.id)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
              
              if let created = session.created {
                Text("Created: \(formattedDate(created))")
                  .font(.caption)
              }
              
              HStack {
                if let lastActive = session.lastActive {
                  Text("Last active: \(formattedDate(lastActive))")
                    .font(.caption)
                }
                
                Spacer()
                
                if let totalCost = session.totalCostUsd {
                  Text("$\(String(format: "%.4f", totalCost))")
                    .font(.caption)
                    .foregroundColor(.blue)
                }
              }
              
              if let project = session.project {
                Text("Project: \(project)")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            .padding(.vertical, 4)
          }
        }
      }
      .navigationTitle("Sessions")
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button("Done") {
            isPresented = false
          }
        }
      }
    }
  }
  
  private func formattedDate(_ dateString: String) -> String {
    // Try to parse ISO8601 date
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    if let date = formatter.date(from: dateString) {
      let displayFormatter = DateFormatter()
      displayFormatter.dateStyle = .short
      displayFormatter.timeStyle = .short
      return displayFormatter.string(from: date)
    }
    
    return dateString
  }
}
