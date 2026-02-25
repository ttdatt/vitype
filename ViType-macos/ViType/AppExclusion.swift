//
//  AppExclusion.swift
//  ViType
//
//  Created by Tran Dat on 24/12/25.
//

import Foundation

enum AppExclusion {
    static let isEnabledKey = "enableAppExclusion"
    static let excludedBundleIDsKey = "excludedBundleIDs"

    // Global enable/disable toggle
    static let viTypeEnabledKey = "viTypeEnabled"

    // Keyboard shortcut settings
    static let shortcutKeyKey = "shortcutKey"              // Single character (a-z, 0-9, []`\;',./, or "space")
    static let shortcutCommandKey = "shortcutCommand"      // Cmd modifier
    static let shortcutOptionKey = "shortcutOption"        // Option modifier
    static let shortcutControlKey = "shortcutControl"      // Control modifier
    static let shortcutShiftKey = "shortcutShift"          // Shift modifier

    // Sound feedback settings
    static let playSoundOnToggleKey = "playSoundOnToggle"

    // Set to true while the shortcut recorder is active so the CGEvent tap passes events through
    static var isRecordingShortcut = false

    static func normalizeBundleID(_ bundleID: String) -> String {
        bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Parses a user-provided list of bundle IDs.
    /// - Supported separators: newline and comma
    /// - Ignores empty entries and `#` comment lines
    static func parseBundleIDList(_ text: String) -> Set<String> {
        var result: Set<String> = []

        for raw in text.split(whereSeparator: { $0 == "\n" || $0 == "," }) {
            let trimmed = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !trimmed.hasPrefix("#") else { continue }

            let normalized = normalizeBundleID(trimmed)
            guard !normalized.isEmpty else { continue }
            result.insert(normalized)
        }

        return result
    }
}
