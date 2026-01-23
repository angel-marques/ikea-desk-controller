import Foundation

struct LastSession: Codable {
    var height: Double
    var timestamp: Date
}

struct DailyStats: Codable, Identifiable {
    var id: Date { date }
    var date: Date
    var standingTime: TimeInterval  // seconds
    var sittingTime: TimeInterval
    var transitions: Int

    var standingTimeFormatted: String {
        formatDuration(standingTime)
    }

    var sittingTimeFormatted: String {
        formatDuration(sittingTime)
    }

    var estimatedCalories: Int {
        // Standing burns ~0.15 more calories per minute than sitting
        Int(standingTime / 60.0 * 0.15)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct WeeklyStats {
    var days: [DailyStats]

    var totalStandingTime: TimeInterval {
        days.reduce(0) { $0 + $1.standingTime }
    }

    var totalSittingTime: TimeInterval {
        days.reduce(0) { $0 + $1.sittingTime }
    }

    var totalTransitions: Int {
        days.reduce(0) { $0 + $1.transitions }
    }

    var averageStandingPerDay: TimeInterval {
        guard !days.isEmpty else { return 0 }
        return totalStandingTime / Double(days.count)
    }
}
