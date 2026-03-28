import Foundation
import OSLog

actor UCProcessMonitor {
    private let shell = ShellExecutor.shared

    func findPID() async -> Int32? {
        guard let output = try? await shell.cmd("pgrep", arguments: ["-x", "UniversalControl"]) else {
            Logger.connection.debug("pgrep: UniversalControl not found")
            return nil
        }
        let pid = Int32(output.components(separatedBy: "\n").first ?? "")
        Logger.connection.debug("UC PID: \(pid ?? -1, privacy: .public)")
        return pid
    }

    func checkConnections() async -> UCConnectionStatus {
        guard let pid = await findPID() else {
            return .unknown
        }

        guard let output = try? await shell.cmd("lsof", arguments: ["-a", "-i", "-p", "\(pid)"]) else {
            Logger.connection.warning("lsof failed for PID \(pid, privacy: .public)")
            return .unknown
        }

        let lines = output.components(separatedBy: "\n")
        let established = lines.filter { $0.contains("ESTABLISHED") }.count

        Logger.connection.debug("lsof: \(lines.count, privacy: .public) lines, \(established, privacy: .public) ESTABLISHED")

        if established > 0 {
            let estimatedPeers = max(1, established / 4)
            return .connected(peerCount: estimatedPeers)
        }

        return .disconnected
    }

    /// Soft nudge: browse mDNS for AirPlay services for 2 seconds.
    /// This is what opening Displays in System Settings does internally -
    /// it pokes the Bonjour discovery layer which often wakes UC back up.
    func softNudge() async {
        Logger.connection.info("Soft nudge: poking mDNS discovery")
        // dns-sd -B browses for services. Run for 2s then kill.
        _ = try? await shell.cmd("dns-sd", arguments: ["-B", "_airplay._tcp", "local."], timeout: .seconds(2))
        // The timeout will terminate dns-sd (it runs forever otherwise). That's fine.
    }

    /// Hard restart: kill UniversalControl (it auto-relaunches via launchd).
    func restart() async {
        Logger.connection.info("Hard restart: killall UniversalControl")
        await shell.fire("killall", arguments: ["UniversalControl"])
    }
}
