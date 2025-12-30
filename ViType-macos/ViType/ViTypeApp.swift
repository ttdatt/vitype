//
//  ViTypeApp.swift
//  ViType
//
//  Created by Tran Dat on 26/12/25.
//

import SwiftUI

@main
struct ViTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some Scene {
        Window("ViType Settings".localized(), id: "settings") {
            ContentView()
                .injectWindowManager()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
