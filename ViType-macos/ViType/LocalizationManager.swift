//
//  LocalizationManager.swift
//  ViType
//
//  Created by Tran Dat on 30/12/24.
//

import SwiftUI
import Combine

/// Supported languages in the app
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case vietnamese = "vi"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .vietnamese:
            return "Tiếng Việt"
        }
    }
}

/// Manages in-app language selection and provides localized strings
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    static let languageKey = "appLanguage"
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.languageKey)
            updateBundle()
            // Post notification for non-SwiftUI components (e.g., MenuBarManager)
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }
    
    private(set) var bundle: Bundle = .main
    
    private init() {
        // Load saved language or default to English
        let savedLanguage = UserDefaults.standard.string(forKey: Self.languageKey) ?? "en"
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .english
        updateBundle()
    }
    
    private func updateBundle() {
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            // Fallback to main bundle
            self.bundle = .main
        }
    }
    
    /// Get localized string for a given key
    func localizedString(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    /// Get localized string with format arguments
    func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - String Extension for Localization

extension String {
    /// Returns localized string using LocalizationManager
    func localized() -> String {
        return LocalizationManager.shared.localizedString(self)
    }
    
    /// Returns localized string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localizedString(self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Injects LocalizationManager as environment object
    func withLocalization() -> some View {
        self.environmentObject(LocalizationManager.shared)
    }
}

// MARK: - Localized Text View

/// A Text view that automatically updates when language changes
struct LocalizedText: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let key: String
    let arguments: [CVarArg]
    
    init(_ key: String, _ arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }
    
    var body: some View {
        if arguments.isEmpty {
            Text(localizationManager.localizedString(key))
        } else {
            Text(localizationManager.localizedString(key, arguments))
        }
    }
}

// Helper to use CVarArg array
extension LocalizationManager {
    func localizedString(_ key: String, _ arguments: [CVarArg]) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        if arguments.isEmpty {
            return format
        }
        return String(format: format, arguments: arguments)
    }
}
