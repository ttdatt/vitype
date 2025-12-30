//
//  AdvancedSettingsView.swift
//  ViType
//
//  Created by Tran Dat on 30/12/24.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @Binding var outputEncoding: Int
    @Binding var useAXGhostSuggestion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Character Encoding
            VStack(alignment: .leading, spacing: 4) {
                Picker("Character Encoding:".localized(), selection: $outputEncoding) {
                    Text("Unicode".localized()).tag(0)
                    Text("Composite Unicode".localized()).tag(1)
                }
                .pickerStyle(.menu)

                Text("Character Encoding Help".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Accessibility API
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Use Accessibility API".localized(), isOn: $useAXGhostSuggestion)

                Text("Use Accessibility API Help".localized())
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
