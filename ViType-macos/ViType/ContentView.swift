//
//  ContentView.swift
//  ViType
//
//  Created by Tran Dat on 24/12/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("autoFixTone") private var autoFixTone = true
    @AppStorage("outputEncoding") private var outputEncoding = 0
    @AppStorage(AppExclusion.isEnabledKey) private var appExclusionEnabled = true
    @AppStorage(AppExclusion.excludedBundleIDsKey) private var excludedBundleIDsText = ""
    @AppStorage(AppExclusion.viTypeEnabledKey) private var viTypeEnabled = true
    @AppStorage(AppExclusion.useAXGhostSuggestionKey) private var useAXGhostSuggestion = true

    // Shortcut settings
    @AppStorage(AppExclusion.shortcutKeyKey) private var shortcutKey = "space"
    @AppStorage(AppExclusion.shortcutCommandKey) private var shortcutCommand = false
    @AppStorage(AppExclusion.shortcutOptionKey) private var shortcutOption = false
    @AppStorage(AppExclusion.shortcutControlKey) private var shortcutControl = true
    @AppStorage(AppExclusion.shortcutShiftKey) private var shortcutShift = false

    @StateObject private var frontmostAppMonitor = FrontmostAppMonitor()

    private var bundleIDToAdd: String? {
        let viTypeBundleID = Bundle.main.bundleIdentifier?.lowercased()
        let current = frontmostAppMonitor.bundleIdentifier?.lowercased()
        if current == viTypeBundleID {
            return frontmostAppMonitor.lastNonViTypeBundleIdentifier
        }
        return current ?? frontmostAppMonitor.lastNonViTypeBundleIdentifier
    }

    private var addButtonTitle: String {
        let viTypeBundleID = Bundle.main.bundleIdentifier?.lowercased()
        let current = frontmostAppMonitor.bundleIdentifier?.lowercased()
        return current == viTypeBundleID ? "Add Previous App" : "Add Current App"
    }

    private var shortcutDisplayString: String {
        var parts: [String] = []
        if shortcutControl { parts.append("^") }
        if shortcutOption { parts.append("\u{2325}") }
        if shortcutCommand { parts.append("\u{2318}") }
        if shortcutShift { parts.append("\u{21E7}") }

        let keyDisplay = shortcutKey.lowercased() == "space" ? "Space" : shortcutKey.uppercased()
        parts.append(keyDisplay)

        return parts.joined()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ViType")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Vietnamese Telex Input Method")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()

            Toggle("Enable viType", isOn: $viTypeEnabled)

            Text("Toggle Vietnamese input on/off. When disabled, all keys pass through unchanged.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Keyboard shortcut settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Toggle Shortcut:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Toggle("Control", isOn: $shortcutControl)
                        .toggleStyle(.checkbox)
                    Toggle("Option", isOn: $shortcutOption)
                        .toggleStyle(.checkbox)
                    Toggle("Command", isOn: $shortcutCommand)
                        .toggleStyle(.checkbox)
                    Toggle("Shift", isOn: $shortcutShift)
                        .toggleStyle(.checkbox)
                }
                .font(.caption)

                HStack(spacing: 8) {
                    Text("Key:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ShortcutKeyField(key: $shortcutKey)
                        .frame(width: 60)

                    Text(shortcutDisplayString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
            }
            .padding(.leading, 20)

            Divider()
            
            Toggle("Auto Fix Tone", isOn: $autoFixTone)
            
            Text("Automatically reposition tone marks when adding vowels to follow Vietnamese spelling rules.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Picker("Character Encoding:", selection: $outputEncoding) {
                Text("Unicode").tag(0)
                Text("Composite Unicode").tag(1)
            }
            .pickerStyle(.menu)

            Text("Unicode uses precomposed characters (default). Composite Unicode uses decomposed characters (NFD).")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("Use Accessibility API", isOn: $useAXGhostSuggestion)

            Text("Enable AX-based detection to avoid browser suggestion conflicts.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("App Exclusion", isOn: $appExclusionEnabled)

            Text("Disable ViType when these apps are focused (bundle IDs, one per line or comma-separated):")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $excludedBundleIDsText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 96)
                .disabled(!appExclusionEnabled)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.secondary.opacity(0.25))
                )

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Current app:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(frontmostAppMonitor.bundleIdentifier ?? "Unknown")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 8) {
                        Text("Previous app:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(frontmostAppMonitor.lastNonViTypeBundleIdentifier ?? "Unknown")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Spacer()

                Button(addButtonTitle) {
                    addBundleIDToExclusionList()
                }
                .disabled(!appExclusionEnabled || bundleIDToAdd == nil)
            }
            
        }
        .padding()
        .frame(width: 420)
    }

    private func addBundleIDToExclusionList() {
        guard let bundleID = bundleIDToAdd else { return }
        let normalized = AppExclusion.normalizeBundleID(bundleID)
        guard !normalized.isEmpty else { return }

        let existing = AppExclusion.parseBundleIDList(excludedBundleIDsText)
        guard !existing.contains(normalized) else { return }

        if excludedBundleIDsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            excludedBundleIDsText = normalized
        } else {
            excludedBundleIDsText += "\n" + normalized
        }
    }
}

// Custom text field that only accepts a single character (a-z) or "space"
struct ShortcutKeyField: View {
    @Binding var key: String
    @State private var displayText: String = ""

    var body: some View {
        TextField("", text: $displayText)
            .textFieldStyle(.roundedBorder)
            .onAppear {
                displayText = key.lowercased() == "space" ? "Space" : key.uppercased()
            }
            .onChange(of: displayText) { _, newValue in
                processInput(newValue)
            }
    }

    private func processInput(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Check for "space" typed out
        if trimmed.lowercased() == "space" {
            key = "space"
            displayText = "Space"
            return
        }

        // If user types a space character
        if input.contains(" ") {
            key = "space"
            displayText = "Space"
            return
        }

        // Take only the last character if multiple are entered
        guard let lastChar = trimmed.last else {
            // Empty input - reset to current key
            displayText = key.lowercased() == "space" ? "Space" : key.uppercased()
            return
        }

        let char = String(lastChar).lowercased()

        // Only accept a-z
        if char.count == 1, let scalar = char.unicodeScalars.first,
           scalar >= "a" && scalar <= "z" {
            key = char
            displayText = char.uppercased()
        } else {
            // Invalid character - reset to current key
            displayText = key.lowercased() == "space" ? "Space" : key.uppercased()
        }
    }
}

#Preview {
    ContentView()
}
