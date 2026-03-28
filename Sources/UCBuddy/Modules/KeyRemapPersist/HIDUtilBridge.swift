import Foundation
import OSLog

struct HIDUtilBridge: Sendable {
    private let shell = ShellExecutor.shared

    func apply(_ json: String) async throws {
        Logger.keyremap.info("hidutil set: \(json, privacy: .public)")
        _ = try await shell.cmd("hidutil", arguments: ["property", "--set", json])
    }

    func readCurrentHidutil() async -> String {
        (try? await shell.cmd("hidutil", arguments: ["property", "--get", "UserKeyMapping"])) ?? "(null)"
    }
}
