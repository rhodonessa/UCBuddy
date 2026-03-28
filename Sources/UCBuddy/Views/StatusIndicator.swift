import SwiftUI

struct StatusIndicator: View {
    let status: ModuleStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private var color: Color {
        switch status {
        case .idle: .secondary
        case .running: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
