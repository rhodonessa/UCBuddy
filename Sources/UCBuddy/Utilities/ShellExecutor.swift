import Foundation
import OSLog

enum ShellError: Error, LocalizedError {
    case nonZeroExit(Int32, stderr: String)
    case timeout(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let code, let stderr):
            "Exit code \(code): \(stderr)"
        case .timeout(let cmd):
            "Timed out: \(cmd)"
        case .launchFailed(let reason):
            "Launch failed: \(reason)"
        }
    }
}

struct ShellExecutor: Sendable {
    static let shared = ShellExecutor()

    private static let knownPaths: [String: String] = [
        "pgrep": "/usr/bin/pgrep",
        "lsof": "/usr/sbin/lsof",
        "hidutil": "/usr/bin/hidutil",
        "killall": "/usr/bin/killall",
        "defaults": "/usr/bin/defaults",
        "log": "/usr/bin/log",
        "launchctl": "/bin/launchctl",
    ]

    /// Run a process using fully non-blocking APIs.
    ///
    /// Uses `terminationHandler` (GCD) + `DispatchSource` timer for timeout.
    /// Zero blocking calls on the Swift cooperative thread pool.
    /// Handles external task cancellation cleanly (terminates process, resumes continuation).
    func run(_ executable: String, arguments: [String] = [], timeout: Duration = .seconds(10)) async throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let cmdDesc = ([executable] + arguments).joined(separator: " ")

        do {
            try process.run()
        } catch {
            Logger.shell.error("Launch failed: \(cmdDesc, privacy: .public) - \(error.localizedDescription, privacy: .public)")
            throw ShellError.launchFailed("\(cmdDesc): \(error.localizedDescription)")
        }

        let timeoutSeconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18

        // OSAllocatedUnfairLock guards against double-resume:
        // terminationHandler, timeout timer, and onCancel can all race.
        let resumed = OSAllocatedUnfairLock(initialState: false)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in

                // Timeout via GCD timer - no cooperative pool thread blocked
                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + timeoutSeconds)
                timer.setEventHandler {
                    let alreadyResumed = resumed.withLock { val in let v = val; val = true; return v }
                    guard !alreadyResumed else { return }
                    process.terminate()
                    Logger.shell.error("Timeout: \(cmdDesc, privacy: .public)")
                    continuation.resume(throwing: ShellError.timeout(cmdDesc))
                }
                timer.resume()

                // Process completion - fires on GCD, not cooperative pool
                process.terminationHandler = { proc in
                    timer.cancel()
                    let alreadyResumed = resumed.withLock { val in let v = val; val = true; return v }
                    guard !alreadyResumed else { return }

                    let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    if proc.terminationStatus == 0 {
                        let output = String(data: outData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        continuation.resume(returning: output)
                    } else {
                        let errStr = String(data: errData, encoding: .utf8) ?? ""
                        Logger.shell.debug("Exit \(proc.terminationStatus, privacy: .public): \(cmdDesc, privacy: .public) - \(errStr, privacy: .public)")
                        continuation.resume(throwing: ShellError.nonZeroExit(proc.terminationStatus, stderr: errStr))
                    }
                }
            }
        } onCancel: {
            // Parent task cancelled (e.g. SwiftUI .task lifecycle restart).
            // Terminate the process - terminationHandler will resume the continuation.
            process.terminate()
        }
    }

    func cmd(_ name: String, arguments: [String] = [], timeout: Duration = .seconds(10)) async throws -> String {
        let path = Self.knownPaths[name] ?? "/usr/bin/\(name)"
        return try await run(path, arguments: arguments, timeout: timeout)
    }

    func fire(_ name: String, arguments: [String] = []) async {
        _ = try? await cmd(name, arguments: arguments)
    }
}
