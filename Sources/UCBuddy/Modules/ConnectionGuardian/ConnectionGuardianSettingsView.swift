import SwiftUI

struct ConnectionGuardianSettingsView: View {
    @Bindable var module: ConnectionGuardian

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Mode", selection: $module.restartMode) {
                ForEach(RestartMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Check every")
                TextField("", value: $module.checkInterval, format: .number)
                    .frame(width: 40)
                    .textFieldStyle(.roundedBorder)
                Text("sec")
            }
            .font(.caption)

            HStack {
                Text("Grace period")
                TextField("", value: $module.gracePeriod, format: .number)
                    .frame(width: 40)
                    .textFieldStyle(.roundedBorder)
                Text("sec")
            }
            .font(.caption)
        }
    }
}
