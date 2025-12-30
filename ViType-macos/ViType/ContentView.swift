//
//  ContentView.swift
//  ViType
//
//  Created by Tran Dat on 24/12/25.
//

import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general
    case advanced
    case appExclusion
    
    func localizedName() -> String {
        switch self {
        case .general:
            return "General".localized()
        case .advanced:
            return "Advanced".localized()
        case .appExclusion:
            return "App Exclusion".localized()
        }
    }
}

struct ContentView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var selectedTab: SettingsTab = .general

    @AppStorage("autoFixTone") private var autoFixTone = true
    @AppStorage("inputMethod") private var inputMethod = 0
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
    @AppStorage(AppExclusion.playSoundOnToggleKey) private var playSoundOnToggle = true

    @StateObject private var frontmostAppMonitor = FrontmostAppMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header - always visible
            VStack(alignment: .leading, spacing: 4) {
                Text("ViType")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Vietnamese Input Method".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Segmented control for tabs
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.localizedName()).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(
                        viTypeEnabled: $viTypeEnabled,
                        shortcutKey: $shortcutKey,
                        shortcutCommand: $shortcutCommand,
                        shortcutOption: $shortcutOption,
                        shortcutControl: $shortcutControl,
                        shortcutShift: $shortcutShift,
                        inputMethod: $inputMethod,
                        autoFixTone: $autoFixTone,
                        playSoundOnToggle: $playSoundOnToggle
                    )

                case .advanced:
                    AdvancedSettingsView(
                        outputEncoding: $outputEncoding,
                        useAXGhostSuggestion: $useAXGhostSuggestion
                    )

                case .appExclusion:
                    AppExclusionView(
                        appExclusionEnabled: $appExclusionEnabled,
                        excludedBundleIDsText: $excludedBundleIDsText,
                        frontmostAppMonitor: frontmostAppMonitor
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(width: 420)
        .id(localizationManager.currentLanguage) // Force refresh when language changes
    }
}

// Custom text field that only accepts a single character (a-z) or "space"
struct ShortcutKeyField: View {
    @Binding var key: String
    @State private var displayText: String = ""
    @StateObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        TextField("", text: $displayText)
            .textFieldStyle(.roundedBorder)
            .onAppear {
                displayText = key.lowercased() == "space" ? "Space".localized() : key.uppercased()
            }
            .onChange(of: displayText) { _, newValue in
                processInput(newValue)
            }
            .onChange(of: localizationManager.currentLanguage) { _, _ in
                // Update display when language changes
                displayText = key.lowercased() == "space" ? "Space".localized() : key.uppercased()
            }
    }

    private func processInput(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let spaceLocalized = "Space".localized()

        // Check for "space" typed out (in either language)
        if trimmed.lowercased() == "space" || trimmed == spaceLocalized {
            key = "space"
            displayText = spaceLocalized
            return
        }

        // If user types a space character
        if input.contains(" ") {
            key = "space"
            displayText = spaceLocalized
            return
        }

        // Take only the last character if multiple are entered
        guard let lastChar = trimmed.last else {
            // Empty input - reset to current key
            displayText = key.lowercased() == "space" ? spaceLocalized : key.uppercased()
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
            displayText = key.lowercased() == "space" ? spaceLocalized : key.uppercased()
        }
    }
}

#Preview {
    ContentView()
}
