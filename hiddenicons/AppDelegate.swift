//
//  AppDelegate.swift
//  hiddenicons
//
//  Created by Jakub Gradzewicz on 05/09/2026.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let menuBarController = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Give the status items a moment to lay out, then make sure the blank
        // separator is the left-hand item before any collapse can happen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            menuBarController.syncRoles()
            guard Preferences.startCollapsed else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.menuBarController.collapse()
            }
        }
    }
}
