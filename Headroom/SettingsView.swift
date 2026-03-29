import SwiftUI

/// Settings panel opened from the gear icon in the popover.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var appState: AppState
    @State private var formatText: String = ""

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Text("Headroom \(appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Emoji prefix
            HStack {
                Text("Icon")
                    .frame(width: 80, alignment: .leading)
                TextField("Emoji", text: $settings.menuBarEmoji)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                Text("Prefix shown before the format string")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Format string
            VStack(alignment: .leading, spacing: 6) {
                Text("Menu Bar Format")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("e.g. SL {sl} WL {wl}", text: $formatText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onAppear { formatText = settings.menuBarFormat }
                    .onChange(of: formatText) { _, newValue in
                        settings.menuBarFormat = newValue
                    }

                // Preview
                HStack(spacing: 4) {
                    Text("Preview:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(settings.resolveMenuBarFormat(
                        usage: appState.usage,
                        predictions: appState.usageHistory.predictions
                    ))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                }
                .padding(.vertical, 2)
            }

            // Placeholder reference
            VStack(alignment: .leading, spacing: 4) {
                Text("Available Placeholders")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(AppSettings.placeholders, id: \.placeholder) { item in
                            HStack(alignment: .top) {
                                Text(item.placeholder)
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .frame(width: 90, alignment: .leading)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }

            Divider()

            // Poll interval
            HStack {
                Text("Refresh every")
                    .frame(width: 90, alignment: .leading)
                Picker("", selection: $settings.pollInterval) {
                    Text("30s").tag(30.0)
                    Text("60s").tag(60.0)
                    Text("2m").tag(120.0)
                    Text("5m").tag(300.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            // Launch at login
            Toggle("Launch at login", isOn: $settings.launchAtLogin)

            Spacer()
        }
        .padding(16)
        .frame(width: 400, height: 480)
    }
}
