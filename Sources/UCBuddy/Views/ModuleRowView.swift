import SwiftUI

struct ModuleRowView<Settings: View>: View {
    let module: any QoLModule
    @ViewBuilder var settings: () -> Settings

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: module.iconSystemName)
                    .frame(width: 16)
                    .foregroundStyle(module.isEnabled ? .primary : .secondary)

                Text(module.displayName)
                    .font(.system(.body, weight: .medium))

                Spacer()

                if module.isEnabled {
                    StatusIndicator(status: module.status)
                }

                Toggle("", isOn: Binding(
                    get: { module.isEnabled },
                    set: { module.isEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }

            if module.isEnabled {
                statusText

                if expanded {
                    settings()
                        .padding(.leading, 24)
                        .padding(.top, 4)
                }

                Button(expanded ? "Less" : "Settings") {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusText: some View {
        switch module.status {
        case .idle:
            EmptyView()
        case .running(let detail):
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 24)
        case .warning(let detail):
            Text(detail)
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.leading, 24)
        case .error(let detail):
            Text(detail)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.leading, 24)
        }
    }
}
