import SwiftUI

/// The popover content shown when clicking the menu bar item.
struct UsagePopoverView: View {
    @ObservedObject var appState: AppState
    let onLogin: () -> Void
    let onLogout: () -> Void
    let onSettings: () -> Void
    let onCheckForUpdates: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch appState.authState {
            case .loggedOut, .error:
                notLoggedInView
            case .loggingIn:
                notLoggedInView
            case .loggedIn(_, let orgName):
                loggedInView(orgName: orgName)
            }

            Divider()
            footerView
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: - Not Logged In

    private var notLoggedInView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Not signed in")
                .font(.headline)

            Text("Sign in to Claude.ai to view your usage limits.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if case .error(let msg) = appState.authState {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Logged In

    private func loggedInView(orgName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                if appState.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(action: {
                        Task { await appState.refreshUsage() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let errorMsg = appState.errorMessage {
                Label(errorMsg, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if let usage = appState.usage {
                Divider()

                // Session Limit (5-hour)
                if let fiveHour = usage.fiveHour {
                    UsageLimitRow(
                        title: "Session Limit (5h)",
                        icon: "clock",
                        utilization: fiveHour.utilization,
                        resetTime: fiveHour.timeUntilReset,
                        eta: appState.usageHistory.predictions?.sessionLimitETA,
                        rate: appState.usageHistory.predictions?.sessionRate
                    )
                }

                // Weekly Limit (7-day)
                if let sevenDay = usage.sevenDay {
                    UsageLimitRow(
                        title: "Weekly Limit (7d)",
                        icon: "calendar",
                        utilization: sevenDay.utilization,
                        resetTime: sevenDay.timeUntilReset,
                        eta: appState.usageHistory.predictions?.weeklyLimitETA,
                        rate: appState.usageHistory.predictions?.weeklyRate
                    )
                }

                // Model-specific limits
                let modelLimits: [(String, String, UsageLimit?)] = [
                    ("Opus (7d)", "brain.head.profile", usage.sevenDayOpus),
                    ("Sonnet (7d)", "wand.and.stars", usage.sevenDaySonnet),
                    ("OAuth Apps (7d)", "app.connected.to.app.below.fill", usage.sevenDayOauthApps),
                    ("Cowork (7d)", "person.2", usage.sevenDayCowork),
                ]

                let activeModelLimits = modelLimits.filter { $0.2 != nil }

                if !activeModelLimits.isEmpty {
                    Divider()
                    Text("Model Limits")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(activeModelLimits, id: \.0) { title, icon, limit in
                        if let limit = limit {
                            UsageLimitRow(
                                title: title,
                                icon: icon,
                                utilization: limit.utilization,
                                resetTime: limit.timeUntilReset
                            )
                        }
                    }
                }

                // Extra Usage
                if let extra = usage.extraUsage, extra.isEnabled {
                    Divider()
                    extraUsageSection(extra)
                }
            } else if appState.errorMessage == nil {
                HStack {
                    Spacer()
                    ProgressView("Loading usage data...")
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Extra Usage

    private func extraUsageSection(_ extra: ExtraUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Extra Usage")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(extra.formattedUsed) / \(extra.formattedLimit)")
                        .font(.system(.body, design: .monospaced))
                    if let util = extra.utilization {
                        UsageBar(utilization: util)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if let lastUpdated = appState.lastUpdated {
                Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Settings gear
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)

            switch appState.authState {
            case .loggedIn:
                Menu {
                    Button("Open Claude.ai Usage") {
                        if let url = URL(string: "https://claude.ai/settings/usage") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Check for Updates...") { onCheckForUpdates() }
                    Divider()
                    Button("Sign Out") { onLogout() }
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            default:
                Button("Sign In") { onLogin() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Usage Limit Row

struct UsageLimitRow: View {
    let title: String
    let icon: String
    let utilization: Double
    let resetTime: String
    var eta: String? = nil
    var rate: Double? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundColor(colorForUtilization(utilization))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(.body, weight: .medium))
                    Spacer()
                    Text("\(Int(utilization))%")
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundColor(colorForUtilization(utilization))
                }

                UsageBar(utilization: utilization)

                HStack(spacing: 8) {
                    Text("Resets in \(resetTime)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let eta = eta {
                        Text("Hit limit in ~\(eta)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    if let rate = rate, rate > 0.01 {
                        Text(String(format: "%.1f%%/hr", rate))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Usage Bar

struct UsageBar: View {
    let utilization: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(colorForUtilization(utilization))
                    .frame(width: max(0, geometry.size.width * min(utilization / 100.0, 1.0)), height: 6)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Color Helper

func colorForUtilization(_ utilization: Double) -> Color {
    if utilization >= 80 { return .red }
    if utilization >= 50 { return .orange }
    return .green
}
