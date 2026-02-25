//
//  AppDelegate.swift
//  ViType
//
//  Created by Tran Dat on 24/12/25.
//

import Cocoa
import Carbon
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Sparkle updater controller for automatic updates
    let updaterController: SPUStandardUpdaterController
    
    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }
    
    private var keyTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var transformer = KeyTransformer()
    private let injectedEventTag: Int64 = kViTypeEventMarker
    private let characterInjector = CharacterInjector()
    
    private var isInjectingReplacement: Bool = false
    private var pendingInjectedKeyDownCount: Int = 0
    private var queuedKeyDownEvents: [QueuedKeyDownEvent] = []
    private var flushQueuedEventsScheduled: Bool = false
    private var lastFocusedElement: AXUIElement?

    private var frontmostBundleID: String?
    private var excludedBundleIDs: Set<String> = []
    private var appActivationObserver: NSObjectProtocol?
    private var userDefaultsObserver: NSObjectProtocol?
    private var inputSourceObserver: NSObjectProtocol?
    private var sessionActiveObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var cachedInputSourceID: String?
    private var cachedInputSourceType: CFString?
    private var tapRestartPending: Bool = false
    
    // Unsupported input sources that should bypass Vietnamese transformation
    private let unsupportedInputSources: Set<String> = [
        "com.apple.inputmethod.SCIM.ITABC",           // Pinyin - Simplified
        "com.apple.inputmethod.TCIM.Pinyin",          // Pinyin - Traditional
        "com.apple.inputmethod.Korean",               // Korean
        "com.apple.inputmethod.Japanese",             // Japanese
        "com.apple.inputmethod.TCIM.Cangjie",         // Cangjie
        "com.apple.inputmethod.TCIM.Shuangpin",       // Shuangpin
        "com.apple.inputmethod.SCIM.Shuangpin",       // Shuangpin (Simplified)
    ]

    private var menuBarManager: MenuBarManager?
    private var settingsWindowObserver: NSObjectProtocol?

    // Cached shortcut settings for performance
    private var shortcutKey: String = ""
    private var shortcutKeyCode: Int64 = -1
    private var shortcutModifiers: CGEventFlags = []
    
    // Sound feedback
    private var toggleSound: NSSound?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // This is a menu-bar app by default; hide it from the Dock unless a window is explicitly shown.
        NSApp.setActivationPolicy(.accessory)

        // Register default values
        UserDefaults.standard.register(defaults: [
            "autoFixTone": true,
            "freeTonePlacement": false,
            "inputMethod": 0, // 0 = Telex, 1 = VNI
            "outputEncoding": 0,
            "tonePlacement": 0, // 0 = Orthographic, 1 = NucleusOnly
            AppExclusion.isEnabledKey: true,
            AppExclusion.excludedBundleIDsKey: "",
            AppExclusion.viTypeEnabledKey: true,
            AppExclusion.shortcutKeyKey: "x",
            AppExclusion.shortcutCommandKey: false,
            AppExclusion.shortcutOptionKey: false,
            AppExclusion.shortcutControlKey: true,
            AppExclusion.shortcutShiftKey: false,
            AppExclusion.playSoundOnToggleKey: true,
        ])

        refreshTransformerSettings()
        refreshFrontmostBundleID()
        refreshExcludedBundleIDs()
        refreshShortcutSettings()
        startAppExclusionObservers()
        startInputSourceObservers()
        startSessionObservers()
        startKeyTap()

        // Initialize menu bar with Sparkle updater
        menuBarManager = MenuBarManager(updaterController: updaterController)
        
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
    
    @objc private func showSettingsWindow(_ notification: Notification) {
        // Extract target tab from notification userInfo if provided
        let targetTab = notification.userInfo?[SettingsNotificationKey.tab] as? SettingsTab
        openSettingsWindow(tab: targetTab)
    }

    private func openSettingsWindow(tab: SettingsTab? = nil) {
        Task { @MainActor in
            // Show app in Dock temporarily while settings window is open
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.unhide(nil)

            let settingsWindow = await WindowManager.shared.openSettings(tab: tab)
            self.observeWindowClose(settingsWindow)
        }
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
        openSettingsWindow(tab: nil)
        return false // We handled it
    }

    deinit {
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
        if let inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(inputSourceObserver)
        }
        if let sessionActiveObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sessionActiveObserver)
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
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
            callback: { _, type, event, refcon in
                let delegate = Unmanaged<AppDelegate>
                    .fromOpaque(refcon!)
                    .takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    delegate.handleTapDisabled()
                    return nil
                }
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

    private func stopKeyTap() {
        if let runLoopSource {
            CFRunLoopSourceInvalidate(runLoopSource)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let keyTap {
            CFMachPortInvalidate(keyTap)
            self.keyTap = nil
        }
    }

    private func restartKeyTap() {
        stopKeyTap()
        resetKeyTapState()
        startKeyTap()
    }

    private func resetKeyTapState() {
        resetInputState()
    }

    private func resetInputState() {
        isInjectingReplacement = false
        pendingInjectedKeyDownCount = 0
        queuedKeyDownEvents.removeAll(keepingCapacity: true)
        flushQueuedEventsScheduled = false
        lastFocusedElement = nil
        transformer.reset()
    }

    private func requestKeyTapRestart() {
        guard !tapRestartPending else { return }
        tapRestartPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.tapRestartPending = false
            self.restartKeyTap()
        }
    }

    private func handleTapDisabled() {
        requestKeyTapRestart()
    }

    private func startSessionObservers() {
        sessionActiveObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.requestKeyTapRestart()
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.requestKeyTapRestart()
        }
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
            resetInputState()
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

    private func startInputSourceObservers() {
        refreshCachedInputSourceInfo(resetTransformerIfNeeded: false)

        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshCachedInputSourceInfo(resetTransformerIfNeeded: true)
        }
    }

    private func refreshCachedInputSourceInfo(resetTransformerIfNeeded: Bool) {
        let wasUnsupported = isInputSourceUnsupported(
            inputSourceID: cachedInputSourceID,
            inputSourceType: cachedInputSourceType
        )

        let info = getCurrentInputSourceInfo()
        cachedInputSourceID = info?.id
        cachedInputSourceType = info?.type

        let isUnsupported = isInputSourceUnsupported(
            inputSourceID: cachedInputSourceID,
            inputSourceType: cachedInputSourceType
        )

        if resetTransformerIfNeeded && wasUnsupported != isUnsupported {
            transformer.reset()
        }
    }

    private func refreshTransformerSettings() {
        transformer.autoFixTone = UserDefaults.standard.bool(forKey: "autoFixTone")
        transformer.freeTonePlacement = UserDefaults.standard.bool(forKey: "freeTonePlacement")
        let methodValue = UserDefaults.standard.integer(forKey: "inputMethod")
        transformer.inputMethod = InputMethod(rawValue: Int32(methodValue)) ?? .telex

        let encodingValue = UserDefaults.standard.integer(forKey: "outputEncoding")
        transformer.outputEncoding = OutputEncoding(rawValue: Int32(encodingValue)) ?? .unicode

        let tonePlacementValue = UserDefaults.standard.integer(forKey: "tonePlacement")
        transformer.tonePlacement = TonePlacement(rawValue: Int32(tonePlacementValue)) ?? .orthographic
    }

    private func refreshFrontmostBundleID() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func refreshExcludedBundleIDs() {
        let text = UserDefaults.standard.string(forKey: AppExclusion.excludedBundleIDsKey) ?? ""
        excludedBundleIDs = AppExclusion.parseBundleIDList(text)
    }

    private func refreshShortcutSettings() {
        shortcutKey = UserDefaults.standard.string(forKey: AppExclusion.shortcutKeyKey) ?? "x"
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
        
        // Check if current input source is unsupported (e.g., Pinyin, Korean, Japanese)
        if isUnsupportedInputSource() {
            return true
        }

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
    
    private func isUnsupportedInputSource() -> Bool {
        if cachedInputSourceID == nil && cachedInputSourceType == nil {
            let info = getCurrentInputSourceInfo()
            return isInputSourceUnsupported(inputSourceID: info?.id, inputSourceType: info?.type)
        }
        return isInputSourceUnsupported(inputSourceID: cachedInputSourceID, inputSourceType: cachedInputSourceType)
    }
    
    private func isInputSourceUnsupported(inputSourceID: String?, inputSourceType: CFString?) -> Bool {
        if inputSourceType == kTISTypeKeyboardInputMethodWithoutModes ||
            inputSourceType == kTISTypeKeyboardInputMethodModeEnabled ||
            inputSourceType == kTISTypeKeyboardInputMode {
            return true
        }
        guard let inputSourceID else { return false }
        return unsupportedInputSources.contains(inputSourceID)
    }

    private struct InputSourceInfo {
        let id: String
        let type: CFString?
    }

    private func getCurrentInputSourceInfo() -> InputSourceInfo? {
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }

        guard let sourceID = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
            return nil
        }
        let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String

        var type: CFString?
        if let sourceType = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceType) {
            type = Unmanaged<CFString>.fromOpaque(sourceType).takeUnretainedValue()
        }

        return InputSourceInfo(id: id, type: type)
    }
}

extension AppDelegate {
    private struct QueuedKeyDownEvent {
        let keyCode: Int64
        let flags: CGEventFlags
        let unicodeString: String?
    }
    
    // Key codes for navigation and special keys
    private static let backspaceKey: Int64 = 51
    private static let forwardDeleteKey: Int64 = 117
    private static let escapeKey: Int64 = 53
    private static let navigationKeys: Set<Int64> = [
        123, 124, 125, 126,  // Arrow keys: left, right, down, up
        115, 119,            // Home, End
        116, 121             // Page Up, Page Down
    ]

    // Key code mapping for a-z, 0-9, punctuation, and space
    private static let keyCodeMap: [String: Int64] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
        "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35,
        "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
        "y": 16, "z": 6,
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
        "[": 33, "]": 30, "\\": 42, ";": 41, "'": 39, ",": 43, ".": 47, "/": 44, "`": 50,
        "space": 49
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
            noteInjectedKeyDown()
            return false
        }

        resetStateIfFocusedElementChanged()
        
        if isInjectingReplacement {
            enqueueKeyDownEvent(event)
            return true
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

    private func resetStateIfFocusedElementChanged() {
        // Skip focus check for Electron-based apps (VSCode, Cursor, Trae) as their AX references are unstable
        // and trigger constant state resets, breaking Vietnamese input (e.g. "đă3ng").
        // We rely on app activation/deactivation to reset state for these apps.
        if let bundleID = frontmostBundleID {
             let lower = bundleID.lowercased()
             if lower.contains("vscode") || 
                lower.contains("cursor") || 
                lower.contains("trae") ||
                lower.contains("windsurf") ||
                lower.contains("electron") {
                 return
             }
        }

        guard AXIsProcessTrusted() else { return }

        let current: AXUIElement? = {
            if Thread.isMainThread {
                return focusedElement()
            }
            return DispatchQueue.main.sync { [weak self] in
                self?.focusedElement()
            }
        }()

        guard let current else {
            if lastFocusedElement != nil {
                transformer.reset()
            }
            lastFocusedElement = nil
            return
        }

        guard let lastFocusedElement else {
            self.lastFocusedElement = current
            return
        }

        guard !CFEqual(lastFocusedElement, current) else { return }

        self.lastFocusedElement = current
        resetInputState()
    }

    private func replace(last count: Int, with text: String, extraDeleteCount: Int) {
        beginReplacementInjection()
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            self.characterInjector.injectSync(
                backspaceCount: extraDeleteCount + count,
                text: text,
                proxy: nil
            )
            DispatchQueue.main.async {
                self.finishReplacementInjection()
            }
        }
    }
    
    private func enqueueKeyDownEvent(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        queuedKeyDownEvents.append(
            QueuedKeyDownEvent(
                keyCode: keyCode,
                flags: event.flags,
                unicodeString: event.keyboardGetUnicodeString()
            )
        )
        
        if queuedKeyDownEvents.count > 128 {
            queuedKeyDownEvents.removeAll(keepingCapacity: true)
            isInjectingReplacement = false
            transformer.reset()
        }
    }
    
    private func beginReplacementInjection(backspaceCount: Int = 0) {
        isInjectingReplacement = true
    }
    
    private func finishReplacementInjection() {
        isInjectingReplacement = false
        scheduleFlushQueuedEvents()
    }
    
    private func noteInjectedKeyDown() {
        // No-op: we manage state via completion handler now
    }
    
    private func scheduleFlushQueuedEvents() {
        guard !flushQueuedEventsScheduled else { return }
        flushQueuedEventsScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.flushQueuedEventsScheduled = false
            self.flushQueuedKeyDownEvents()
        }
    }
    
    private func flushQueuedKeyDownEvents() {
        while !isInjectingReplacement && !queuedKeyDownEvents.isEmpty {
            let next = queuedKeyDownEvents.removeFirst()
            replayQueuedKeyDown(next)
        }
    }
    
    private func replayQueuedKeyDown(_ queued: QueuedKeyDownEvent) {
        let keyCode = queued.keyCode
        let flags = queued.flags
        
        if isToggleShortcut(keyCode: keyCode, flags: flags) {
            toggleViType()
            return
        }
        
        if shouldBypassVietnameseInput() {
            transformer.reset()
            if let s = queued.unicodeString {
                // Use replace with 0 backspaces to handle text injection asynchronously and safely
                replace(last: 0, with: s, extraDeleteCount: 0)
            } else {
                sendKey(CGKeyCode(keyCode))
            }
            return
        }
        
        let hasActionModifier = flags.contains(.maskCommand) ||
                                flags.contains(.maskControl) ||
                                flags.contains(.maskAlternate)
        
        if keyCode == Self.backspaceKey && !hasActionModifier {
            transformer.deleteLastCharacter()
            sendKey(CGKeyCode(Self.backspaceKey))
            return
        }
        
        if keyCode == Self.forwardDeleteKey ||
           keyCode == Self.escapeKey ||
           Self.navigationKeys.contains(keyCode) ||
           hasActionModifier {
            transformer.reset()
            sendKey(CGKeyCode(keyCode))
            return
        }
        
        guard let s = queued.unicodeString else {
            sendKey(CGKeyCode(keyCode))
            return
        }
        
        refreshTransformerSettings()
        
        if let action = transformer.process(input: s) {
            let extraDeleteCount = shouldWipeGhostSuggestion() ? 1 : 0
            replace(last: action.deleteCount, with: action.text, extraDeleteCount: extraDeleteCount)
        } else {
            // Use replace with 0 backspaces
            replace(last: 0, with: s, extraDeleteCount: 0)
        }
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
