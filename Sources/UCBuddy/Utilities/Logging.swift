import OSLog
import Foundation

extension Logger {
    static let app = Logger(subsystem: "com.ucbuddy", category: "app")
    static let connection = Logger(subsystem: "com.ucbuddy", category: "connection")
    static let keyremap = Logger(subsystem: "com.ucbuddy", category: "keyremap")
    static let shell = Logger(subsystem: "com.ucbuddy", category: "shell")
}

enum DiagnosticLog {
    static func collect(seconds: Int = 300) async -> String {
        let shell = ShellExecutor.shared
        do {
            let output = try await shell.cmd("log", arguments: [
                "show",
                "--predicate", "subsystem == \"com.ucbuddy\"",
                "--last", "\(seconds)s",
                "--style", "compact"
            ], timeout: .seconds(15))
            return output.isEmpty ? "(no log entries in the last \(seconds)s)" : output
        } catch {
            return "(failed to collect logs: \(error))"
        }
    }
}
