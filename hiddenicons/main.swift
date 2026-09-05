//
//  main.swift
//  hiddenicons
//
//  Created by Jakub Gradzewicz on 05/09/2026.
//

import AppKit

// Hand-rolled AppKit bootstrap instead of the SwiftUI app lifecycle: this app
// has no windows and lives entirely in the status bar, so keeping the SwiftUI
// runtime (and its transitive frameworks) out of the process is a large part
// of why the memory footprint stays a few tens of MB.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
