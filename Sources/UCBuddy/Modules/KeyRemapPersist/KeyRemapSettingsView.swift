import SwiftUI

struct KeyRemapSettingsView: View {
    @Bindable var module: KeyRemapPersist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if module.mappingJSON.isEmpty {
                Text("Do your modifier keys (Ctrl, Cmd, etc.) keep resetting to defaults on this machine when using Universal Control?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("First, set up your modifier keys the way you want them in System Settings > Keyboard > Modifier Keys. Then come back here and capture that config.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Capture current modifier key setup") {
                    Task { await module.captureCurrentMapping() }
                }
                .controlSize(.small)
            } else {
                Text("Your modifier key config is saved. UCBuddy will re-apply it every 30 seconds, but only while Universal Control is connected. When you're using this machine standalone, it won't touch anything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Re-capture") {
                        Task { await module.captureCurrentMapping() }
                    }
                    .controlSize(.small)

                    Button("Clear saved config") {
                        module.clearMapping()
                    }
                    .controlSize(.small)
                    .foregroundStyle(.red)
                }
            }
        }
    }
}
