//
//  AppDelegate.swift
//  ViType
//
//  Created by Tran Dat on 24/12/25.
//
//  Simplified for IMK — no more CGEvent tap, no more character injection.
//

import Cocoa

// Shared notification names
extension Notification.Name {
    static let showSettingsWindow = Notification.Name("showSettingsWindow")
}

/// Keys for notification userInfo
enum SettingsNotificationKey {
    static let tab = "tab"
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default values
        UserDefaults.standard.register(defaults: [
            "autoFixTone": true,
            "freeTonePlacement": false,
            "inputMethod": 0,
            "outputEncoding": 0,
            "tonePlacement": 0,
        ])
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
