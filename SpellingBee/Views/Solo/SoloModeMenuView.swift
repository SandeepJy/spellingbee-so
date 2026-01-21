import SwiftUI

struct SoloModeMenuView: View {
    @EnvironmentObject var soloManager: SoloModeManager
    @EnvironmentObject var gameManager: GameManager
    @State private var showingSessionView = false
    @State private var showingStatsSheet = false
    @State private var showingAchievementsSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let progress = soloManager.soloProgress {
                let config = SoloLevelConfig.config(for: progress.level)
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 20)
                        
                        // Level Badge
                        LevelBadgeView(level: progress.level, config: config)
                        
                        // Mission Card
                        MissionCard(config: config)
                        
                        // Start Button
                        StartButton(isLoading: soloManager.isLoading) {
                            Task {
                                await startSession(level: progress.level)
                            }
                        }
                        
                        // Quick info pills
                        QuickInfoPills(progress: progress)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
                
                // Bottom action bar
                BottomActionBar(
                    onStatsTap: { showingStatsSheet = true },
                    onAchievementsTap: { showingAchievementsSheet = true }
                )
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading progress...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Solo Mode")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSessionView) {
            if soloManager.currentSession != nil {
                SoloSessionView()
                    .environmentObject(soloManager)
            }
        }
        .sheet(isPresented: $showingStatsSheet) {
            if let progress = soloManager.soloProgress {
                StatisticsView(progress: progress)
            }
        }
        .sheet(isPresented: $showingAchievementsSheet) {
            if let progress = soloManager.soloProgress {
                AchievementsView(progress: progress)
            }
        }
        .overlay {
            if soloManager.isLoading {
                LoadingOverlay(message: soloManager.loadingMessage)
            }
        }
        .alert("Error", isPresented: .init(
            get: { soloManager.errorMessage != nil },
            set: { if !$0 { soloManager.errorMessage = nil } }
        )) {
            Button("OK") { soloManager.errorMessage = nil }
        } message: {
            Text(soloManager.errorMessage ?? "")
        }
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
            _ = try await soloManager.createSession(userID: userID, level: level)
            showingSessionView = true
        } catch {
            soloManager.errorMessage = "Failed to start session: \(error.localizedDescription)"
        }
    }
}

// MARK: - Level Badge
struct LevelBadgeView: View {
    let level: Int
    let config: SoloLevelConfig
    
    private var tierGradient: [Color] {
        switch level {
        case 1...5: return [.green, .mint]
        case 6...10: return [.blue, .cyan]
        case 11...15: return [.purple, .indigo]
        case 16...20: return [.red, .orange]
        default: return [.yellow, .orange]
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: tierGradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: tierGradient[0].opacity(0.4), radius: 15, x: 0, y: 8)
                
                VStack(spacing: 4) {
                    Text("\(level)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("LEVEL")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(2)
                }
            }
            
            Text(config.tierName)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Mission Card
struct MissionCard: View {
    let config: SoloLevelConfig
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.orange)
                Text("MISSION")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .tracking(1.5)
                Spacer()
            }
            
            Text(config.missionText)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            HStack(spacing: 24) {
                MissionDetail(icon: "textformat.size", label: config.difficultyDescription)
                MissionDetail(icon: "timer", label: "\(Int(config.timeLimit))s per word")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct MissionDetail: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Start Button
struct StartButton: View {
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "play.fill")
                        .font(.title2)
                }
                
                Text(isLoading ? "Loading..." : "Start Level")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isLoading ? [.gray, .gray] : [.green, .blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: isLoading ? .clear : .green.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Quick Info Pills
struct QuickInfoPills: View {
    let progress: SoloProgress
    
    var body: some View {
        HStack(spacing: 12) {
            InfoPill(icon: "flame.fill", value: "\(progress.currentStreak)", label: "Streak", color: .orange)
            InfoPill(icon: "percent", value: "\(progress.accuracyPercentage)%", label: "Accuracy", color: .blue)
            InfoPill(icon: "star.fill", value: "\(progress.xp)", label: "XP", color: .yellow)
        }
    }
}

struct InfoPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Bottom Action Bar
struct BottomActionBar: View {
    let onStatsTap: () -> Void
    let onAchievementsTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: onStatsTap) {
                VStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                    Text("Statistics")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            Divider()
                .frame(height: 30)
            
            Button(action: onAchievementsTap) {
                VStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                    Text("Achievements")
                        .font(.caption2)
                }
                .foregroundColor(.yellow)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(
            Color(.systemGray6)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -2)
        )
    }
}
