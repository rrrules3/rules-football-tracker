//
//  AppDelegate.swift
//  Testing overlay football
//
//  Created by Rohan Rajesh on 08/04/26.
//

import AppKit
import SwiftUI
import SwiftData

extension Notification.Name {
    static let navigateToSettings = Notification.Name("navigateToSettings")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var onboardingWindow: NSWindow?
    private var mainAppWindow: NSWindow?
    private var pulseTimer: Timer?
    private var isPulseOn = true

    var modelContainer: ModelContainer!
    var matchMonitor: MatchMonitor!
    var overlayManager: OverlayManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply stored appearance preference before any windows appear
        if let stored = UserDefaults.standard.string(forKey: "appAppearance"),
           let mode = AppAppearance(rawValue: stored) {
            NSApp.appearance = mode.nsAppearance
        }

        // Set up SwiftData
        let schema = Schema([FavoriteTeam.self, FavoriteLeague.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        modelContainer = try! ModelContainer(for: schema, configurations: [config])

        // Store API key if not already set
        if KeychainHelper.getAPIKey() == nil {
            KeychainHelper.saveAPIKey("c7c8a4e580718f8a98ffdf77080a404c")
        }

        // Set up notifications
        NotificationManager.shared.requestPermission()

        // Set up MatchMonitor and OverlayManager
        matchMonitor = MatchMonitor(modelContainer: modelContainer)
        overlayManager = OverlayManager()

        // Handle "Watch Live" notification tap
        NotificationManager.shared.onWatchLive = { [weak self] fixtureID in
            guard let self = self else { return }
            // Find the match in today's fixtures and open overlay
            let allMatches = self.matchMonitor.leagueGroups.flatMap(\.matches) + self.matchMonitor.liveMatches
            if let match = allMatches.first(where: { $0.id == fixtureID }) {
                self.overlayManager.openOverlay(for: match)
            }
        }

        // Close any default windows
        for window in NSApplication.shared.windows {
            window.close()
        }

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "⚽"
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create the popover with our menu bar view
        let menuBarView = MenuBarView(
            matchMonitor: matchMonitor,
            overlayManager: overlayManager,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onOpenFullApp: { [weak self] in self?.openFullApp() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        .modelContainer(modelContainer)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: menuBarView)

        // Show onboarding on first launch
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        }

        // Start background monitoring with overlay updates
        matchMonitor.overlayManager = overlayManager
        overlayManager.matchMonitor = matchMonitor
        matchMonitor.startMonitoring()

        // Pulse the menu bar icon when live matches exist
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.updateMenuBarPulse()
            }
        }
    }

    private func updateMenuBarPulse() {
        guard let button = statusItem?.button else { return }
        let hasLive = !matchMonitor.liveMatches.isEmpty || !overlayManager.activeMatches.isEmpty

        if hasLive {
            isPulseOn.toggle()
            button.title = isPulseOn ? "⚽" : "🔴"
        } else {
            isPulseOn = true
            button.title = "⚽"
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Main App Window

    func openFullApp() {
        popover.performClose(nil)

        if let existing = mainAppWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let view = MainAppView(matchMonitor: matchMonitor, overlayManager: overlayManager)
            .modelContainer(modelContainer)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Football"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: 800, height: 500)
        window.contentViewController = NSHostingController(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        mainAppWindow = window
    }

    // MARK: - Settings Window

    func openSettings() {
        // Open the main app and switch to the Settings tab
        openFullApp()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .navigateToSettings, object: nil)
        }
    }

    // MARK: - Onboarding Window

    private func showOnboarding() {
        let onboardingView = OnboardingView {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
        }
        .modelContainer(modelContainer)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Football Overlay"
        window.contentViewController = NSHostingController(rootView: onboardingView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
