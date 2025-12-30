//
//  GeneralSettingsView.swift
//  ViType
//
//  Created by Tran Dat on 30/12/24.
//

import SwiftUI

struct GeneralSettingsView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @Binding var viTypeEnabled: Bool
    @Binding var shortcutKey: String
    @Binding var shortcutCommand: Bool
    @Binding var shortcutOption: Bool
    @Binding var shortcutControl: Bool
    @Binding var shortcutShift: Bool
    @Binding var inputMethod: Int
    @Binding var autoFixTone: Bool
    @Binding var playSoundOnToggle: Bool

    private var shortcutDisplayString: String {
        var parts: [String] = []
        if shortcutControl { parts.append("^") }
        if shortcutOption { parts.append("\u{2325}") }
        if shortcutCommand { parts.append("\u{2318}") }
        if shortcutShift { parts.append("\u{21E7}") }

        let keyDisplay = shortcutKey.lowercased() == "space" ? "Space".localized() : shortcutKey.uppercased()
        parts.append(keyDisplay)

        return parts.joined()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Language Selector
            VStack(alignment: .leading, spacing: 4) {
                Picker("Language:".localized(), selection: $localizationManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            // Enable ViType
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Enable ViType".localized(), isOn: $viTypeEnabled)

                Text("Enable ViType Help".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Keyboard shortcut settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Toggle Shortcut:".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Toggle("Control".localized(), isOn: $shortcutControl)
                        .toggleStyle(.checkbox)
                    Toggle("Option".localized(), isOn: $shortcutOption)
                        .toggleStyle(.checkbox)
                    Toggle("Command".localized(), isOn: $shortcutCommand)
                        .toggleStyle(.checkbox)
                    Toggle("Shift".localized(), isOn: $shortcutShift)
                        .toggleStyle(.checkbox)
                }
                .font(.caption)

                HStack(spacing: 8) {
                    Text("Key:".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ShortcutKeyField(key: $shortcutKey)
                        .frame(width: 60)

                    Text(shortcutDisplayString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
                
                // Play sound on toggle
                Toggle("Play Sound on Toggle".localized(), isOn: $playSoundOnToggle)
                    .padding(.top, 4)
                
                Text("Play Sound on Toggle Help".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 20)

            Divider()

            // Input Method
            VStack(alignment: .leading, spacing: 4) {
                Picker("Input Method:".localized(), selection: $inputMethod) {
                    Text("Telex").tag(0)
                    Text("VNI").tag(1)
                }
                .pickerStyle(.menu)

                Text("Input Method Help".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Auto Fix Tone
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Auto Fix Tone".localized(), isOn: $autoFixTone)

                Text("Auto Fix Tone Help".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    GeneralSettingsView(
        viTypeEnabled: .constant(true),
        shortcutKey: .constant("space"),
        shortcutCommand: .constant(false),
        shortcutOption: .constant(false),
        shortcutControl: .constant(true),
        shortcutShift: .constant(false),
        inputMethod: .constant(0),
        autoFixTone: .constant(true),
        playSoundOnToggle: .constant(true)
    )
    .padding()
    .frame(width: 400, height: 300)
}
