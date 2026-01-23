import Foundation
import Combine

@MainActor
class StatsManager: ObservableObject {
    @Published var todayStats: DailyStats
    @Published var weeklyStats: [DailyStats] = []
    @Published var dailyGoalHours: Double = 5.0
    @Published var goalProgress: Double = 0.0

    private var lastHeightCheck: Date = Date()
    private var lastHeight: Double = 72.0
    private var isStanding: Bool = false
    private var trackingTimer: Timer?

    private let statsKey = "deskStats"
    private let standingThreshold: Double = 85.0  // cm

    init() {
        todayStats = DailyStats(date: Date(), standingTime: 0, sittingTime: 0, transitions: 0)
        loadStats()
        startTracking()
    }

    func loadStats() {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode([DailyStats].self, from: data) {
            weeklyStats = decoded.filter { stats in
                Calendar.current.isDate(stats.date, equalTo: Date(), toGranularity: .weekOfYear)
            }

            if let today = weeklyStats.first(where: { Calendar.current.isDateInToday($0.date) }) {
                todayStats = today
            }
        }
        updateGoalProgress()
    }

    func saveStats() {
        // Update today in weekly stats
        if let index = weeklyStats.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            weeklyStats[index] = todayStats
        } else {
            weeklyStats.append(todayStats)
        }

        // Keep only last 7 days
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        weeklyStats = weeklyStats.filter { $0.date > weekAgo }

        if let encoded = try? JSONEncoder().encode(weeklyStats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }

    func updateHeight(_ height: Double) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastHeightCheck)

        // Only count reasonable intervals (less than 5 minutes)
        if elapsed < 300 {
            let wasStanding = isStanding
            isStanding = height >= standingThreshold

            if isStanding {
                todayStats.standingTime += elapsed
            } else {
                todayStats.sittingTime += elapsed
            }

            // Count transitions
            if wasStanding != isStanding {
                todayStats.transitions += 1
            }

            saveStats()
            updateGoalProgress()
        }

        lastHeightCheck = now
        lastHeight = height
    }

    func startTracking() {
        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDayChange()
            }
        }
    }

    private func checkDayChange() {
        if !Calendar.current.isDateInToday(todayStats.date) {
            saveStats()
            todayStats = DailyStats(date: Date(), standingTime: 0, sittingTime: 0, transitions: 0)
        }
    }

    private func updateGoalProgress() {
        let goalSeconds = dailyGoalHours * 3600
        goalProgress = min(1.0, todayStats.standingTime / goalSeconds)
    }

    func getWeekData() -> [(day: String, standing: Double, sitting: Double)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        var result: [(String, Double, Double)] = []

        for dayOffset in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dayName = formatter.string(from: date)

            if let stats = weeklyStats.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                let standingHours = stats.standingTime / 3600
                let sittingHours = stats.sittingTime / 3600
                result.append((dayName, standingHours, sittingHours))
            } else {
                result.append((dayName, 0, 0))
            }
        }

        return result
    }
}
