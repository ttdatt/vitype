//
//  GeneralSettingsView.swift
//  ViType
//
//  Created by Tran Dat on 30/12/24.
//

import SwiftUI
import Combine

// MARK: - Shortcut Recorder

/// Captures key combinations by pressing and holding for 2 seconds.
final class ShortcutRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var holdProgress: Double = 0
    @Published var currentModifiers: NSEvent.ModifierFlags = []
    @Published var currentKey: String?

    var onSave: ((NSEvent.ModifierFlags, String?) -> Void)?

    private var eventMonitors: [Any] = []
    private var holdTimer: Timer?
    private var progressTimer: Timer?
    private let holdDuration: TimeInterval = 1.0

    private static let keyCodeMap: [UInt16: String] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f", 5: "g", 4: "h",
        34: "i", 38: "j", 40: "k", 37: "l", 46: "m", 45: "n", 31: "o", 35: "p",
        12: "q", 15: "r", 1: "s", 17: "t", 32: "u", 9: "v", 13: "w", 7: "x",
        16: "y", 6: "z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
        26: "7", 28: "8", 25: "9",
        33: "[", 30: "]", 42: "\\", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 50: "`",
        49: "space"
    ]

    var displayString: String {
        var parts: [String] = []
        if currentModifiers.contains(.control) { parts.append("⌃") }
        if currentModifiers.contains(.option) { parts.append("⌥") }
        if currentModifiers.contains(.command) { parts.append("⌘") }
        if currentModifiers.contains(.shift) { parts.append("⇧") }
        if let key = currentKey {
            parts.append(key.lowercased() == "space" ? "Space".localized() : key.uppercased())
        }
        return parts.isEmpty ? "…" : parts.joined()
    }

    func startRecording() {
        isRecording = true
        holdProgress = 0
        currentModifiers = []
        currentKey = nil
        AppExclusion.isRecordingShortcut = true

        let keyMon = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return nil
        }
        let keyUpMon = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleKeyUp(event)
            return nil
        }
        let flagsMon = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        eventMonitors = [keyMon, keyUpMon, flagsMon].compactMap { $0 }
    }

    func stopRecording() {
        isRecording = false
        holdProgress = 0
        cancelTimers()
        AppExclusion.isRecordingShortcut = false

        for mon in eventMonitors { NSEvent.removeMonitor(mon) }
        eventMonitors.removeAll()
    }

    private func cancelTimers() {
        holdTimer?.invalidate(); holdTimer = nil
        progressTimer?.invalidate(); progressTimer = nil
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 { stopRecording(); return } // Escape
        if event.isARepeat { return }
        guard let keyString = Self.keyCodeMap[event.keyCode] else { return }

        let mods = event.modifierFlags.intersection([.control, .option, .command, .shift])
        if mods != currentModifiers || keyString != currentKey {
            currentModifiers = mods
            currentKey = keyString
            startHoldTimer()
        }
    }

    private func handleKeyUp(_ event: NSEvent) {
        if let key = currentKey, Self.keyCodeMap[event.keyCode] == key {
            cancelTimers()
            holdProgress = 0
            currentKey = nil  // Allow re-pressing the same key
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection([.control, .option, .command, .shift])
        if mods.isEmpty && currentKey == nil {
            cancelTimers(); holdProgress = 0; currentModifiers = []; return
        }
        if currentKey == nil && !mods.isEmpty && mods != currentModifiers {
            currentModifiers = mods
            startHoldTimer()
        }
    }

    private func startHoldTimer() {
        cancelTimers(); holdProgress = 0
        let start = Date()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.holdProgress = min(Date().timeIntervalSince(start) / self.holdDuration, 1.0)
        }
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.holdProgress = 1.0
            guard !self.currentModifiers.isEmpty else { self.stopRecording(); return }
            self.onSave?(self.currentModifiers, self.currentKey)
            self.stopRecording()
        }
    }
}

struct ShortcutRecorderView: View {
    @Binding var shortcutKey: String
    @Binding var shortcutCommand: Bool
    @Binding var shortcutOption: Bool
    @Binding var shortcutControl: Bool
    @Binding var shortcutShift: Bool

    @StateObject private var recorder = ShortcutRecorder()

    private var currentDisplay: String {
        var parts: [String] = []
        if shortcutControl { parts.append("⌃") }
        if shortcutOption { parts.append("⌥") }
        if shortcutCommand { parts.append("⌘") }
        if shortcutShift { parts.append("⇧") }
        if !shortcutKey.isEmpty {
            parts.append(shortcutKey.lowercased() == "space" ? "Space".localized() : shortcutKey.uppercased())
        }
        return parts.isEmpty ? "—" : parts.joined()
    }

    var body: some View {
        HStack(spacing: 8) {
            if recorder.isRecording {
                HStack(spacing: 6) {
                    Text(recorder.displayString)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .frame(minWidth: 40)

                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: recorder.holdProgress)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 14, height: 14)
                    .animation(.linear(duration: 0.04), value: recorder.holdProgress)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.5)))
                )

                Button("Shortcut Cancel".localized()) { recorder.stopRecording() }
                    .font(.caption)
            } else {
                Text(currentDisplay)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                    )

                Button("Shortcut Record".localized()) { recorder.startRecording() }
                    .font(.caption)
            }
        }
        .onAppear {
            recorder.onSave = { mods, key in
                shortcutControl = mods.contains(.control)
                shortcutOption = mods.contains(.option)
                shortcutCommand = mods.contains(.command)
                shortcutShift = mods.contains(.shift)
                shortcutKey = key ?? ""
            }
        }
        .onDisappear { recorder.stopRecording() }
    }
}

// MARK: - General Settings View

struct GeneralSettingsView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @Binding var viTypeEnabled: Bool
    @Binding var shortcutKey: String
    @Binding var shortcutCommand: Bool
    @Binding var shortcutOption: Bool
    @Binding var shortcutControl: Bool
    @Binding var shortcutShift: Bool
    @Binding var inputMethod: Int
    @Binding var tonePlacement: Int
    @Binding var autoFixTone: Bool
    @Binding var freeTonePlacement: Bool
    @Binding var outputEncoding: Int
    @Binding var playSoundOnToggle: Bool

    @State private var launchAtLoginEnabled = LaunchAtLoginManager.isOnForToggle

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
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Keyboard shortcut
            VStack(alignment: .leading, spacing: 8) {
                Text("Toggle Shortcut:".localized())
                    .font(.caption).foregroundColor(.secondary)

                ShortcutRecorderView(
                    shortcutKey: $shortcutKey,
                    shortcutCommand: $shortcutCommand,
                    shortcutOption: $shortcutOption,
                    shortcutControl: $shortcutControl,
                    shortcutShift: $shortcutShift
                )

                Text("Shortcut Record Help".localized())
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Play Sound on Toggle".localized(), isOn: $playSoundOnToggle)
                    .padding(.top, 4)
                Text("Play Sound on Toggle Help".localized())
                    .font(.caption).foregroundColor(.secondary)
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
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Tone Placement
            VStack(alignment: .leading, spacing: 4) {
                Picker("Tone Placement:".localized(), selection: $tonePlacement) {
                    Text("Orthographic".localized()).tag(0)
                    Text("Nucleus Only".localized()).tag(1)
                }
                .pickerStyle(.menu)
                Text("Tone Placement Help".localized())
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Auto Fix Tone
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Auto Fix Tone".localized(), isOn: $autoFixTone)
                Text("Auto Fix Tone Help".localized())
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Free Tone Placement
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Free Tone Placement".localized(), isOn: $freeTonePlacement)
                Text("Free Tone Placement Help".localized())
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Character Encoding
            VStack(alignment: .leading, spacing: 4) {
                Picker("Character Encoding:".localized(), selection: $outputEncoding) {
                    Text("Unicode".localized()).tag(0)
                    Text("Composite Unicode".localized()).tag(1)
                }
                .pickerStyle(.menu)
                Text("Character Encoding Help".localized())
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Start at Login
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Start at Login".localized(), isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { _, newValue in
                        do { try LaunchAtLoginManager.setOn(newValue) }
                        catch { launchAtLoginEnabled = LaunchAtLoginManager.isOnForToggle }
                        launchAtLoginEnabled = LaunchAtLoginManager.isOnForToggle
                    }

                if LaunchAtLoginManager.state == .requiresApproval {
                    Text("Approval required in System Settings…".localized())
                        .font(.caption).foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Start at Login Help".localized())
                        .font(.caption).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { launchAtLoginEnabled = LaunchAtLoginManager.isOnForToggle }
    }
}

#Preview {
    GeneralSettingsView(
        viTypeEnabled: .constant(true),
        shortcutKey: .constant("x"),
        shortcutCommand: .constant(false),
        shortcutOption: .constant(false),
        shortcutControl: .constant(true),
        shortcutShift: .constant(false),
        inputMethod: .constant(0),
        tonePlacement: .constant(0),
        autoFixTone: .constant(true),
        freeTonePlacement: .constant(false),
        outputEncoding: .constant(0),
        playSoundOnToggle: .constant(true)
    )
    .padding()
    .frame(width: 400, height: 300)
}
