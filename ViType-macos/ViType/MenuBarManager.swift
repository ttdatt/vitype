//
//  MenuBarManager.swift
//  ViType
//
//  Created by Tran Dat on 25/12/25.
//

import Cocoa

extension Notification.Name {
    static let showSettingsWindow = Notification.Name("showSettingsWindow")
}

final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var userDefaultsObserver: NSObjectProtocol?

    override init() {
        super.init()
        setupStatusItem()
        startObservingDefaults()
    }

    deinit {
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusItemAppearance()

        if let button = statusItem?.button {
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func startObservingDefaults() {
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusItemAppearance()
        }
    }

    private func updateStatusItemAppearance() {
        let isEnabled = UserDefaults.standard.bool(forKey: AppExclusion.viTypeEnabledKey)

        if let button = statusItem?.button {
            // Use "V" for Vietnamese enabled, "E" for English (disabled)
            button.title = isEnabled ? "V" : "E"

            // Optionally add a tooltip
            button.toolTip = isEnabled ? "ViType: Vietnamese (Click to switch to English)" : "ViType: English (Click to switch to Vietnamese)"
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent

        if event?.type == .rightMouseUp {
            showMenu()
        } else {
            toggleViType()
        }
    }

    private func toggleViType() {
        let currentState = UserDefaults.standard.bool(forKey: AppExclusion.viTypeEnabledKey)
        UserDefaults.standard.set(!currentState, forKey: AppExclusion.viTypeEnabledKey)
    }

    private func showMenu() {
        let menu = NSMenu()

        let isEnabled = UserDefaults.standard.bool(forKey: AppExclusion.viTypeEnabledKey)

        let toggleItem = NSMenuItem(
            title: isEnabled ? "Switch to English" : "Switch to Vietnamese",
            action: #selector(menuToggleViType),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "About ViType",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "Quit ViType",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func menuToggleViType() {
        toggleViType()
    }

    @objc private func openSettings() {
        // Post notification - AppDelegate handles all the window management
        NotificationCenter.default.post(name: .showSettingsWindow, object: nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(
                string: "Author: Trần Tiến Đạt\nEmail: ttdat.nt@gmail.com",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            )
        ])
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
