import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: AppStore?
    private weak var mainWindow: NSWindow?

    func configure(store: AppStore) {
        self.store = store
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        let capturePath = ProcessInfo.processInfo.environment["YANXU_CAPTURE_PATH"]
        let reopenTestPath = ProcessInfo.processInfo.environment["YANXU_REOPEN_TEST_PATH"]
#else
        let capturePath: String? = nil
#endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self,
                  let window = self.findMainWindow(in: NSApplication.shared),
                  let visibleFrame = window.screen?.visibleFrame else { return }
            self.mainWindow = window
            window.isReleasedWhenClosed = false
            window.setFrame(visibleFrame, display: true, animate: false)
#if DEBUG
            if let reopenTestPath {
                self.verifyWindowReopen(window: window, resultPath: reopenTestPath)
            }
#endif
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

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard let window = mainWindow ?? findMainWindow(in: sender) else {
            return true
        }

        mainWindow = window
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        sender.activate()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        DispatchQueue.main.async {
            sender.activate()
            window.makeKeyAndOrderFront(nil)
        }
        return false
    }

    private func findMainWindow(in application: NSApplication) -> NSWindow? {
        application.windows.first {
            !$0.isExcludedFromWindowsMenu
                && $0.styleMask.contains(.titled)
                && ($0.contentView?.bounds.width ?? 0) > 800
        }
    }

#if DEBUG
    private func verifyWindowReopen(window: NSWindow, resultPath: String) {
        window.performClose(nil)
        let closedBeforeReopen = !window.isVisible
        let handledByDelegate = !applicationShouldHandleReopen(
            NSApplication.shared,
            hasVisibleWindows: false
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let result: [String: Bool] = [
                "appActive": NSApplication.shared.isActive,
                "closedBeforeReopen": closedBeforeReopen,
                "handledByDelegate": handledByDelegate,
                "mainWindowVisible": window.isVisible,
                "mainWindowKey": window.isKeyWindow
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]) {
                try? data.write(to: URL(fileURLWithPath: resultPath))
            }
            NSApplication.shared.terminate(nil)
        }
    }
#endif
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
