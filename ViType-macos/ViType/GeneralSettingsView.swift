//
//  GeneralSettingsView.swift
//  ViType
//
//  Created by Tran Dat on 30/12/24.
//

import SwiftUI

struct GeneralSettingsView: View {
    @Binding var viTypeEnabled: Bool
    @Binding var shortcutKey: String
    @Binding var shortcutCommand: Bool
    @Binding var shortcutOption: Bool
    @Binding var shortcutControl: Bool
    @Binding var shortcutShift: Bool
    @Binding var inputMethod: Int
    @Binding var autoFixTone: Bool

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
        VStack(alignment: .leading, spacing: 14) {
            // Enable ViType
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Enable ViType", isOn: $viTypeEnabled)

                Text("Toggle Vietnamese input on/off. When disabled, all keys pass through unchanged.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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

            // Input Method
            VStack(alignment: .leading, spacing: 4) {
                Picker("Input Method:", selection: $inputMethod) {
                    Text("Telex").tag(0)
                    Text("VNI").tag(1)
                }
                .pickerStyle(.menu)

                Text("Choose Telex (letters) or VNI (numbers) for Vietnamese input.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Auto Fix Tone
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Auto Fix Tone", isOn: $autoFixTone)

                Text("Automatically reposition tone marks when adding vowels.")
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
        autoFixTone: .constant(true)
    )
    .padding()
    .frame(width: 400, height: 300)
}
