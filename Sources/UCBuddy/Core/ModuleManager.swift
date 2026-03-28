import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ModuleManager {
    let connectionGuardian = ConnectionGuardian()
    let keyRemapPersist = KeyRemapPersist()

    var modules: [any QoLModule] { [connectionGuardian, keyRemapPersist] }

    var menuBarIcon: String {
        let enabled = modules.filter(\.isEnabled)
        if enabled.isEmpty { return "link" }
        if enabled.contains(where: { if case .error = $0.status { return true }; return false }) {
            return "exclamationmark.triangle"
        }
        if enabled.contains(where: { if case .warning = $0.status { return true }; return false }) {
            return "link.badge.plus"
        }
        return "link.circle"
    }

    private var hasStarted = false

    init() {
        keyRemapPersist.connectionGuardian = connectionGuardian
        Logger.app.info("ModuleManager initialized with \(self.modules.count) modules")
    }

    /// Idempotent - safe to call from SwiftUI .task which may fire multiple times.
    func startOnce() async {
        guard !hasStarted else {
            Logger.app.debug("startOnce: already started, skipping")
            return
        }
        hasStarted = true
        OldLaunchAgentCleaner.removeIfNeeded()
        await startEnabledModules()
    }

    private func startEnabledModules() async {
        for module in modules where module.isEnabled {
            Logger.app.info("Starting module: \(module.id)")
            await module.start()
            Logger.app.info("Module \(module.id) started, status: \(String(describing: module.status))")
        }
    }

    func stopAllModules() async {
        for module in modules {
            Logger.app.info("Stopping module: \(module.id)")
            await module.stop()
        }
    }
}
