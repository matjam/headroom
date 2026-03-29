import Foundation
import Combine
import WebKit

/// Central app state manager. Handles auth, polling, and usage data.
@MainActor
final class AppState: ObservableObject {
    @Published var authState: AuthState = .loggedOut
    @Published var usage: UsageResponse?
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var isRefreshing = false

    let apiClient = ClaudeAPIClient()
    let settings = AppSettings.shared
    let usageHistory = UsageHistory()

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // When poll interval changes, restart the timer
        settings.$pollInterval
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if case .loggedIn = self.authState {
                    self.startPolling()
                }
            }
            .store(in: &cancellables)

        // Try to restore session from Keychain
        Task {
            await restoreSession()
        }
    }

    // MARK: - Auth

    func restoreSession() async {
        if let sessionKey = KeychainHelper.loadSessionKey(),
           let orgId = KeychainHelper.loadOrgId(),
           let orgName = KeychainHelper.loadOrgName() {
            await apiClient.setSessionKey(sessionKey)
            authState = .loggedIn(orgId: orgId, orgName: orgName)
            await refreshUsage()
            startPolling()
        }
    }

    func loginCompleted(sessionKey: String) async {
        await apiClient.setSessionKey(sessionKey)
        _ = KeychainHelper.saveSessionKey(sessionKey)

        // Fetch organizations to get the org ID
        do {
            let orgs = try await apiClient.fetchOrganizations()
            guard let org = orgs.first else {
                authState = .error("No organization found")
                return
            }

            _ = KeychainHelper.saveOrgId(org.uuid)
            _ = KeychainHelper.saveOrgName(org.name)
            authState = .loggedIn(orgId: org.uuid, orgName: org.name)
            await refreshUsage()
            startPolling()
        } catch {
            authState = .error("Failed to fetch organizations: \(error.localizedDescription)")
        }
    }

    func logout() {
        stopPolling()
        KeychainHelper.clearAll()
        authState = .loggedOut
        usage = nil
        lastUpdated = nil
        errorMessage = nil

        // Clear all WebView cookies for claude.ai
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let claudeRecords = records.filter { $0.displayName.contains("claude") }
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: claudeRecords) {}
        }
    }

    // MARK: - Usage

    func refreshUsage() async {
        guard case .loggedIn(let orgId, _) = authState else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await apiClient.fetchUsage(orgId: orgId)
            usage = response
            lastUpdated = Date()
            errorMessage = nil

            // Record sample for prediction
            usageHistory.record(usage: response)
        } catch let error as APIError {
            if case .unauthorized = error {
                logout()
                errorMessage = "Session expired. Please sign in again."
            } else if case .cloudflareChallenge = error {
                errorMessage = "Cloudflare challenge. Please sign in again."
                logout()
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Polling

    func startPolling() {
        stopPolling()
        let interval = settings.pollInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.refreshUsage()
            }
        }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Menu Bar

    /// Resolved menu bar title string using the format from settings.
    var menuBarTitle: String {
        return settings.resolveMenuBarFormat(
            usage: usage,
            predictions: usageHistory.predictions
        )
    }

    /// Color indicator: green < 50%, yellow 50-80%, red > 80%
    var statusLevel: StatusLevel {
        guard let usage = usage else { return .unknown }

        let maxUtil = max(
            usage.fiveHour?.utilization ?? 0,
            usage.sevenDay?.utilization ?? 0
        )

        if maxUtil >= 80 { return .critical }
        if maxUtil >= 50 { return .warning }
        return .good
    }
}

enum StatusLevel {
    case good, warning, critical, unknown

    var color: String {
        switch self {
        case .good: return "green"
        case .warning: return "yellow"
        case .critical: return "red"
        case .unknown: return "gray"
        }
    }
}
