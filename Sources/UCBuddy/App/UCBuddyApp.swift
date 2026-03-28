import SwiftUI
import OSLog

@main
struct UCBuddyApp: App {
    @State private var moduleManager = ModuleManager()

    init() {
        Logger.app.info("UCBuddy launching")
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(moduleManager: moduleManager)
        } label: {
            Label("UCBuddy", systemImage: moduleManager.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
