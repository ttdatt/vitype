//
//  main.swift
//  ViType
//
//  IMK entry point — creates IMKServer and runs the application.
//

import Cocoa
import Carbon
import InputMethodKit

// Register default values early
UserDefaults.standard.register(defaults: [
    "autoFixTone": true,
    "freeTonePlacement": false,
    "inputMethod": 0,
    "outputEncoding": 0,
    "tonePlacement": 0,
])

// Register this input source with macOS on first launch
// This is required for macOS to discover the input method
if let bundleURL = Bundle.main.bundleURL as CFURL? {
    let status = TISRegisterInputSource(bundleURL)
    if status != noErr {
        NSLog("ViType: TISRegisterInputSource returned \(status)")
    }
}

// Connection name must match InputMethodConnectionName in Info.plist
let kConnectionName = "ViType_Connection"

guard let server = IMKServer(name: kConnectionName,
                             bundleIdentifier: Bundle.main.bundleIdentifier!) else {
    NSLog("ViType: Failed to initialize IMKServer")
    exit(1)
}

// Keep a strong reference so the server lives for the app's lifetime
_ = server

NSApplication.shared.run()
