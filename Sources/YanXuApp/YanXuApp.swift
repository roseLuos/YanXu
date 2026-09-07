import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: AppStore?

    func configure(store: AppStore) {
        self.store = store
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        let capturePath = ProcessInfo.processInfo.environment["YANXU_CAPTURE_PATH"]
#else
        let capturePath: String? = nil
#endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let window = NSApplication.shared.windows.first(where: { ($0.contentView?.bounds.width ?? 0) > 800 }),
                  let visibleFrame = window.screen?.visibleFrame else { return }
            window.setFrame(visibleFrame, display: true, animate: false)
        }

        if let store {
            ResearchIslandCoordinator.shared.show(store: store)
        }

#if DEBUG
        guard let capturePath else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let capturesEditor = ProcessInfo.processInfo.environment["YANXU_PREVIEW_TASK_EDITOR"] == "1"
            let previewPanel = ProcessInfo.processInfo.environment["YANXU_PREVIEW_PANEL"]
            let capturesCalendarSync = previewPanel == "calendar-sync"
            let capturesPanel = previewPanel != nil
            let window = NSApplication.shared.windows.first { window in
                let width = window.contentView?.bounds.width ?? 0
                if capturesEditor { return width >= 400 && width < 800 }
                if capturesCalendarSync { return width >= 500 && width < 700 }
                if capturesPanel { return width >= 900 && width < 1_600 }
                return width > 800
            }

            guard let window,
                  let contentView = window.contentView,
                  let bitmap = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
                NSApplication.shared.terminate(nil)
                return
            }

            window.displayIfNeeded()
            contentView.cacheDisplay(in: contentView.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: capturePath))
            }
            NSApplication.shared.terminate(nil)
        }
#endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        ResearchIslandCoordinator.shared.hide()
    }
}

@main
struct YanXuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AppStore

    init() {
#if DEBUG
        let dataPath = ProcessInfo.processInfo.environment["YANXU_DATA_PATH"]
        let dataURL = dataPath.map { URL(fileURLWithPath: $0) }
        let initialStore = AppStore(fileURL: dataURL)
#else
        let initialStore = AppStore()
#endif
        _store = StateObject(wrappedValue: initialStore)
        appDelegate.configure(store: initialStore)
    }

    var body: some Scene {
        WindowGroup("研序") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1080, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 860)
    }
}
