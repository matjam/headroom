import Foundation
import ServiceManagement

/// Persisted app settings via UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let menuBarFormat = "menuBarFormat"
        static let menuBarEmoji = "menuBarEmoji"
        static let pollInterval = "pollInterval"
    }

    /// Launch at login via SMAppService.
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Revert on failure
                launchAtLogin = oldValue
            }
        }
    }

    /// The format string for the menu bar display.
    /// Available placeholders:
    ///   {sl}       - Session limit utilization (e.g. "10%")
    ///   {wl}       - Weekly limit utilization (e.g. "6%")
    ///   {sl_reset}  - Session limit reset time (e.g. "2h 30m")
    ///   {wl_reset}  - Weekly limit reset time (e.g. "2d 5h")
    ///   {sl_eta}    - Predicted time until session limit hit (e.g. "1h 15m")
    ///   {wl_eta}    - Predicted time until weekly limit hit (e.g. "3d 2h")
    ///   {sonnet}    - Sonnet 7d utilization
    ///   {opus}      - Opus 7d utilization
    ///   {extra}     - Extra usage utilization
    ///   {extra_used} - Extra usage dollars used
    ///   {extra_limit} - Extra usage dollar limit
    @Published var menuBarFormat: String {
        didSet { defaults.set(menuBarFormat, forKey: Keys.menuBarFormat) }
    }

    /// Emoji prefix for the menu bar.
    @Published var menuBarEmoji: String {
        didSet { defaults.set(menuBarEmoji, forKey: Keys.menuBarEmoji) }
    }

    /// Poll interval in seconds.
    @Published var pollInterval: Double {
        didSet { defaults.set(pollInterval, forKey: Keys.pollInterval) }
    }

    private init() {
        let storedFormat = defaults.string(forKey: Keys.menuBarFormat)
        self.menuBarFormat = storedFormat ?? "SL {sl} WL {wl}"

        let storedEmoji = defaults.string(forKey: Keys.menuBarEmoji)
        self.menuBarEmoji = storedEmoji ?? "🧠"

        let storedInterval = defaults.double(forKey: Keys.pollInterval)
        self.pollInterval = storedInterval > 0 ? storedInterval : 60

        // Read current login item state from the system
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// All available placeholders with descriptions.
    static let placeholders: [(placeholder: String, description: String)] = [
        ("{sl}", "Session limit (5h) utilization %"),
        ("{wl}", "Weekly limit (7d) utilization %"),
        ("{sl_reset}", "Session limit reset countdown"),
        ("{wl_reset}", "Weekly limit reset countdown"),
        ("{sl_eta}", "Predicted time to hit session limit"),
        ("{wl_eta}", "Predicted time to hit weekly limit"),
        ("{sonnet}", "Sonnet (7d) utilization %"),
        ("{opus}", "Opus (7d) utilization %"),
        ("{extra}", "Extra usage utilization %"),
        ("{extra_used}", "Extra usage $ spent"),
        ("{extra_limit}", "Extra usage $ limit"),
    ]

    /// Resolve the format string using current usage data and predictions.
    func resolveMenuBarFormat(usage: UsageResponse?, predictions: UsagePredictions?) -> String {
        var result = "\(menuBarEmoji) \(menuBarFormat)"

        let sl = usage?.fiveHour.map { "\(Int($0.utilization))%" } ?? "--"
        let wl = usage?.sevenDay.map { "\(Int($0.utilization))%" } ?? "--"
        let slReset = usage?.fiveHour?.timeUntilReset ?? "--"
        let wlReset = usage?.sevenDay?.timeUntilReset ?? "--"
        let sonnet = usage?.sevenDaySonnet.map { "\(Int($0.utilization))%" } ?? "--"
        let opus = usage?.sevenDayOpus.map { "\(Int($0.utilization))%" } ?? "--"
        let extra = usage?.extraUsage?.utilization.map { "\(Int($0))%" } ?? "--"
        let extraUsed = usage?.extraUsage?.formattedUsed ?? "--"
        let extraLimit = usage?.extraUsage?.formattedLimit ?? "--"

        let slEta = predictions?.sessionLimitETA ?? "--"
        let wlEta = predictions?.weeklyLimitETA ?? "--"

        result = result
            .replacingOccurrences(of: "{sl}", with: sl)
            .replacingOccurrences(of: "{wl}", with: wl)
            .replacingOccurrences(of: "{sl_reset}", with: slReset)
            .replacingOccurrences(of: "{wl_reset}", with: wlReset)
            .replacingOccurrences(of: "{sl_eta}", with: slEta)
            .replacingOccurrences(of: "{wl_eta}", with: wlEta)
            .replacingOccurrences(of: "{sonnet}", with: sonnet)
            .replacingOccurrences(of: "{opus}", with: opus)
            .replacingOccurrences(of: "{extra}", with: extra)
            .replacingOccurrences(of: "{extra_used}", with: extraUsed)
            .replacingOccurrences(of: "{extra_limit}", with: extraLimit)

        return result
    }
}
