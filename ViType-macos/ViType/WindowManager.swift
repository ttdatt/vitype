//
//  WindowManager.swift
//  ViType
//
//  Created by Tran Dat on 27/12/25.
//

import SwiftUI

/// Singleton that bridges AppKit (AppDelegate/MenuBarManager) with SwiftUI's window management.
/// This allows us to open SwiftUI windows from anywhere in the app.
final class WindowManager {
    static let shared = WindowManager()
    
    private var openWindowAction: OpenWindowAction?
    
    private init() {}
    
    /// Called from SwiftUI to inject the openWindow environment action
    @MainActor
    func setOpenWindowAction(_ action: OpenWindowAction) {
        self.openWindowAction = action
    }
    
    /// Opens the settings window. Can be called from AppDelegate or MenuBarManager.
    @MainActor
    func openSettings() {
        openWindowAction?(id: "settings")
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
