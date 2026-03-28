import SwiftUI
import ServiceManagement
import OSLog

struct MenuBarView: View {
    @Bindable var moduleManager: ModuleManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showDebugLog = false
    @State private var debugLogText = ""
    @State private var debugLogLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("UCBuddy")
                    .font(.headline)
                Spacer()
                Text("v0.1")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Modules
            VStack(spacing: 0) {
                ModuleRowView(module: moduleManager.connectionGuardian) {
                    ConnectionGuardianSettingsView(module: moduleManager.connectionGuardian)
                }

                Divider().padding(.vertical, 2)

                ModuleRowView(module: moduleManager.keyRemapPersist) {
                    KeyRemapSettingsView(module: moduleManager.keyRemapPersist)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Debug log panel
            if showDebugLog {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Debug Log (last 5 min)")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        if debugLogLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(debugLogText, forType: .string)
                        }
                        .font(.caption)
                        .controlSize(.small)
                        .disabled(debugLogText.isEmpty)

                        Button("Refresh") {
                            Task { await loadDebugLog() }
                        }
                        .font(.caption)
                        .controlSize(.small)
                    }

                    ScrollView {
                        Text(debugLogText.isEmpty ? "Loading..." : debugLogText)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .task { await loadDebugLog() }

                Divider()
            }

            // Footer
            HStack {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            Logger.app.error("SMAppService toggle failed: \(error)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }

                Spacer()

                Button(showDebugLog ? "Hide Log" : "Debug") {
                    withAnimation { showDebugLog.toggle() }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                Button("Quit") {
                    Task {
                        await moduleManager.stopAllModules()
                        NSApplication.shared.terminate(nil)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 380)
        .task {
            await moduleManager.startOnce()
        }
    }

    private func loadDebugLog() async {
        debugLogLoading = true
        debugLogText = await DiagnosticLog.collect(seconds: 300)
        debugLogLoading = false
    }
}

/// Removes the old com.local.KeyRemapping LaunchAgent that UCBuddy now replaces.
enum OldLaunchAgentCleaner {
    private static let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/com.local.KeyRemapping.plist"
    private static let cleanedKey = "ucbuddy.oldLaunchAgentCleaned"

    static func removeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: cleanedKey) else { return }
        guard FileManager.default.fileExists(atPath: plistPath) else {
            UserDefaults.standard.set(true, forKey: cleanedKey)
            return
        }

        Logger.app.info("Removing old LaunchAgent: \(plistPath)")

        let process = Process()
        process.executableURL = URL(filePath: "/bin/launchctl")
        process.arguments = ["unload", plistPath]
        try? process.run()
        process.waitUntilExit()

        try? FileManager.default.removeItem(atPath: plistPath)
        UserDefaults.standard.set(true, forKey: cleanedKey)
        Logger.app.info("Old LaunchAgent removed")
    }
}
