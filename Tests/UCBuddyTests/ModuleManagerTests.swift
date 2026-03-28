import Foundation
import Testing
@testable import UCBuddy

@Suite("ModuleManager")
struct ModuleManagerTests {
    @MainActor
    @Test("ModuleManager has active modules")
    func modulesRegistered() {
        let manager = ModuleManager()
        #expect(manager.modules.count == 2)
        let ids = manager.modules.map(\.id)
        #expect(ids.contains("connectionGuardian"))
        #expect(ids.contains("keyRemapPersist"))
    }

    @MainActor
    @Test("Menu bar icon defaults to connected icon")
    func defaultIcon() {
        let manager = ModuleManager()
        // With modules enabled but idle, should show base icon
        #expect(manager.menuBarIcon == "link.circle")
    }
}
