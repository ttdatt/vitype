//
//  AppDelegate.swift
//  ViType
//
//  Created by Tran Dat on 24/12/25.
//

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var transformer = KeyTransformer()
    private let injectedEventTag: Int64 = 0x11EE22DD

    private var frontmostBundleID: String?
    private var excludedBundleIDs: Set<String> = []
    private var appActivationObserver: NSObjectProtocol?
    private var userDefaultsObserver: NSObjectProtocol?

    private var menuBarManager: MenuBarManager?
    private var settingsWindowObserver: NSObjectProtocol?

    // Cached shortcut settings for performance
    private var shortcutKey: String = ""
    private var shortcutKeyCode: Int64 = -1
    private var shortcutModifiers: CGEventFlags = []
    
    // Sound feedback
    private var toggleSound: NSSound?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default values
        UserDefaults.standard.register(defaults: [
            "autoFixTone": true,
            "inputMethod": 0, // 0 = Telex, 1 = VNI
            "outputEncoding": 0,
            AppExclusion.isEnabledKey: true,
            AppExclusion.excludedBundleIDsKey: "",
            AppExclusion.viTypeEnabledKey: true,
            AppExclusion.shortcutKeyKey: "space",
            AppExclusion.shortcutCommandKey: false,
            AppExclusion.shortcutOptionKey: false,
            AppExclusion.shortcutControlKey: true,
            AppExclusion.shortcutShiftKey: false,
            AppExclusion.useAXGhostSuggestionKey: true,
            AppExclusion.playSoundOnToggleKey: true,
        ])

        refreshTransformerSettings()
        refreshFrontmostBundleID()
        refreshExcludedBundleIDs()
        refreshShortcutSettings()
        startAppExclusionObservers()
        startKeyTap()

        // Initialize menu bar
        menuBarManager = MenuBarManager()
        
        // Listen for settings window requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettingsWindow),
            name: .showSettingsWindow,
            object: nil
        )
        
        // Observe the initial settings window for close events (to hide from Dock when closed)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds for SwiftUI to create window
            for window in NSApp.windows {
                if window is NSPanel { continue }
                if window.className.contains("StatusBar") { continue }
                if window.level == .statusBar { continue }
                
                if window.contentView != nil && window.isVisible {
                    self.observeWindowClose(window)
                    break
                }
            }
        }
    }
    
    @objc private func showSettingsWindow() {
        // Show app in Dock temporarily while settings window is open
        NSApp.setActivationPolicy(.regular)
        
        // Use WindowManager to open the settings window via SwiftUI
        Task { @MainActor in
            WindowManager.shared.openSettings()
            
            // Wait a moment for the window to be created, then observe it
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Find and observe the settings window for close events
            for window in NSApp.windows {
                if window is NSPanel { continue }
                if window.className.contains("StatusBar") { continue }
                if window.level == .statusBar { continue }
                
                if window.contentView != nil && window.isVisible {
                    self.observeWindowClose(window)
                    break
                }
            }
        }
        
        // Activate the app to bring it to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func observeWindowClose(_ window: NSWindow) {
        // Remove any existing observer
        if let observer = settingsWindowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Observe when this window closes
        settingsWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            // Hide from Dock when settings window closes
            NSApp.setActivationPolicy(.accessory)
            self?.settingsWindowObserver = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the app running (menu bar icon) even when the settings window is closed
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Called when user clicks the app icon while it's already running (e.g., from Finder, Dock, Spotlight)
        // Show the settings window and Dock icon for consistent behavior
        showSettingsWindow()
        return false // We handled it
    }

    deinit {
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
        if let settingsWindowObserver {
            NotificationCenter.default.removeObserver(settingsWindowObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func startKeyTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        keyTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                let delegate = Unmanaged<AppDelegate>
                    .fromOpaque(refcon!)
                    .takeUnretainedValue()
                let suppress = delegate.handle(event: event)
                return suppress ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(
                Unmanaged.passUnretained(self).toOpaque()
            )
        )

        guard let tap = keyTap else {
            print("No Accessibility permission.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func startAppExclusionObservers() {
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            frontmostBundleID = app?.bundleIdentifier ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            transformer.reset()
        }

        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let wasBypassing = shouldBypassVietnameseInput()
            refreshExcludedBundleIDs()
            refreshShortcutSettings()
            refreshTransformerSettings()
            let isBypassing = shouldBypassVietnameseInput()
            if wasBypassing != isBypassing {
                transformer.reset()
            }
        }
    }

    private func refreshTransformerSettings() {
        transformer.autoFixTone = UserDefaults.standard.bool(forKey: "autoFixTone")
        let methodValue = UserDefaults.standard.integer(forKey: "inputMethod")
        transformer.inputMethod = InputMethod(rawValue: Int32(methodValue)) ?? .telex

        let encodingValue = UserDefaults.standard.integer(forKey: "outputEncoding")
        transformer.outputEncoding = OutputEncoding(rawValue: Int32(encodingValue)) ?? .unicode
    }

    private func refreshFrontmostBundleID() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func refreshExcludedBundleIDs() {
        let text = UserDefaults.standard.string(forKey: AppExclusion.excludedBundleIDsKey) ?? ""
        excludedBundleIDs = AppExclusion.parseBundleIDList(text)
    }

    private func refreshShortcutSettings() {
        shortcutKey = UserDefaults.standard.string(forKey: AppExclusion.shortcutKeyKey) ?? "space"
        shortcutKeyCode = Self.keyCodeForCharacter(shortcutKey)

        var modifiers: CGEventFlags = []
        if UserDefaults.standard.bool(forKey: AppExclusion.shortcutCommandKey) {
            modifiers.insert(.maskCommand)
        }
        if UserDefaults.standard.bool(forKey: AppExclusion.shortcutOptionKey) {
            modifiers.insert(.maskAlternate)
        }
        if UserDefaults.standard.bool(forKey: AppExclusion.shortcutControlKey) {
            modifiers.insert(.maskControl)
        }
        if UserDefaults.standard.bool(forKey: AppExclusion.shortcutShiftKey) {
            modifiers.insert(.maskShift)
        }
        shortcutModifiers = modifiers
    }

    private func shouldBypassVietnameseInput() -> Bool {
        // Check global enable toggle first
        guard UserDefaults.standard.bool(forKey: AppExclusion.viTypeEnabledKey) else { return true }

        // Then check app exclusion
        guard UserDefaults.standard.bool(forKey: AppExclusion.isEnabledKey) else { return false }
        guard let frontmostBundleID else { return false }
        let normalizedFrontmost = AppExclusion.normalizeBundleID(frontmostBundleID)
        if let viTypeBundleID = Bundle.main.bundleIdentifier.map({ AppExclusion.normalizeBundleID($0) }),
           normalizedFrontmost == viTypeBundleID {
            return true
        }
        return excludedBundleIDs.contains(normalizedFrontmost)
    }

    private func toggleViType() {
        let currentState = UserDefaults.standard.bool(forKey: AppExclusion.viTypeEnabledKey)
        let newState = !currentState
        UserDefaults.standard.set(newState, forKey: AppExclusion.viTypeEnabledKey)
        transformer.reset()
        
        // Play sound feedback if enabled
        if UserDefaults.standard.bool(forKey: AppExclusion.playSoundOnToggleKey) {
            // Stop any currently playing sound to ensure new sound plays immediately
            toggleSound?.stop()
            // Different sounds for enable vs disable
            // "Tink" for enable (short, high), "Pop" for disable (short, low)
            let soundName = newState ? "Tink" : "Pop"
            toggleSound = NSSound(named: NSSound.Name(soundName))
            toggleSound?.play()
        }
    }
}

extension AppDelegate {
    // Key codes for navigation and special keys
    private static let backspaceKey: Int64 = 51
    private static let forwardDeleteKey: Int64 = 117
    private static let escapeKey: Int64 = 53
    private static let navigationKeys: Set<Int64> = [
        123, 124, 125, 126,  // Arrow keys: left, right, down, up
        115, 119,            // Home, End
        116, 121             // Page Up, Page Down
    ]

    // Key code mapping for a-z and space
    private static let keyCodeMap: [String: Int64] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
        "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35,
        "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
        "y": 16, "z": 6, "space": 49
    ]

    static func keyCodeForCharacter(_ char: String) -> Int64 {
        keyCodeMap[char.lowercased()] ?? -1
    }

    private func isToggleShortcut(keyCode: Int64, flags: CGEventFlags) -> Bool {
        // Must have at least one modifier configured
        guard shortcutModifiers.rawValue != 0 else { return false }
        // Must have the correct key
        guard keyCode == shortcutKeyCode else { return false }

        // Check modifiers - we need to mask out caps lock and numeric pad flags
        let relevantModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let pressedModifiers = flags.intersection(relevantModifiers)

        return pressedModifiers == shortcutModifiers
    }
    
    /// Returns `true` if the event should be suppressed (not passed to the application).
    func handle(event: CGEvent) -> Bool {
        // Skip injected events
        if event.getIntegerValueField(.eventSourceUserData) == injectedEventTag {
            return false
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Check for toggle shortcut
        if isToggleShortcut(keyCode: keyCode, flags: flags) {
            toggleViType()
            return true  // Suppress the event
        }

        // App exclusion: bypass Vietnamese transformation for excluded apps.
        if shouldBypassVietnameseInput() {
            transformer.reset()
            return false
        }
        
        // Check for action modifiers (Cmd, Ctrl, Option) - these typically perform actions
        let hasActionModifier = flags.contains(.maskCommand) ||
                                flags.contains(.maskControl) ||
                                flags.contains(.maskAlternate)
        
        // Backspace without modifiers - remove one char from buffer
        if keyCode == Self.backspaceKey && !hasActionModifier {
            transformer.deleteLastCharacter()
            return false
        }
        
        // Navigation keys, forward delete, escape, or any key with action modifiers - reset buffer
        if keyCode == Self.forwardDeleteKey ||
           keyCode == Self.escapeKey ||
           Self.navigationKeys.contains(keyCode) ||
           hasActionModifier {
            transformer.reset()
            return false
        }

        guard let s = event.keyboardGetUnicodeString() else { return false }

        // Update settings from UserDefaults
        refreshTransformerSettings()
        
        if let action = transformer.process(input: s) {
            let extraDeleteCount = shouldWipeGhostSuggestion() ? 1 : 0
            replace(last: action.deleteCount, with: action.text, extraDeleteCount: extraDeleteCount)
            return true
        }
        return false
    }

    private func replace(last count: Int, with text: String, extraDeleteCount: Int) {
        if extraDeleteCount > 0 {
            for _ in 0..<extraDeleteCount { sendKey(CGKeyCode(Self.backspaceKey)) }
        }
        for _ in 0..<count { sendKey(CGKeyCode(Self.backspaceKey)) }
        sendText(text)
    }

    private func sendKey(_ key: CGKeyCode) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        down?.setIntegerValueField(.eventSourceUserData, value: injectedEventTag)
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        up?.setIntegerValueField(.eventSourceUserData, value: injectedEventTag)
        up?.post(tap: .cghidEventTap)
    }

    private func sendText(_ text: String) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        var utf16 = Array(text.utf16)

        let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        down?.setIntegerValueField(.eventSourceUserData, value: injectedEventTag)
        utf16.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            down?.keyboardSetUnicodeString(
                stringLength: buffer.count,
                unicodeString: baseAddress
            )
        }
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        up?.setIntegerValueField(.eventSourceUserData, value: injectedEventTag)
        up?.post(tap: .cghidEventTap)
    }
}

extension AppDelegate {
    private func shouldWipeGhostSuggestion() -> Bool {
        guard UserDefaults.standard.bool(forKey: AppExclusion.useAXGhostSuggestionKey) else { return false }
        guard AXIsProcessTrusted() else { return false }
        return readSelectionRange()
            .map { $0.isGhostSuggestion }
            ?? false
    }

    private func readSelectionRange() -> SelectionRangeContext? {
        let work: () -> SelectionRangeContext? = { [weak self] in
            guard let self, let element = self.focusedElement() else { return nil }
            guard let rangeValue = copyAXValue(from: element, name: kAXSelectedTextRangeAttribute) else { return nil }

            var range = CFRange()
            guard AXValueGetValue(rangeValue, .cfRange, &range) else { return nil }
            guard range.length > 0 else { return nil }

            let valueLength: Int?
            if let value = copyAttribute(element, name: kAXValueAttribute) as? String {
                valueLength = value.utf16.count
            } else {
                valueLength = nil
            }

            let selectedTextLength: Int?
            if let selectedText = copyAttribute(element, name: kAXSelectedTextAttribute) as? String {
                selectedTextLength = selectedText.utf16.count
            } else {
                selectedTextLength = nil
            }

            return SelectionRangeContext(range: range, valueLength: valueLength, selectedTextLength: selectedTextLength)
        }

        if Thread.isMainThread {
            return work()
        }
        return DispatchQueue.main.sync { work() }
    }

    private func focusedElement() -> AXUIElement? {
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
            if let element = copyFocusedElement(from: appElement) {
                return element
            }
        }

        let systemWide = AXUIElementCreateSystemWide()
        return copyFocusedElement(from: systemWide)
    }

    private func copyFocusedElement(from root: AXUIElement) -> AXUIElement? {
        guard let value = copyAttribute(root, name: kAXFocusedUIElementAttribute) else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func copyAttribute(_ element: AXUIElement, name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return result == .success ? value : nil
    }

    private func copyAXValue(from element: AXUIElement, name: String) -> AXValue? {
        guard let value = copyAttribute(element, name: name) else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

}

private struct SelectionRangeContext {
    let range: CFRange
    let valueLength: Int?
    let selectedTextLength: Int?

    var isGhostSuggestion: Bool {
        guard range.length > 0 else { return false }

        if let valueLength {
            let rangeEnd = Int(range.location + range.length)
            guard rangeEnd == valueLength else { return false }
        }

        if let selectedTextLength, selectedTextLength != Int(range.length) {
            return false
        }

        return true
    }
}

extension CGEvent {
    func keyboardGetUnicodeString() -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        keyboardGetUnicodeString(
            maxStringLength: 4,
            actualStringLength: &length,
            unicodeString: &chars
        )
        return length > 0 ? String(utf16CodeUnits: chars, count: length) : nil
    }
}
