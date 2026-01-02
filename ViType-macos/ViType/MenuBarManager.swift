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
    private var languageObserver: NSObjectProtocol?

    override init() {
        super.init()
        setupStatusItem()
        startObservingDefaults()
        startObservingLanguageChanges()
    }

    deinit {
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = languageObserver {
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

    private func startObservingLanguageChanges() {
        languageObserver = NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusItemAppearance()
        }
    }

    private func updateStatusItemAppearance() {
        let isEnabled = UserDefaults.standard.bool(forKey: AppExclusion.viTypeEnabledKey)
        let inputMethodValue = UserDefaults.standard.integer(forKey: "inputMethod")
        let inputMethodLabel = inputMethodValue == 1 ? "VNI" : "Telex"

        if let button = statusItem?.button {
            // Use "V" for Vietnamese enabled, "E" for English (disabled)
            button.title = isEnabled ? "V" : "E"

            // Localized tooltip
            button.toolTip = isEnabled
                ? "ViType Tooltip Vietnamese".localized(inputMethodLabel)
                : "ViType Tooltip English".localized()
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        showMenu()
    }

    private func toggleViType() {
        let currentState = UserDefaults.standard.bool(forKey: AppExclusion.viTypeEnabledKey)
        UserDefaults.standard.set(!currentState, forKey: AppExclusion.viTypeEnabledKey)
    }

    private func showMenu() {
        let menu = NSMenu()

        let isEnabled = UserDefaults.standard.bool(forKey: AppExclusion.viTypeEnabledKey)
        let inputMethodValue = UserDefaults.standard.integer(forKey: "inputMethod")

        let toggleItem = NSMenuItem(
            title: isEnabled ? "Switch to English".localized() : "Switch to Vietnamese".localized(),
            action: #selector(menuToggleViType),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let inputHeader = NSMenuItem(title: "Input Method".localized(), action: nil, keyEquivalent: "")
        inputHeader.isEnabled = false
        menu.addItem(inputHeader)

        let telexItem = NSMenuItem(
            title: "Telex",
            action: #selector(selectTelex),
            keyEquivalent: ""
        )
        telexItem.target = self
        telexItem.state = inputMethodValue == 0 ? .on : .off
        menu.addItem(telexItem)

        let vniItem = NSMenuItem(
            title: "VNI",
            action: #selector(selectVni),
            keyEquivalent: ""
        )
        vniItem.target = self
        vniItem.state = inputMethodValue == 1 ? .on : .off
        menu.addItem(vniItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...".localized(),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "About ViType".localized(),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "Quit ViType".localized(),
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

    @objc private func selectTelex() {
        setInputMethod(0)
    }

    @objc private func selectVni() {
        setInputMethod(1)
    }

    private func setInputMethod(_ method: Int) {
        UserDefaults.standard.set(method, forKey: "inputMethod")
    }

    @objc private func openSettings() {
        // Post notification - AppDelegate handles all the window management
        NotificationCenter.default.post(name: .showSettingsWindow, object: nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(
                string: "Author Credits".localized(),
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            )
        ])
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
