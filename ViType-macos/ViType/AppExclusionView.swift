//
//  AppExclusionView.swift
//  ViType
//
//  Created by Tran Dat on 30/12/24.
//

import SwiftUI

struct AppExclusionView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @Binding var appExclusionEnabled: Bool
    @Binding var excludedBundleIDsText: String
    
    @ObservedObject var frontmostAppMonitor: FrontmostAppMonitor

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
        return current == viTypeBundleID ? "Add Previous App".localized() : "Add Current App".localized()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // App Exclusion Toggle
            VStack(alignment: .leading, spacing: 4) {
                Toggle("App Exclusion Toggle".localized(), isOn: $appExclusionEnabled)

                Text("Disable ViType when these apps are focused (bundle IDs, one per line or comma-separated):".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Text Editor for bundle IDs
            TextEditor(text: $excludedBundleIDsText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 96)
                .disabled(!appExclusionEnabled)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.secondary.opacity(0.25))
                )

            // Current/Previous app info and Add button
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Current app:".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(frontmostAppMonitor.bundleIdentifier ?? "Unknown".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 8) {
                        Text("Previous app:".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(frontmostAppMonitor.lastNonViTypeBundleIdentifier ?? "Unknown".localized())
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

#Preview {
    AppExclusionView(
        appExclusionEnabled: .constant(true),
        excludedBundleIDsText: .constant("com.example.app"),
        frontmostAppMonitor: FrontmostAppMonitor()
    )
    .padding()
    .frame(width: 400, height: 300)
}
