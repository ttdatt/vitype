//
//  LaunchAtLoginManager.swift
//  ViType
//
//  Created by ViType on 29/12/25.
//

import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    enum State: Equatable {
        case disabled
        case enabled
        case requiresApproval
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        default:
            // Covers .notRegistered and any future statuses we don't explicitly handle.
            return .disabled
        }
    }

    static var isOnForToggle: Bool {
        switch state {
        case .enabled, .requiresApproval:
            return true
        case .disabled:
            return false
        }
    }

    static func setOn(_ isOn: Bool) throws {
        if isOn {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}


