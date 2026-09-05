//
//  LoginItem.swift
//  hiddenicons
//
//  Created by Jakub Gradzewicz on 05/09/2026.
//

import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService for the "Launch at Login" toggle.
enum LoginItem {

    static var isEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LoginItem: failed to \(enabled ? "register" : "unregister"): \(error)")
        }
    }
}
