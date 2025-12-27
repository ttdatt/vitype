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
    
    var body: some Scene {
        WindowGroup(id: "settings") {
            ContentView()
                .injectWindowManager()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
