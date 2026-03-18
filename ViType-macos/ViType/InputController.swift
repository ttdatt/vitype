//
//  InputController.swift
//  ViType
//
//  IMKInputController subclass — handles key events via Input Method Kit.
//  Uses marked text (inline composition) instead of backspace+retype.
//

import Cocoa
import InputMethodKit

@objc(ViTypeInputController)
class InputController: IMKInputController {

    private var engine = KeyTransformer()
    private var composingText = ""

    // MARK: - Server Lifecycle

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        engine.reset()
        composingText = ""
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        super.deactivateServer(sender)
    }

    // MARK: - Composition

    override func composedString(_ sender: Any!) -> Any! {
        return composingText
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        if !composingText.isEmpty {
            client.insertText(composingText,
                            replacementRange: NSRange(location: NSNotFound, length: 0))
        }
        composingText = ""
        engine.reset()
    }

    // MARK: - Event Handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else { return false }
        guard let client = sender as? IMKTextInput else { return false }

        let keyCode = event.keyCode
        let modifiers = event.modifierFlags

        // Pass through events with Cmd modifier (shortcuts like Cmd+C, Cmd+V)
        if modifiers.contains(.command) {
            commitIfNeeded(client: client)
            return false
        }

        // Ctrl combinations: commit and pass through
        if modifiers.contains(.control) {
            commitIfNeeded(client: client)
            return false
        }

        // Option combinations: commit and pass through
        if modifiers.contains(.option) {
            commitIfNeeded(client: client)
            return false
        }

        // Backspace
        if keyCode == 51 {
            return handleBackspace(client: client)
        }

        // Escape — cancel composition, insert raw text
        if keyCode == 53 {
            if !composingText.isEmpty {
                // Cancel: clear marked text without committing
                client.insertText("", replacementRange: NSRange(location: NSNotFound, length: 0))
                composingText = ""
                engine.reset()
                return true
            }
            return false
        }

        // Arrow keys, Home, End, Page Up/Down — commit and pass through
        if isNavigationKey(keyCode) {
            commitIfNeeded(client: client)
            return false
        }

        // Forward delete
        if keyCode == 117 {
            commitIfNeeded(client: client)
            return false
        }

        guard let chars = event.characters, !chars.isEmpty else { return false }

        let char = chars.first!

        // Space, Enter, Tab — commit composition then pass through
        if char == " " || char == "\n" || char == "\r" || char == "\t" || keyCode == 36 || keyCode == 76 || keyCode == 48 {
            commitIfNeeded(client: client)
            return false
        }

        // Punctuation and digits — commit first, then pass through
        if isPunctuation(char) || char.isNumber {
            commitIfNeeded(client: client)
            return false
        }

        // Regular character — feed to engine
        return handleCharacter(chars, client: client)
    }

    // MARK: - Character Processing

    private func handleCharacter(_ input: String, client: IMKTextInput) -> Bool {
        refreshEngineSettings()

        if let action = engine.process(input: input) {
            // Engine produced a transformation
            composingText = engine.getComposedText()
            updateMarkedText(client: client)
            return true
        } else {
            // No transformation — engine accepted the char into its buffer
            // but no visual change needed from the engine's perspective.
            // Update composing text from engine buffer.
            let newComposed = engine.getComposedText()
            if newComposed.count > composingText.count {
                // Character was added to buffer
                composingText = newComposed
                updateMarkedText(client: client)
                return true
            }

            // Engine didn't consume the char (word boundary, etc.)
            // Commit current composition and pass through
            commitIfNeeded(client: client)
            return false
        }
    }

    private func handleBackspace(client: IMKTextInput) -> Bool {
        if composingText.isEmpty {
            return false // let app handle it
        }

        engine.deleteLastCharacter()
        composingText = engine.getComposedText()

        if composingText.isEmpty {
            // Clear marked text
            client.insertText("", replacementRange: NSRange(location: NSNotFound, length: 0))
        } else {
            updateMarkedText(client: client)
        }
        return true
    }

    // MARK: - Marked Text

    private func updateMarkedText(client: IMKTextInput) {
        let attrs: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.thick.rawValue,
            .foregroundColor: NSColor.textColor,
        ]
        let marked = NSAttributedString(string: composingText, attributes: attrs)

        client.setMarkedText(marked,
                           selectionRange: NSRange(location: composingText.utf16.count, length: 0),
                           replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func commitIfNeeded(client: IMKTextInput) {
        guard !composingText.isEmpty else { return }
        client.insertText(composingText,
                        replacementRange: NSRange(location: NSNotFound, length: 0))
        composingText = ""
        engine.reset()
    }

    // MARK: - Helpers

    private func isNavigationKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 123, 124, 125, 126, // Arrow keys
             115, 119,           // Home, End
             116, 121:           // Page Up, Page Down
            return true
        default:
            return false
        }
    }

    private func isPunctuation(_ char: Character) -> Bool {
        let punctuationChars: Set<Character> = [
            ".", ",", ";", ":", "!", "?", "'", "\"",
            "(", ")", "[", "]", "{", "}", "<", ">",
            "/", "\\", "|", "@", "#", "$", "%", "^",
            "&", "*", "-", "_", "+", "=", "~", "`",
        ]
        return punctuationChars.contains(char)
    }

    private func refreshEngineSettings() {
        engine.autoFixTone = UserDefaults.standard.bool(forKey: "autoFixTone")
        engine.freeTonePlacement = UserDefaults.standard.bool(forKey: "freeTonePlacement")
        let methodValue = UserDefaults.standard.integer(forKey: "inputMethod")
        engine.inputMethod = InputMethod(rawValue: Int32(methodValue)) ?? .telex
        let encodingValue = UserDefaults.standard.integer(forKey: "outputEncoding")
        engine.outputEncoding = OutputEncoding(rawValue: Int32(encodingValue)) ?? .unicode
        let tonePlacementValue = UserDefaults.standard.integer(forKey: "tonePlacement")
        engine.tonePlacement = TonePlacement(rawValue: Int32(tonePlacementValue)) ?? .orthographic
    }

    // MARK: - Menu

    override func menu() -> NSMenu! {
        let menu = NSMenu()

        let inputMethodValue = UserDefaults.standard.integer(forKey: "inputMethod")

        let telexItem = NSMenuItem(title: "Telex", action: #selector(selectTelex), keyEquivalent: "")
        telexItem.target = self
        telexItem.state = inputMethodValue == 0 ? .on : .off
        menu.addItem(telexItem)

        let vniItem = NSMenuItem(title: "VNI", action: #selector(selectVni), keyEquivalent: "")
        vniItem.target = self
        vniItem.state = inputMethodValue == 1 ? .on : .off
        menu.addItem(vniItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About ViType", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        return menu
    }

    @objc private func selectTelex() {
        UserDefaults.standard.set(0, forKey: "inputMethod")
    }

    @objc private func selectVni() {
        UserDefaults.standard.set(1, forKey: "inputMethod")
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .showSettingsWindow, object: nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
