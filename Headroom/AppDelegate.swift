import AppKit
import SwiftUI
import Combine
import Sparkle

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let appState = AppState()
    private var cancellables = Set<AnyCancellable>()
    private var loginWindow: NSWindow?
    private var settingsWindow: NSWindow?
    let updaterController: SPUStandardUpdaterController

    override init() {
        // Initialize Sparkle updater before app finishes launching
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the popover that drops down from the menu bar
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 420)
        popover.behavior = .transient
        rebuildPopoverContent()

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            updateStatusButton(button)
        }

        // Update menu bar text when usage, auth state, settings, or predictions change
        appState.$usage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusBar() }
            .store(in: &cancellables)

        appState.$authState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateStatusBar()
                if case .loggedIn = state {
                    self?.closeLoginWindow()
                }
            }
            .store(in: &cancellables)

        appState.settings.$menuBarFormat
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusBar() }
            .store(in: &cancellables)

        appState.settings.$menuBarEmoji
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusBar() }
            .store(in: &cancellables)

        appState.usageHistory.$predictions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusBar() }
            .store(in: &cancellables)
    }

    // MARK: - Popover

    private func rebuildPopoverContent() {
        popover.contentViewController = NSHostingController(
            rootView: UsagePopoverView(
                appState: appState,
                onLogin: { [weak self] in self?.openLoginWindow() },
                onLogout: { [weak self] in self?.appState.logout() },
                onSettings: { [weak self] in self?.openSettingsWindow() },
                onCheckForUpdates: { [weak self] in self?.updaterController.checkForUpdates(nil) }
            )
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            rebuildPopoverContent()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Task { await appState.refreshUsage() }
        }
    }

    // MARK: - Status Bar

    private func updateStatusBar() {
        guard let button = statusItem.button else { return }
        updateStatusButton(button)
    }

    private func updateStatusButton(_ button: NSStatusBarButton) {
        let title = appState.menuBarTitle
        button.title = title
        button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
    }

    // MARK: - Login Window

    func openLoginWindow() {
        popover.performClose(nil)

        if let window = loginWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let loginView = LoginWebView { [weak self] sessionKey in
            Task { @MainActor in
                await self?.appState.loginCompleted(sessionKey: sessionKey)
            }
        }

        let hostingView = NSHostingView(rootView: loginView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in to Claude.ai"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        self.loginWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeLoginWindow() {
        loginWindow?.close()
        loginWindow = nil
    }

    // MARK: - Settings Window

    func openSettingsWindow() {
        popover.performClose(nil)

        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            settings: appState.settings,
            appState: appState,
            onDismiss: { [weak self] in
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
            }
        )

        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Headroom Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
