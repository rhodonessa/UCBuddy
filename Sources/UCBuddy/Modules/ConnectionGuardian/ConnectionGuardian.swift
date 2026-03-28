import Foundation
import Observation
import OSLog
@preconcurrency import UserNotifications

enum RestartMode: String, CaseIterable, Identifiable, Codable {
    case autoRestart = "Auto-restart"
    case notifyOnly = "Notify only"
    var id: String { rawValue }
}

@MainActor
@Observable
final class ConnectionGuardian: QoLModule, Identifiable {
    let id = "connectionGuardian"
    let displayName = "Connection Guardian"
    let iconSystemName = "wifi.circle"
    let enabledByDefault = true


    var isEnabled: Bool = UserDefaults.standard.object(forKey: "cg.enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "cg.enabled")
            Logger.connection.info("ConnectionGuardian enabled: \(self.isEnabled)")
            Task {
                if isEnabled { await start() } else { await stop() }
            }
        }
    }

    var status: ModuleStatus = .idle {
        didSet {
            Logger.connection.info("ConnectionGuardian status: \(String(describing: self.status))")
        }
    }
    var connectionStatus: UCConnectionStatus = .unknown

    var checkInterval: TimeInterval = UserDefaults.standard.double(forKey: "cg.interval").clamped(5...60, default: 10) {
        didSet { UserDefaults.standard.set(checkInterval, forKey: "cg.interval") }
    }
    var gracePeriod: TimeInterval = UserDefaults.standard.double(forKey: "cg.grace").clamped(10...120, default: 30) {
        didSet { UserDefaults.standard.set(gracePeriod, forKey: "cg.grace") }
    }
    var restartMode: RestartMode = RestartMode(rawValue: UserDefaults.standard.string(forKey: "cg.mode") ?? "") ?? .autoRestart {
        didSet { UserDefaults.standard.set(restartMode.rawValue, forKey: "cg.mode") }
    }

    private let monitor = UCProcessMonitor()
    private var monitorTask: Task<Void, Never>?
    private var consecutiveDisconnects = 0
    private var inGracePeriod = false

    func start() async {
        monitorTask?.cancel()
        status = .running("Monitoring")
        consecutiveDisconnects = 0
        inGracePeriod = false
        Logger.connection.info("ConnectionGuardian starting, interval=\(self.checkInterval)s, grace=\(self.gracePeriod)s, mode=\(self.restartMode.rawValue)")

        monitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.tick()
                try? await Task.sleep(for: .seconds(self.checkInterval))
            }
        }
    }

    func stop() async {
        monitorTask?.cancel()
        monitorTask = nil
        status = .idle
        connectionStatus = .unknown
        Logger.connection.info("ConnectionGuardian stopped")
    }

    private func tick() async {
        let newStatus = await monitor.checkConnections()
        let oldStatus = connectionStatus
        connectionStatus = newStatus

        if oldStatus != newStatus {
            Logger.connection.info("UC status changed: \(String(describing: oldStatus)) → \(String(describing: newStatus))")
        }

        switch newStatus {
        case .connected:
            consecutiveDisconnects = 0
            inGracePeriod = false
            status = .running(newStatus.description)

        case .disconnected:
            guard !inGracePeriod else {
                status = .warning("Restarted, waiting...")
                return
            }
            consecutiveDisconnects += 1
            Logger.connection.info("Consecutive disconnects: \(self.consecutiveDisconnects)")
            if consecutiveDisconnects == 2 {
                // First try: soft nudge (poke mDNS, like opening Displays)
                status = .warning("Connection lost, nudging...")
                if restartMode == .autoRestart {
                    Logger.connection.info("Trying soft nudge first")
                    await monitor.softNudge()
                }
            } else if consecutiveDisconnects >= 3 {
                // Second try: hard restart
                status = .warning("Connection lost")
                if restartMode == .autoRestart {
                    Logger.connection.info("Soft nudge didn't work, hard restarting UC")
                    await monitor.restart()
                    inGracePeriod = true
                    consecutiveDisconnects = 0
                    Task { [weak self] in
                        try? await Task.sleep(for: .seconds(self?.gracePeriod ?? 30))
                        await MainActor.run { self?.inGracePeriod = false }
                    }
                } else {
                    Logger.connection.warning("UC disconnected - notify-only mode")
                    await sendDisconnectNotification()
                }
            }

        case .unknown:
            status = .warning("UC not running")
        }
    }

    private func sendDisconnectNotification() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            Logger.connection.info("Requesting notification permission")
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }

        let content = UNMutableNotificationContent()
        content.title = "Universal Control Disconnected"
        content.body = "The UC connection dropped. Open UCBuddy to restart it."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "uc-disconnect-\(Date.now.timeIntervalSince1970)",
                                            content: content, trigger: nil)
        try? await center.add(request)
    }
}

private extension Double {
    func clamped(_ range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        if self == 0 { return defaultValue }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
