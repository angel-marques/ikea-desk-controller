import SwiftUI

struct StatsView: View {
    @EnvironmentObject var statsManager: StatsManager
    @State private var selectedPeriod = "This Week"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Statistics")
                    .font(AppFont.title)
                    .foregroundColor(.textPrimary)

                Spacer()

                Menu {
                    Button("Today") { selectedPeriod = "Today" }
                    Button("This Week") { selectedPeriod = "This Week" }
                    Button("This Month") { selectedPeriod = "This Month" }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedPeriod)
                            .font(AppFont.body)
                            .foregroundColor(.white)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.cardBackground)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 24) {
                    // Today's Summary
                    TodaySummarySection()

                    // Weekly Activity Chart
                    WeeklyActivitySection()

                    // Daily Goal
                    DailyGoalSection()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

struct TodaySummarySection: View {
    @EnvironmentObject var statsManager: StatsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Summary")
                .font(AppFont.title2)
                .foregroundColor(.textPrimary)

            // First row
            HStack(spacing: 12) {
                StatCard(
                    icon: "figure.stand",
                    iconColor: .standing,
                    label: "Standing",
                    value: statsManager.todayStats.standingTimeFormatted
                )

                StatCard(
                    icon: "person.fill",
                    iconColor: .sitting,
                    label: "Sitting",
                    value: statsManager.todayStats.sittingTimeFormatted
                )
            }

            // Second row
            HStack(spacing: 12) {
                StatCard(
                    icon: "arrow.up.arrow.down",
                    iconColor: .success,
                    label: "Transitions",
                    value: "\(statsManager.todayStats.transitions)"
                )

                StatCard(
                    icon: "flame.fill",
                    iconColor: .error,
                    label: "Extra Calories",
                    value: "\(statsManager.todayStats.estimatedCalories)"
                )
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            Text(label)
                .font(AppFont.caption)
                .foregroundColor(.textSecondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}

struct WeeklyActivitySection: View {
    @EnvironmentObject var statsManager: StatsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Activity")
                    .font(AppFont.title2)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Legend
                HStack(spacing: 16) {
                    LegendItem(color: .standing, label: "Standing")
                    LegendItem(color: .sitting, label: "Sitting")
                }
            }

            // Chart
            WeeklyChart(data: statsManager.getWeekData())
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(AppFont.caption)
                .foregroundColor(.textMuted)
        }
    }
}

struct WeeklyChart: View {
    let data: [(day: String, standing: Double, sitting: Double)]

    private var maxValue: Double {
        data.map { $0.standing + $0.sitting }.max() ?? 8
    }

    var body: some View {
        VStack(spacing: 8) {
            // Bars
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data.indices, id: \.self) { index in
                    let item = data[index]
                    VStack(spacing: 2) {
                        // Standing bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.standing)
                            .frame(width: 24, height: barHeight(for: item.standing))

                        // Sitting bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.sitting)
                            .frame(width: 24, height: barHeight(for: item.sitting))
                    }
                }
            }
            .frame(height: 100)

            // Labels
            HStack(spacing: 8) {
                ForEach(data.indices, id: \.self) { index in
                    Text(data[index].day)
                        .font(AppFont.small)
                        .foregroundColor(index == data.count - 1 ? .accentOrange : .textMuted)
                        .frame(width: 24)
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    private func barHeight(for value: Double) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        return max(4, CGFloat(value / maxValue) * 80)
    }
}

struct DailyGoalSection: View {
    @EnvironmentObject var statsManager: StatsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Goal")
                    .font(AppFont.title2)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("\(Int(statsManager.goalProgress * 100))%")
                    .font(AppFont.title2)
                    .foregroundColor(.accentOrange)
            }

            CardView(padding: 20) {
                VStack(spacing: 16) {
                    HStack {
                        Text("Stand for \(Int(statsManager.dailyGoalHours)) hours today")
                            .font(AppFont.body)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        Text("\(statsManager.todayStats.standingTimeFormatted) / \(Int(statsManager.dailyGoalHours))h")
                            .font(AppFont.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.borderMedium)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentOrange)
                                .frame(width: geometry.size.width * statsManager.goalProgress)
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
    }
}

#Preview {
    StatsView()
        .environmentObject(StatsManager())
        .preferredColorScheme(.dark)
        .background(Color.appBackground)
}
