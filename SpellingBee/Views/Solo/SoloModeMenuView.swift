import SwiftUI

struct SoloModeMenuView: View {
    @EnvironmentObject var soloManager: SoloModeManager
    @EnvironmentObject var gameManager: GameManager
    @State private var showingSessionView = false
    @State private var selectedLevel: Int?
    @State private var showingStatsView = false
    @State private var showingAchievementsView = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with level and XP
                if let progress = soloManager.soloProgress {
                    PlayerProgressHeader(progress: progress)
                        .padding(.horizontal)
                    
                    // Streak indicator
                    StreakIndicator(currentStreak: progress.currentStreak, longestStreak: progress.longestStreak)
                        .padding(.horizontal)
                    
                    // Quick stats
                    QuickStatsView(progress: progress)
                        .padding(.horizontal)
                    
                    // Level selection
                    LevelSelectionView(
                        currentLevel: progress.level,
                        onLevelSelected: { level in
                            selectedLevel = level
                            Task {
                                await startSession(level: level)
                            }
                        }
                    )
                    .padding(.horizontal)
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        MenuActionButton(
                            title: "Statistics",
                            icon: "chart.bar.fill",
                            color: .blue,
                            action: { showingStatsView = true }
                        )
                        
                        MenuActionButton(
                            title: "Achievements",
                            icon: "trophy.fill",
                            color: .yellow,
                            action: { showingAchievementsView = true }
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Solo Practice")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingSessionView) {
            if let session = soloManager.currentSession {
                SoloSessionView(session: session)
                    .environmentObject(soloManager)
            }
        }
        .sheet(isPresented: $showingStatsView) {
            if let progress = soloManager.soloProgress {
                StatisticsView(progress: progress)
            }
        }
        .sheet(isPresented: $showingAchievementsView) {
            if let progress = soloManager.soloProgress {
                AchievementsView(progress: progress)
            }
        }
        .overlay(
            Group {
                if soloManager.isLoading {
                    LoadingOverlay()
                }
            }
        )
        .task {
            if soloManager.soloProgress == nil, let userID = gameManager.currentUser?.id {
                await soloManager.loadProgress(for: userID)
                soloManager.setupRealtimeListener(for: userID)
            }
        }
        .onDisappear {
            soloManager.removeListener()
        }
    }
    
    private func startSession(level: Int) async {
        guard let userID = gameManager.currentUser?.id else { return }
        
        do {
            _ = try await soloManager.createSession(userID: userID, level: level, wordCount: 10)
            showingSessionView = true
        } catch {
            print("Error creating session: \(error)")
        }
    }
}

// MARK: - Player Progress Header
struct PlayerProgressHeader: View {
    let progress: SoloProgress
    
    var body: some View {
        VStack(spacing: 16) {
            // Level badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(progress.level)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(progress.xp) / \(progress.xpToNextLevel) XP")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("\(progress.level)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("LVL")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    )
            }
            
            // XP Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 16)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress.progressToNextLevel, height: 16)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress.progressToNextLevel)
                    }
                }
                .frame(height: 16)
                
                HStack {
                    Text("\(Int(progress.progressToNextLevel * 100))% to next level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(progress.xpToNextLevel - progress.xp) XP needed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Streak Indicator
struct StreakIndicator: View {
    let currentStreak: Int
    let longestStreak: Int
    
    var body: some View {
        HStack(spacing: 20) {
            StreakBadge(
                value: currentStreak,
                label: "Current Streak",
                icon: "flame.fill",
                color: currentStreak > 0 ? .orange : .gray
            )
            
            StreakBadge(
                value: longestStreak,
                label: "Longest Streak",
                icon: "star.fill",
                color: .yellow
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct StreakBadge: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Quick Stats View
struct QuickStatsView: View {
    let progress: SoloProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                StatItem(
                    icon: "checkmark.circle.fill",
                    value: "\(progress.totalCorrectWords)",
                    label: "Correct",
                    color: .green
                )
                
                StatItem(
                    icon: "xmark.circle.fill",
                    value: "\(progress.totalIncorrectWords)",
                    label: "Incorrect",
                    color: .red
                )
                
                StatItem(
                    icon: "percent",
                    value: "\(progress.accuracyPercentage)%",
                    label: "Accuracy",
                    color: .blue
                )
                
                StatItem(
                    icon: "lightbulb.fill",
                    value: "\(progress.availableHints)",
                    label: "Hints",
                    color: .yellow
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

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Level Selection View
struct LevelSelectionView: View {
    let currentLevel: Int
    let onLevelSelected: (Int) -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Level")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...min(currentLevel + 1, 15), id: \.self) { level in
                    LevelButton(
                        level: level,
                        isUnlocked: level <= currentLevel,
                        isCurrent: level == currentLevel,
                        onTap: { onLevelSelected(level) }
                    )
                }
            }
            
            if currentLevel < 10 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Levels 1-10: Word length increases with difficulty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("Level 11+: Curated challenging words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct LevelButton: View {
    let level: Int
    let isUnlocked: Bool
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            if isUnlocked {
                onTap()
            }
        }) {
            VStack(spacing: 4) {
                Text("\(level)")
                    .font(.title3)
                    .fontWeight(.bold)
                
                if isCurrent {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isUnlocked ? (isCurrent ? Color.blue.opacity(0.2) : Color(.systemBackground)) : Color(.systemGray5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? Color.blue : Color.clear, lineWidth: 2)
            )
            .overlay(
                Group {
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                    }
                }
            )
        }
        .disabled(!isUnlocked)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Menu Action Button
struct MenuActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [color, color.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }
}
