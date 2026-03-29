import Foundation

/// A single timestamped usage sample.
struct UsageSample: Codable {
    let timestamp: Date
    let sessionUtilization: Double?
    let weeklyUtilization: Double?
}

/// Predictions derived from usage history.
struct UsagePredictions {
    /// Estimated time until session limit hits 100%, as a human-readable string.
    let sessionLimitETA: String?
    /// Estimated time until weekly limit hits 100%, as a human-readable string.
    let weeklyLimitETA: String?
    /// Session utilization rate (% per hour)
    let sessionRate: Double?
    /// Weekly utilization rate (% per hour)
    let weeklyRate: Double?
}

/// RRD-style circular buffer of usage samples with prediction via linear regression.
///
/// Stores samples at poll intervals. Keeps up to `maxSamples` entries.
/// Older entries are dropped (FIFO). Persisted to disk as JSON.
@MainActor
final class UsageHistory: ObservableObject {
    @Published var predictions: UsagePredictions?

    private var samples: [UsageSample] = []
    private let maxSamples = 1000  // ~16 hours at 60s intervals
    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Headroom", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageURL = dir.appendingPathComponent("usage_history.json")
        loadFromDisk()
    }

    /// Record a new usage sample and recompute predictions.
    func record(usage: UsageResponse) {
        let sample = UsageSample(
            timestamp: Date(),
            sessionUtilization: usage.fiveHour?.utilization,
            weeklyUtilization: usage.sevenDay?.utilization
        )

        samples.append(sample)

        // Trim to max size
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }

        saveToDisk()
        predictions = computePredictions()
    }

    /// Compute predictions using linear regression on recent samples.
    private func computePredictions() -> UsagePredictions {
        let sessionETA = predictETA(extracting: \.sessionUtilization)
        let weeklyETA = predictETA(extracting: \.weeklyUtilization)
        let sessionRate = computeRate(extracting: \.sessionUtilization)
        let weeklyRate = computeRate(extracting: \.weeklyUtilization)

        return UsagePredictions(
            sessionLimitETA: sessionETA,
            weeklyLimitETA: weeklyETA,
            sessionRate: sessionRate,
            weeklyRate: weeklyRate
        )
    }

    /// Linear regression to predict when utilization will hit 100%.
    /// Uses samples from the last 2 hours for session limit (shorter window),
    /// and last 24 hours for weekly limit.
    private func predictETA(extracting keyPath: KeyPath<UsageSample, Double?>) -> String? {
        // Need at least 3 data points
        let relevantSamples = samples.compactMap { s -> (Double, Double)? in
            guard let value = s[keyPath: keyPath] else { return nil }
            return (s.timestamp.timeIntervalSince1970, value)
        }

        guard relevantSamples.count >= 3 else { return nil }

        // Use the most recent samples (last 60 for ~1 hour of data at 60s intervals)
        let recentSamples = Array(relevantSamples.suffix(60))

        // If utilization is decreasing or flat, no ETA
        let lastValue = recentSamples.last!.1
        if lastValue >= 100 { return "now" }

        // Linear regression: y = mx + b
        let (slope, intercept) = linearRegression(recentSamples)

        // slope is % per second
        guard slope > 0.0001 else { return nil } // Not increasing meaningfully

        // Solve for y = 100: time = (100 - b) / m
        let targetTime = (100.0 - intercept) / slope
        let now = Date().timeIntervalSince1970
        let secondsUntil = targetTime - now

        guard secondsUntil > 0 else { return "now" }

        return formatDuration(seconds: secondsUntil)
    }

    /// Compute the rate of change in % per hour.
    private func computeRate(extracting keyPath: KeyPath<UsageSample, Double?>) -> Double? {
        let relevantSamples = samples.compactMap { s -> (Double, Double)? in
            guard let value = s[keyPath: keyPath] else { return nil }
            return (s.timestamp.timeIntervalSince1970, value)
        }

        guard relevantSamples.count >= 3 else { return nil }

        let recentSamples = Array(relevantSamples.suffix(60))
        let (slope, _) = linearRegression(recentSamples)

        // Convert from % per second to % per hour
        return slope * 3600.0
    }

    /// Simple linear regression on (x, y) pairs.
    /// Returns (slope, intercept).
    private func linearRegression(_ points: [(Double, Double)]) -> (Double, Double) {
        let n = Double(points.count)
        let sumX = points.reduce(0.0) { $0 + $1.0 }
        let sumY = points.reduce(0.0) { $0 + $1.1 }
        let sumXY = points.reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumX2 = points.reduce(0.0) { $0 + $1.0 * $1.0 }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return (0, sumY / n) }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        return (slope, intercept)
    }

    /// Format seconds into a human-readable duration.
    private func formatDuration(seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 48 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(samples)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Non-fatal; we'll just lose history on restart
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        guard let loaded = try? JSONDecoder().decode([UsageSample].self, from: data) else { return }

        // Prune old samples (older than 24 hours)
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        samples = loaded.filter { $0.timestamp > cutoff }
        if !samples.isEmpty {
            predictions = computePredictions()
        }
    }
}
