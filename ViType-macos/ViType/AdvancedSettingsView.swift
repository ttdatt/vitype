//
//  AdvancedSettingsView.swift
//  ViType
//
//  Created by Tran Dat on 30/12/24.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @Binding var outputEncoding: Int
    @Binding var useAXGhostSuggestion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Character Encoding
            VStack(alignment: .leading, spacing: 4) {
                Picker("Character Encoding:", selection: $outputEncoding) {
                    Text("Unicode").tag(0)
                    Text("Composite Unicode").tag(1)
                }
                .pickerStyle(.menu)

                Text("Unicode uses precomposed characters (default). Composite Unicode uses decomposed characters (NFD).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Accessibility API
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Use Accessibility API", isOn: $useAXGhostSuggestion)

                Text("Enable AX-based detection to avoid browser suggestion conflicts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    AdvancedSettingsView(
        outputEncoding: .constant(0),
        useAXGhostSuggestion: .constant(true)
    )
    .padding()
    .frame(width: 400, height: 300)
}
