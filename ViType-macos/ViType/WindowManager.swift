//
//  WindowManager.swift
//  ViType
//
//  Created by Tran Dat on 27/12/25.
//

import Cocoa
import SwiftUI

/// Singleton that bridges AppKit (AppDelegate/MenuBarManager) with SwiftUI's window management.
/// This allows us to open SwiftUI windows from anywhere in the app.
final class WindowManager {
    static let shared = WindowManager()

    private static let settingsWindowIdentifier = NSUserInterfaceItemIdentifier("vitype.settings")
    
    private var openWindowAction: OpenWindowAction?
    private weak var settingsWindow: NSWindow?
    private var settingsWindowCloseObserver: NSObjectProtocol?
    
    private init() {}
    
    /// Called from SwiftUI to inject the openWindow environment action
    @MainActor
    func setOpenWindowAction(_ action: OpenWindowAction) {
        self.openWindowAction = action
    }
    
    /// Opens the settings window. Can be called from AppDelegate or MenuBarManager.
    /// Always returns an NSWindow (SwiftUI window when available; otherwise AppKit fallback).
    @MainActor
    @discardableResult
    func openSettings() async -> NSWindow {
        if let existing = findSettingsWindow() {
            present(existing)
            return existing
        }

        if let openWindowAction {
            openWindowAction(id: "settings")

            if let created = await waitForSettingsWindow(timeoutSeconds: 1.0) {
                settingsWindow = created
                startObservingSettingsWindowClose(created)
                present(created)
                return created
            }
        }

        let fallback = openSettingsViaAppKitFallback()
        present(fallback)
        return fallback
    }

    @MainActor
    private func findSettingsWindow() -> NSWindow? {
        if let settingsWindow {
            return settingsWindow
        }

        // Best-effort: SwiftUI-created window should be among NSApp.windows.
        // Filter out status bar panels and transient panels.
        let candidates = NSApp.windows.filter { window in
            if window is NSPanel { return false }
            if window.className.contains("StatusBar") { return false }
            if window.level == .statusBar { return false }
            // Avoid grabbing transient windows such as status-item menus.
            if !window.styleMask.contains(.titled) { return false }

            if window.identifier == Self.settingsWindowIdentifier { return true }
            if window.title.localizedCaseInsensitiveContains("ViType") { return true }

            return false
        }

        // Prefer visible windows, then those with "ViType" in the title.
        let sorted = candidates.sorted { lhs, rhs in
            if lhs.isVisible != rhs.isVisible { return lhs.isVisible }
            let lhsScore = lhs.title.localizedCaseInsensitiveContains("ViType") ? 1 : 0
            let rhsScore = rhs.title.localizedCaseInsensitiveContains("ViType") ? 1 : 0
            return lhsScore > rhsScore
        }

        if let found = sorted.first {
            if found.identifier == nil {
                found.identifier = Self.settingsWindowIdentifier
            }
            settingsWindow = found
            startObservingSettingsWindowClose(found)
            return found
        }

        return nil
    }

    @MainActor
    private func waitForSettingsWindow(timeoutSeconds: TimeInterval) async -> NSWindow? {
        let start = Date()
        while Date().timeIntervalSince(start) < timeoutSeconds {
            if let found = findSettingsWindow() {
                return found
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        return nil
    }

    @MainActor
    private func openSettingsViaAppKitFallback() -> NSWindow {
        let hostingController = NSHostingController(rootView: ContentView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = "ViType Settings".localized()
        window.identifier = Self.settingsWindowIdentifier
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 440, height: 560))
        window.center()
        window.makeKeyAndOrderFront(nil)

        settingsWindow = window
        startObservingSettingsWindowClose(window)

        return window
    }

    @MainActor
    private func present(_ window: NSWindow) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @MainActor
    private func startObservingSettingsWindowClose(_ window: NSWindow) {
        if let settingsWindowCloseObserver {
            NotificationCenter.default.removeObserver(settingsWindowCloseObserver)
        }

        settingsWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
            if let observer = self?.settingsWindowCloseObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            self?.settingsWindowCloseObserver = nil
        }
    }
}

/// A SwiftUI view modifier that injects the openWindow action into WindowManager
struct WindowManagerInjector: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                WindowManager.shared.setOpenWindowAction(openWindow)
            }
    }
}

extension View {
    func injectWindowManager() -> some View {
        modifier(WindowManagerInjector())
    }
}
