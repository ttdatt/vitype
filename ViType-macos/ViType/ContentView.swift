//
//  ContentView.swift
//  ViType
//
//  Created by Tran Dat on 24/12/25.
//

import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general
    case appExclusion

    func localizedName() -> String {
        switch self {
        case .general:
            return "General".localized()
        case .appExclusion:
            return "App Exclusion".localized()
        }
    }
}

struct ContentView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var windowManager = WindowManager.shared
    @State private var selectedTab: SettingsTab = .general

    @AppStorage("autoFixTone") private var autoFixTone = true
    @AppStorage("freeTonePlacement") private var freeTonePlacement = false
    @AppStorage("inputMethod") private var inputMethod = 0
    @AppStorage("outputEncoding") private var outputEncoding = 0
    @AppStorage("tonePlacement") private var tonePlacement = 0
    @AppStorage(AppExclusion.isEnabledKey) private var appExclusionEnabled = true
    @AppStorage(AppExclusion.excludedBundleIDsKey) private var excludedBundleIDsText = ""
    @AppStorage(AppExclusion.viTypeEnabledKey) private var viTypeEnabled = true

    // Shortcut settings
    @AppStorage(AppExclusion.shortcutKeyKey) private var shortcutKey = "x"
    @AppStorage(AppExclusion.shortcutCommandKey) private var shortcutCommand = false
    @AppStorage(AppExclusion.shortcutOptionKey) private var shortcutOption = false
    @AppStorage(AppExclusion.shortcutControlKey) private var shortcutControl = true
    @AppStorage(AppExclusion.shortcutShiftKey) private var shortcutShift = false
    @AppStorage(AppExclusion.playSoundOnToggleKey) private var playSoundOnToggle = true

    @StateObject private var frontmostAppMonitor = FrontmostAppMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ViType")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Vietnamese Input Method".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.localizedName()).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            ScrollView {
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
                            tonePlacement: $tonePlacement,
                            autoFixTone: $autoFixTone,
                            freeTonePlacement: $freeTonePlacement,
                            outputEncoding: $outputEncoding,
                            playSoundOnToggle: $playSoundOnToggle
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
        }
        .padding()
        .frame(width: 420)
        .onChange(of: windowManager.requestedTab) { _, newTab in
            if let tab = newTab {
                selectedTab = tab
                windowManager.requestedTab = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
