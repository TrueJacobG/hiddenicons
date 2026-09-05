//
//  MenuBarController.swift
//  hiddenicons
//
//  Created by Jakub Gradzewicz on 05/09/2026.
//

import AppKit

/// Coordinates the two status items that make the hide/show trick work.
///
/// The user sees a single chevron; right next to it sits an invisible
/// separator item (a few points wide, no icon). Collapsing inflates the
/// separator's length to roughly twice the widest attached display, which
/// pushes everything to its left off the screen. The chevron sits to the
/// separator's right and is never resized, so it always stays visible and
/// one more click brings the bar back. macOS caps `NSStatusItem.length` at
/// 10,000pt, hence the upper bound on this value.
///
/// macOS gives no control over where a new status item is inserted, so the
/// roles are not tied to creation order: after launch (and before every
/// collapse) both items are measured and whichever sits further left becomes
/// the separator. The arrangement is therefore correct by construction.
final class MenuBarController {

    // MARK: Constants

    /// Resting width of the separator. Imageless and this small it is
    /// invisible — the gap it leaves reads as normal icon spacing.
    private static let separatorRestLength: CGFloat = 4

    /// How long the bar stays expanded before auto-collapsing (if enabled).
    private static let autoCollapseInterval: TimeInterval = 30

    // MARK: Status items

    private let itemA = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let itemB = NSStatusBar.system.statusItem(withLength: MenuBarController.separatorRestLength)

    /// The item showing the chevron and handling clicks. Provisionally itemA
    /// until the first measurement, in case the roles need to swap.
    private var chevronItem: NSStatusItem

    /// The blank item that gets inflated on collapse.
    private var separatorItem: NSStatusItem

    // MARK: State

    private(set) var isCollapsed = false

    /// Inflated separator length, recomputed whenever screens change.
    private var collapsedLength: CGFloat = 2_000

    /// Debounces rapid clicking so layout can settle between toggles.
    private var isToggling = false

    private var autoCollapseTimer: Timer?

    // MARK: Setup

    init() {
        chevronItem = itemA
        separatorItem = itemB
        configureAutosaveNames()
        applyRoles()

        // A display sleep/wake or hot-plug can change the widest screen, so
        // the collapsed length has to be recomputed and re-applied.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Measures both items and makes sure the left one acts as the separator.
    /// Call once the status item windows are on screen (shortly after launch).
    func syncRoles() {
        guard let aX = screenX(of: itemA), let bX = screenX(of: itemB) else { return }
        let newChevron = aX <= bX ? itemB : itemA
        guard newChevron !== chevronItem else { return }

        NSLog("hiddenicons: status items were inserted inverted — swapping roles")
        chevronItem = newChevron
        separatorItem = newChevron === itemA ? itemB : itemA
        applyRoles()
    }

    /// Applies look, click handling and resting lengths to the current roles.
    private func applyRoles() {
        if let button = chevronItem.button {
            button.image = NSImage(
                systemSymbolName: isCollapsed ? "chevron.right" : "chevron.left",
                accessibilityDescription: isCollapsed ? "Show menu bar icons" : "Hide menu bar icons"
            )
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if let button = separatorItem.button {
            // Deliberately no image and no action: the separator stays
            // invisible and fully inert. It exists only to be inflated.
            button.image = nil
            button.target = nil
            button.action = nil
        }

        chevronItem.length = NSStatusItem.variableLength
        separatorItem.length = isCollapsed ? collapsedLength : Self.separatorRestLength
    }

    private func configureAutosaveNames() {
        // Autosaved names let macOS remember ⌘-dragged positions across
        // launches. ⌘-dragging an item off the bar is persisted too, which
        // would leave the app running but unreachable — making both items
        // visible again on every launch self-heals that.
        itemA.autosaveName = "HI_itemA"
        itemA.isVisible = true
        itemB.autosaveName = "HI_itemB"
        itemB.isVisible = true
    }

    // MARK: Toggle

    /// Collapses the bar (hides the icons to the left of the separator).
    func collapse() {
        guard !isCollapsed else { return }
        syncRoles()
        guard let chevronX = screenX(of: chevronItem), let separatorX = screenX(of: separatorItem),
              chevronX >= separatorX else {
            NSLog("hiddenicons: collapse postponed — status items not measurable yet, try again")
            return
        }
        stopAutoCollapseTimer()
        isCollapsed = true
        separatorItem.length = collapsedLength
        refreshControlImage()
    }

    /// Expands the bar (brings the hidden icons back).
    func expand() {
        guard isCollapsed else { return }
        isCollapsed = false
        separatorItem.length = Self.separatorRestLength
        refreshControlImage()
        startAutoCollapseTimer()
    }

    func toggle() {
        if isToggling { return }
        isToggling = true
        if isCollapsed {
            expand()
        } else {
            collapse()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { @MainActor [weak self] in
            self?.isToggling = false
        }
    }

    // MARK: Click handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu(from: sender)
            return
        }
        toggle()
    }

    private func showMenu(from button: NSStatusBarButton) {
        // Built per invocation so the checkmarks always reflect current state.
        let menu = buildMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 5), in: button)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: isCollapsed ? "Show Menu Bar Icons" : "Hide Menu Bar Icons",
            action: #selector(toggleClicked),
            keyEquivalent: "h"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let autoCollapseItem = NSMenuItem(
            title: "Auto-Collapse After 30 Seconds",
            action: #selector(toggleAutoCollapseClicked),
            keyEquivalent: ""
        )
        autoCollapseItem.target = self
        autoCollapseItem.state = Preferences.autoCollapseEnabled ? .on : .off
        menu.addItem(autoCollapseItem)

        let startCollapsedItem = NSMenuItem(
            title: "Start Collapsed on Launch",
            action: #selector(toggleStartCollapsedClicked),
            keyEquivalent: ""
        )
        startCollapsedItem.target = self
        startCollapsedItem.state = Preferences.startCollapsed ? .on : .off
        menu.addItem(startCollapsedItem)

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLoginClicked),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Hidden Icons",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    // MARK: Menu actions

    @objc private func toggleClicked() {
        toggle()
    }

    @objc private func toggleAutoCollapseClicked() {
        Preferences.autoCollapseEnabled.toggle()
        if Preferences.autoCollapseEnabled, !isCollapsed {
            startAutoCollapseTimer()
        } else {
            stopAutoCollapseTimer()
        }
    }

    @objc private func toggleStartCollapsedClicked() {
        Preferences.startCollapsed.toggle()
    }

    @objc private func toggleLaunchAtLoginClicked() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
    }

    // MARK: Auto-collapse

    private func startAutoCollapseTimer() {
        stopAutoCollapseTimer()
        guard Preferences.autoCollapseEnabled, !isCollapsed else { return }
        autoCollapseTimer = Timer.scheduledTimer(
            withTimeInterval: Self.autoCollapseInterval,
            repeats: false
        ) { [weak self] _ in
            // Timers created here fire on the main run loop, so main-actor
            // isolation is guaranteed even though the block type isn't.
            MainActor.assumeIsolated {
                guard let self, Preferences.autoCollapseEnabled, !self.isCollapsed else { return }
                // Don't yank the bar closed while the pointer rests on the menu bar.
                if Self.isMouseInMenuBar() {
                    self.startAutoCollapseTimer()
                } else {
                    self.collapse()
                }
            }
        }
    }

    private func stopAutoCollapseTimer() {
        autoCollapseTimer?.invalidate()
        autoCollapseTimer = nil
    }

    /// True while the pointer sits in any screen's menu bar band. On fullscreen
    /// spaces the menu bar is hidden, so the band collapses to ~zero and this
    /// returns false — intentionally, since there is nothing to protect there.
    private static func isMouseInMenuBar() -> Bool {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            mouse.x >= screen.frame.minX
                && mouse.x <= screen.frame.maxX
                && mouse.y >= screen.visibleFrame.maxY
                && mouse.y <= screen.frame.maxY
        }
    }

    // MARK: Geometry

    /// Screen-space x of an item's button. Measured via the button (not
    /// `window.frame`) so the reading stays correct regardless of how macOS
    /// shapes the backing windows.
    private func screenX(of item: NSStatusItem) -> CGFloat? {
        guard let button = item.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).minX
    }

    private func updateCollapsedLength() {
        // The menu bar replicates across every attached display, so the
        // collapsed length must cover the widest screen, not just the
        // focused one — sizing from a narrower screen leaks icons on
        // wider displays.
        let widestScreen = NSScreen.screens.map(\.frame.width).max() ?? 1_728
        collapsedLength = max(500, min(widestScreen * 2, 10_000))
        if isCollapsed {
            separatorItem.length = collapsedLength
        }
    }

    @objc private func screenParametersChanged() {
        updateCollapsedLength()
    }

    // MARK: Appearance

    private func refreshControlImage() {
        guard let button = chevronItem.button else { return }
        let symbolName = isCollapsed ? "chevron.right" : "chevron.left"
        let description = isCollapsed ? "Show menu bar icons" : "Hide menu bar icons"
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
    }
}
