import SwiftUI
import TavernCore
import os.log

/// View for managing permission rules and switching permission modes.
///
/// Displays the current mode selector and a list of all permission rules
/// with the ability to add/remove rules.
struct PermissionSettingsView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "permissions")

    @ObservedObject var viewModel: PermissionSettingsViewModel

    var body: some View {
        let _ = Self.logger.debug("[PermissionSettingsView] body - mode: \(viewModel.currentMode.rawValue), rules: \(viewModel.rules.count)")

        VStack(alignment: .leading, spacing: 16) {
            // Mode selector
            Section {
                Picker("Permission Mode", selection: $viewModel.currentMode) {
                    ForEach(PermissionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(viewModel.currentMode.modeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Mode")
                    .font(.headline)
            }

            Divider()

            // Rules list
            Section {
                if viewModel.rules.isEmpty {
                    Text("No permission rules configured.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    List {
                        ForEach(viewModel.rules) { rule in
                            HStack {
                                Image(systemName: rule.decision == .allow ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(rule.decision == .allow ? .green : .red)

                                VStack(alignment: .leading) {
                                    Text(rule.toolPattern)
                                        .font(.body.monospaced())
                                    if let note = rule.note {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(rule.decision == .allow ? "Allow" : "Deny")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button(role: .destructive) {
                                    viewModel.removeRule(id: rule.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .frame(minHeight: 100)
                }

                // Add rule controls
                HStack {
                    TextField("Tool pattern (e.g. bash)", text: $viewModel.newRulePattern)
                        .textFieldStyle(.roundedBorder)

                    Picker("", selection: $viewModel.newRuleDecision) {
                        Text("Allow").tag(PermissionDecision.allow)
                        Text("Deny").tag(PermissionDecision.deny)
                    }
                    .frame(width: 100)

                    Button("Add") {
                        viewModel.addRule()
                    }
                    .disabled(viewModel.newRulePattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                HStack {
                    Text("Rules")
                        .font(.headline)
                    Spacer()
                    if !viewModel.rules.isEmpty {
                        Button("Remove All", role: .destructive) {
                            viewModel.removeAllRules()
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 300)
        .onAppear {
            Self.logger.info("[PermissionSettingsView] appeared")
        }
    }
}
