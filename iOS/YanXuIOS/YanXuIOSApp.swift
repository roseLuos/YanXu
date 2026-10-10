import SwiftUI

@main
struct YanXuIOSApp: App {
    @StateObject private var store = MobileAppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.synchronizeWithMacIfConfigured() }
                }
        }
    }
}
