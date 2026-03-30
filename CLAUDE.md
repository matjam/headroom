# CLAUDE.md

This file provides context for AI assistants working on this codebase.

## What is Headroom?

Headroom is a native macOS menu bar app that monitors Claude.ai usage limits in real-time. It shows session and weekly utilization in the menu bar, with a popover for detailed breakdowns including model-specific limits, extra usage spend, and predictions for when limits will be hit.

## Tech Stack

- **Language**: Swift 5.9
- **UI**: SwiftUI (popover, settings) + AppKit (NSStatusItem, NSWindow, NSPopover)
- **Minimum Target**: macOS 14.0
- **Dependencies**: Sparkle 2.9.0 (auto-updates via Swift Package Manager)
- **Build System**: xcodegen + Makefile
- **CI/CD**: GitHub Actions, release-please, Apple notarization

## Project Structure

```
Headroom/
  HeadroomApp.swift         - @main entry point, minimal (delegates to AppDelegate)
  AppDelegate.swift         - NSStatusItem, popover, window management, Sparkle updater
  AppState.swift            - Central state: auth, usage polling, refresh timer
  Models.swift              - Codable structs for the Claude.ai usage API response
  ClaudeAPIClient.swift     - HTTP client for Claude.ai API (session cookie auth)
  KeychainHelper.swift      - Secure storage for session key and org ID
  LoginWebView.swift        - WKWebView for Claude.ai OAuth login (handles Google popup)
  UsageDetailView.swift     - Popover UI: usage bars, limits, predictions, footer
  SettingsView.swift        - Settings window: format string editor, poll interval, launch at login
  Settings.swift            - AppSettings: persisted config via UserDefaults
  UsageHistory.swift        - RRD-style circular buffer + linear regression predictor
  Info.plist                - Uses $(MARKETING_VERSION) and $(CURRENT_PROJECT_VERSION) variables
  Headroom.entitlements     - com.apple.security.network.client
  Assets.xcassets/          - App icon (all sizes)

project.yml                 - xcodegen project definition
Makefile                    - Build, run, DMG creation, code signing
.github/workflows/
  ci.yml                    - Build on push/PR
  release-please.yml        - Automated releases with signing, notarization, Sparkle appcast
```

## Architecture

### App Lifecycle
- `HeadroomApp` creates an `AppDelegate` via `@NSApplicationDelegateAdaptor`
- `AppDelegate` owns the `NSStatusItem` (menu bar), `NSPopover`, and window management
- No main window; the app is `LSUIElement = true` (menu bar only)

### Authentication
- Claude.ai uses session cookies, not a public API
- `LoginWebView` opens claude.ai/login in a WKWebView
- Google OAuth popups are handled by creating a real second NSWindow with its own WKWebView (sharing the same WKWebsiteDataStore)
- The `sessionKey` cookie is captured via polling and stored in the macOS Keychain
- The session key is used to call `https://claude.ai/api/organizations/{orgId}/usage`

### Usage Data Flow
1. `AppState.refreshUsage()` calls `ClaudeAPIClient.fetchUsage(orgId:)`
2. Response is decoded into `UsageResponse` (see `Models.swift`)
3. Sample is recorded in `UsageHistory` for prediction
4. Menu bar title is resolved from the format string in `AppSettings`
5. Popover UI observes `@Published` properties on `AppState`

### Predictions
- `UsageHistory` stores up to 1000 timestamped samples in a circular buffer
- Linear regression on the last 60 samples estimates rate of change
- Predicts when utilization will hit 100%
- Persisted to `~/Library/Application Support/Headroom/usage_history.json`

### Auto-Updates (Sparkle)
- `SPUStandardUpdaterController` initialized in `AppDelegate.init()`
- Appcast at `https://matjam.github.io/headroom/appcast.xml` (GitHub Pages, `gh-pages` branch)
- EdDSA signatures verify update authenticity
- Automatic check every 24 hours; manual via popover menu

## Building

### Prerequisites
- macOS 14.0+, Xcode 15+, xcodegen (`brew install xcodegen`)

### Commands
```sh
cp .env.example .env        # Set DEVELOPMENT_TEAM for code signing
make                         # Debug build
make run                     # Build and launch
make dmg                     # Release build + DMG
make clean                   # Remove artifacts
```

### Version Stamping
- Version is derived from the latest git tag: `git describe --tags --abbrev=0`
- Passed to xcodebuild as `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
- Git short SHA is passed as `GIT_COMMIT_SHA` (custom Info.plist key)
- Info.plist uses `$(MARKETING_VERSION)`, `$(CURRENT_PROJECT_VERSION)`, `$(GIT_COMMIT_SHA)` placeholders

### Code Signing for Releases
- Debug: Apple Development (automatic) or ad-hoc if no team set
- Release: Developer ID Application (manual), hardened runtime, secure timestamp
- Sparkle framework binaries are re-signed individually with `--preserve-metadata=entitlements`
- The final app is signed with entitlements from `Headroom/Headroom.entitlements`
- `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` prevents the debug `get-task-allow` entitlement

## Contributing Code

### Commit Messages
This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automated releases:
- `feat:` - New feature (triggers minor version bump)
- `fix:` - Bug fix (triggers patch version bump)
- `chore:` - Maintenance (no version bump)

### Pull Requests
- All changes go through PRs to `main`
- CI must pass (build check)
- The maintainer merges; no external approvals needed

### Key Constraints
- **No App Sandbox**: The app needs unrestricted network access and Keychain access
- **LSUIElement**: No dock icon, no main menu bar -- everything is in the status item
- **WKWebView cookies**: Authentication depends on capturing cookies from the WebView; any changes to `LoginWebView.swift` must preserve the cookie polling and popup handling
- **Sparkle compatibility**: `CFBundleVersion` must be a semver-comparable string, not a hash or arbitrary value
- **Notarization**: All binaries in the app bundle must be signed with Developer ID and include a secure timestamp; hardened runtime must be enabled

### Testing Changes Locally
1. `make run` to build and launch
2. Click the menu bar item to test the popover
3. Sign out and back in to test the auth flow
4. Open Settings (gear icon) to test configuration
5. For release builds: `make dmg` and verify with `codesign --verify --deep --strict dist/staging/Headroom.app`

### Common Pitfalls
- **xcodegen overwrites the xcodeproj**: Always run `make` (which calls `xcodegen generate`) rather than editing the xcodeproj directly
- **Shallow clones have no tags**: CI must use `fetch-depth: 0` and `fetch-tags: true` for version stamping to work
- **Sparkle re-signing**: Use `--preserve-metadata=entitlements` when re-signing Sparkle binaries, never `--deep` on the whole app, or XPC communication breaks
- **Google OAuth popups**: Must create a real second WKWebView window, not load the URL in the main WebView, or the OAuth callback fails
