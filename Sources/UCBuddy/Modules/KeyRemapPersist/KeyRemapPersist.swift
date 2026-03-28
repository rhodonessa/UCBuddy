import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class KeyRemapPersist: QoLModule, Identifiable {
    let id = "keyRemapPersist"
    let displayName = "Key Remap Persist"
    let iconSystemName = "keyboard"
    let enabledByDefault = false  // Off by default - user opts in

    var isEnabled: Bool = UserDefaults.standard.object(forKey: "kr.enabled") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "kr.enabled")
            Task { if isEnabled { await start() } else { await stop() } }
        }
    }

    var status: ModuleStatus = .idle

    /// The hidutil JSON string to re-apply. Captured from current state
    /// when the user opts in, or set manually.
    var mappingJSON: String = UserDefaults.standard.string(forKey: "kr.json") ?? ""

    /// Reference to ConnectionGuardian so we only enforce while UC is connected.
    var connectionGuardian: ConnectionGuardian?

    private let bridge = HIDUtilBridge()
    private var monitorTask: Task<Void, Never>?

    func start() async {
        Logger.keyremap.info("KeyRemapPersist starting")

        if mappingJSON.isEmpty {
            status = .running("Waiting for setup")
            Logger.keyremap.info("No mapping captured yet - user needs to set up via Settings")
            return
        }

        status = .running("Active")
        startMonitor()
    }

    func stop() async {
        monitorTask?.cancel()
        monitorTask = nil
        status = .idle
    }

    /// Capture the current hidutil state as the "desired" mapping.
    /// Called when user clicks "Capture current mapping" in settings.
    func captureCurrentMapping() async {
        let current = await bridge.readCurrentHidutil()
        guard current != "(null)" && current.contains("HIDKeyboardModifierMapping") else {
            Logger.keyremap.warning("Nothing to capture - hidutil has no mappings")
            return
        }

        let pairs = parseHidutilOutput(current)
        guard !pairs.isEmpty else { return }

        mappingJSON = buildJSON(pairs)
        UserDefaults.standard.set(mappingJSON, forKey: "kr.json")
        Logger.keyremap.info("Captured: \(self.mappingJSON, privacy: .public)")
        status = .running("Active")
        startMonitor()
    }

    func clearMapping() {
        mappingJSON = ""
        UserDefaults.standard.removeObject(forKey: "kr.json")
        monitorTask?.cancel()
        monitorTask = nil
        status = .running("Waiting for setup")
    }

    /// Every 30s, check if UC is connected. If yes, re-apply the mapping.
    /// If UC is not connected, don't touch anything - let the machine
    /// work standalone without interference.
    private func startMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, self.isEnabled, !self.mappingJSON.isEmpty else { continue }
                guard !Task.isCancelled else { return }

                // Only enforce while UC is actually connected
                if let cg = self.connectionGuardian {
                    guard case .connected = cg.connectionStatus else {
                        Logger.keyremap.debug("UC not connected, skipping re-apply")
                        continue
                    }
                }

                await self.applyMapping()
            }
        }
    }

    private func applyMapping() async {
        guard !Task.isCancelled else { return }
        do {
            try await bridge.apply(mappingJSON)
        } catch is CancellationError {
            return
        } catch {
            Logger.keyremap.error("Failed to apply: \(error)")
            status = .error("Failed to apply")
        }
    }

    // MARK: - Parsing

    private func parseHidutilOutput(_ output: String) -> [(src: UInt64, dst: UInt64)] {
        var pairs: [(UInt64, UInt64)] = []
        var currentSrc: UInt64?
        var currentDst: UInt64?
        for line in output.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("HIDKeyboardModifierMappingSrc") { currentSrc = extractDecimal(t) }
            else if t.hasPrefix("HIDKeyboardModifierMappingDst") { currentDst = extractDecimal(t) }
            if t.hasPrefix("}") {
                if let s = currentSrc, let d = currentDst { pairs.append((s, d)) }
                currentSrc = nil; currentDst = nil
            }
        }
        return pairs
    }

    private func buildJSON(_ pairs: [(src: UInt64, dst: UInt64)]) -> String {
        let entries = pairs.map {
            "{\"HIDKeyboardModifierMappingSrc\":\($0.src),\"HIDKeyboardModifierMappingDst\":\($0.dst)}"
        }.joined(separator: ",")
        return "{\"UserKeyMapping\":[\(entries)]}"
    }

    private func extractDecimal(_ line: String) -> UInt64? {
        let parts = line.components(separatedBy: "=")
        guard parts.count == 2 else { return nil }
        return UInt64(parts[1].trimmingCharacters(in: CharacterSet.decimalDigits.inverted))
    }
}
