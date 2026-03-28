import Foundation
import Testing
@testable import UCBuddy

@Suite("ConnectionGuardian")
struct ConnectionGuardianTests {
    @Test("UCConnectionStatus descriptions")
    func statusDescriptions() {
        #expect(UCConnectionStatus.connected(peerCount: 1).description == "1 peer connected")
        #expect(UCConnectionStatus.connected(peerCount: 2).description == "2 peers connected")
        #expect(UCConnectionStatus.disconnected.description == "Disconnected")
        #expect(UCConnectionStatus.unknown.description == "Unknown")
    }

    @Test("RestartMode has expected cases")
    func restartModes() {
        let cases = RestartMode.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.autoRestart))
        #expect(cases.contains(.notifyOnly))
    }

    @Test("ModuleStatus isHealthy")
    func moduleStatusHealth() {
        #expect(!ModuleStatus.idle.isHealthy)
        #expect(ModuleStatus.running("ok").isHealthy)
        #expect(!ModuleStatus.warning("warn").isHealthy)
        #expect(!ModuleStatus.error("err").isHealthy)
    }
}
