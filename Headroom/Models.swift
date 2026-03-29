import Foundation

// MARK: - Usage API Response

struct UsageResponse: Codable {
    let fiveHour: UsageLimit?
    let sevenDay: UsageLimit?
    let sevenDayOauthApps: UsageLimit?
    let sevenDayOpus: UsageLimit?
    let sevenDaySonnet: UsageLimit?
    let sevenDayCowork: UsageLimit?
    let iguanaNecktie: UsageLimit?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayCowork = "seven_day_cowork"
        case iguanaNecktie = "iguana_necktie"
        case extraUsage = "extra_usage"
    }
}

struct UsageLimit: Codable {
    let utilization: Double
    let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: resetsAt)
    }

    var timeUntilReset: String {
        guard let date = resetsAtDate else { return "unknown" }
        let now = Date()
        guard date > now else { return "now" }

        let interval = date.timeIntervalSince(now)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct ExtraUsage: Codable {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
    }

    var formattedUsed: String {
        guard let used = usedCredits else { return "N/A" }
        return String(format: "$%.2f", used / 100.0)
    }

    var formattedLimit: String {
        guard let limit = monthlyLimit else { return "unlimited" }
        return String(format: "$%.2f", limit / 100.0)
    }
}

// MARK: - Organization

struct Organization: Codable, Identifiable {
    let uuid: String
    let name: String
    let settings: OrgSettings?
    let capabilities: [String]?
    let joinedAt: String?

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, settings, capabilities
        case joinedAt = "joined_at"
    }
}

struct OrgSettings: Codable {
    let claudeConsolePrivacy: String?

    enum CodingKeys: String, CodingKey {
        case claudeConsolePrivacy = "claude_console_privacy"
    }
}

// MARK: - Auth State

enum AuthState: Equatable {
    case loggedOut
    case loggingIn
    case loggedIn(orgId: String, orgName: String)
    case error(String)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.loggedOut, .loggedOut): return true
        case (.loggingIn, .loggingIn): return true
        case (.loggedIn(let a, _), .loggedIn(let b, _)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
