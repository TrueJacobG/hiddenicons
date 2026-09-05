//
//  Preferences.swift
//  hiddenicons
//
//  Created by Jakub Gradzewicz on 05/09/2026.
//

import Foundation

/// The app's two toggles, backed by UserDefaults. Kept deliberately tiny —
/// no bindings, no observers, just typed accessors.
enum Preferences {
    private static let startCollapsedKey = "startCollapsed"
    private static let autoCollapseEnabledKey = "autoCollapseEnabled"

    /// Whether the bar should collapse on its own about a second after launch.
    static var startCollapsed: Bool {
        get { UserDefaults.standard.object(forKey: startCollapsedKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: startCollapsedKey) }
    }

    /// Whether the bar should collapse again 30 seconds after expanding.
    static var autoCollapseEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: autoCollapseEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoCollapseEnabledKey) }
    }
}
