import SwiftUI
import Charts

struct StatisticsView: View {
    let progress: SoloProgress
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeRange = TimeRange.week
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall stats
                    OverallStatsCard(progress: progress)
                    
                    // Performance chart
                    PerformanceChartCard(progress: progress)
                    
                    // Level breakdown
                    LevelBreakdownCard(progress: progress)
                    
                    // Achievement progress
                    AchievementProgressCard(progress: progress)
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OverallStatsCard: View {
    let progress: SoloProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overall Performance")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatBox(
                    icon: "text.book.closed",
                    value: "\(progress.totalWordsSpelled)",
                    label: "Words Attempted",
                    color: .blue
                )
                
                StatBox(
                    icon: "checkmark.circle.fill",
                    value: "\(progress.totalCorrectWords)",
                    label: "Correct Words",
                    color: .green
                )
                
                StatBox(
                    icon: "percent",
                    value: "\(progress.accuracyPercentage)%",
                    label: "Accuracy",
                    color: progress.accuracyPercentage >= 80 ? .green : .orange
                )
                
                StatBox(
                    icon: "flame.fill",
                    value: "\(progress.longestStreak)",
                    label: "Best Streak",
                    color: .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct StatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

struct PerformanceChartCard: View {
    let progress: SoloProgress
    
    // Mock data for chart
    private var chartData: [(String, Int)] {
        return [
            ("Mon", 85),
            ("Tue", 90),
            ("Wed", 78),
            ("Thu", 92),
            ("Fri", 88),
            ("Sat", 95),
            ("Sun", 91)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Accuracy")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Simple bar chart representation
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(chartData, id: \.0) { day, accuracy in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        accuracy >= 90 ? .green : (accuracy >= 80 ? .blue : .orange),
                                        accuracy >= 90 ? .green.opacity(0.7) : (accuracy >= 80 ? .blue.opacity(0.7) : .orange.opacity(0.7))
                                    ]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 40, height: CGFloat(accuracy) * 2)
                        
                        Text(day)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 220)
            
            Text("Average: \(progress.accuracyPercentage)%")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct LevelBreakdownCard: View {
    let progress: SoloProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Level Performance")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(progress.levelHistory.sorted(by: { $0.level < $1.level }), id: \.level) { levelStat in
                LevelStatRow(levelStat: levelStat)
            }
            
            if progress.levelHistory.isEmpty {
                Text("Complete sessions to see level breakdown")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct LevelStatRow: View {
    let levelStat: LevelStats
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Level \(levelStat.level)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(levelStat.attempts) attempts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Label("\(levelStat.accuracy)%", systemImage: "percent")
                    .font(.caption)
                    .foregroundColor(levelStat.accuracy >= 80 ? .green : .orange)
                
                Label("\(levelStat.correctWords)/\(levelStat.totalWords)", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Label(String(format: "%.1fs avg", levelStat.averageTime), systemImage: "timer")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            // Accuracy bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(levelStat.accuracy >= 80 ? Color.green : Color.orange)
                        .frame(width: geometry.size.width * Double(levelStat.accuracy) / 100, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

struct AchievementProgressCard: View {
    let progress: SoloProgress
    
    private var unlockedCount: Int {
        progress.achievements.count
    }
    
    private var totalCount: Int {
        Achievement.allAchievements.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(unlockedCount)/\(totalCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.yellow, .orange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * Double(unlockedCount) / Double(totalCount), height: 12)
                }
            }
            .frame(height: 12)
            
            Text("\(Int(Double(unlockedCount) / Double(totalCount) * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}
