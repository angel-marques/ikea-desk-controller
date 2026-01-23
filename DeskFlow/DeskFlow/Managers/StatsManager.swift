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
    private var hasResumedSession: Bool = false

    private let statsKey = "deskStats"
    private let lastSessionKey = "lastSession"
    private let standingThreshold: Double = 85.0  // cm
    private let heightTolerance: Double = 2.0  // cm - tolerance to consider "same position"

    init() {
        todayStats = DailyStats(date: Date(), standingTime: 0, sittingTime: 0, transitions: 0)
        loadStats()
        loadLastSession()
        startTracking()
    }

    // MARK: - Session Persistence

    private func loadLastSession() {
        if let data = UserDefaults.standard.data(forKey: lastSessionKey),
           let session = try? JSONDecoder().decode(LastSession.self, from: data) {
            lastHeight = session.height
            lastHeightCheck = session.timestamp
            isStanding = session.height >= standingThreshold
        }
    }

    private func saveLastSession() {
        let session = LastSession(height: lastHeight, timestamp: lastHeightCheck)
        if let encoded = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(encoded, forKey: lastSessionKey)
        }
    }

    /// Call this when reconnecting to check if we can infer time from last session
    func resumeSessionIfNeeded(currentHeight: Double) {
        guard !hasResumedSession else { return }
        hasResumedSession = true

        let now = Date()
        let elapsed = now.timeIntervalSince(lastHeightCheck)
        let maxInferenceTime: TimeInterval = 12 * 3600  // 12 hours max

        // Only infer if reasonable time has passed (> 1 min, < 12 hours)
        if elapsed > 60 && elapsed < maxInferenceTime {
            let calendar = Calendar.current
            let sessionStart = lastHeightCheck

            // Only count time within today
            let todayStart = calendar.startOfDay(for: now)
            let effectiveStart = max(sessionStart, todayStart)
            let inferredTime = now.timeIntervalSince(effectiveStart)

            if inferredTime > 60 {
                // Always count the elapsed time as the PREVIOUS position
                // (assumes height change happened just now when user opened app)
                let wasStanding = lastHeight >= standingThreshold
                if wasStanding {
                    todayStats.standingTime += inferredTime
                } else {
                    todayStats.sittingTime += inferredTime
                }

                // Count transition if height changed
                let heightChanged = abs(currentHeight - lastHeight) >= heightTolerance
                if heightChanged {
                    todayStats.transitions += 1
                    print("Resumed session: inferred \(Int(inferredTime/60)) min \(wasStanding ? "standing" : "sitting"), then changed to \(currentHeight >= standingThreshold ? "standing" : "sitting")")
                } else {
                    print("Resumed session: inferred \(Int(inferredTime/60)) min \(wasStanding ? "standing" : "sitting")")
                }

                saveStats()
                updateGoalProgress()
            }
        }

        // Update to current state
        lastHeightCheck = now
        lastHeight = currentHeight
        isStanding = currentHeight >= standingThreshold
        saveLastSession()
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

        // Only count reasonable intervals (less than 5 minutes for live tracking)
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
        isStanding = height >= standingThreshold
        saveLastSession()
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
