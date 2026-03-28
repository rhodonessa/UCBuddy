import Foundation

enum ModuleStatus: Equatable, Sendable {
    case idle
    case running(String)
    case warning(String)
    case error(String)

    var isHealthy: Bool {
        switch self {
        case .running: true
        default: false
        }
    }
}

@MainActor
protocol QoLModule: AnyObject, Observable, Identifiable {
    var id: String { get }
    var displayName: String { get }
    var iconSystemName: String { get }
    var isEnabled: Bool { get set }
    var enabledByDefault: Bool { get }
    var status: ModuleStatus { get }

    func start() async
    func stop() async
}
