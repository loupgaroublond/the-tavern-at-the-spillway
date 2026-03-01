import SwiftUI
import TavernKit
import os.log

struct PermissionSettingsTileView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "permissions")

    @Bindable var tile: PermissionSettingsTile

    var body: some View {
        let _ = Self.logger.debug("[PermissionSettingsTileView] body - mode: \(tile.currentMode.rawValue), rules: \(tile.rules.count)")

        VStack(alignment: .leading, spacing: 16) {
            Section {
                Picker("Permission Mode", selection: $tile.currentMode) {
                    ForEach(PermissionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(tile.currentMode.modeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Mode")
                    .font(.headline)
            }

            Divider()

            Section {
                if tile.rules.isEmpty {
                    Text("No permission rules configured.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    List {
                        ForEach(tile.rules) { rule in
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
                                    tile.removeRule(id: rule.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .frame(minHeight: 100)
                }

                HStack {
                    TextField("Tool pattern (e.g. bash)", text: $tile.newRulePattern)
                        .textFieldStyle(.roundedBorder)

                    Picker("", selection: $tile.newRuleDecision) {
                        Text("Allow").tag(PermissionDecisionInfo.allow)
                        Text("Deny").tag(PermissionDecisionInfo.deny)
                    }
                    .frame(width: 100)

                    Button("Add") {
                        tile.addRule()
                    }
                    .disabled(tile.newRulePattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                HStack {
                    Text("Rules")
                        .font(.headline)
                    Spacer()
                    if !tile.rules.isEmpty {
                        Button("Remove All", role: .destructive) {
                            tile.removeAllRules()
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 300)
        .onAppear {
            Self.logger.info("[PermissionSettingsTileView] onAppear - mode: \(tile.currentMode.rawValue), rules: \(tile.rules.count)")
        }
        .onDisappear {
            Self.logger.debug("[PermissionSettingsTileView] onDisappear")
        }
        .onChange(of: tile.currentMode) {
            Self.logger.info("[PermissionSettingsTileView] currentMode changed: \(tile.currentMode.rawValue)")
            tile.syncModeToProvider()
        }
    }
}

// MARK: - Preview

#Preview("Permission Settings") {
    VStack(alignment: .leading, spacing: 16) {
        Section {
            Picker("Permission Mode", selection: .constant(PermissionMode.normal)) {
                ForEach(PermissionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(PermissionMode.normal.modeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Mode").font(.headline)
        }

        Divider()

        Section {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading) {
                    Text("bash").font(.body.monospaced())
                    Text("Allow shell commands").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("Allow").font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                TextField("Tool pattern (e.g. bash)", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: .constant(PermissionDecisionInfo.allow)) {
                    Text("Allow").tag(PermissionDecisionInfo.allow)
                    Text("Deny").tag(PermissionDecisionInfo.deny)
                }
                .frame(width: 100)
                Button("Add") {}
                    .disabled(true)
            }
        } header: {
            Text("Rules").font(.headline)
        }
    }
    .padding()
    .frame(width: 500, height: 300)
}
