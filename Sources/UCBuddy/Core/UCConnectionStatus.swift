import Foundation

enum UCConnectionStatus: Equatable, Sendable {
    case connected(peerCount: Int)
    case disconnected
    case unknown

    var description: String {
        switch self {
        case .connected(let count): "\(count) peer\(count == 1 ? "" : "s") connected"
        case .disconnected: "Disconnected"
        case .unknown: "Unknown"
        }
    }
}
