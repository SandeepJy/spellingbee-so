import SwiftUI

struct AchievementsView: View {
    let progress: SoloProgress
    @Environment(\.dismiss) var dismiss
    @State private var selectedAchievement: Achievement?
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary
                    AchievementSummaryHeader(
                        unlockedCount: progress.achievements.count,
                        totalCount: Achievement.allAchievements.count
                    )
                    
                    // Achievement grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Achievement.allAchievements) { achievement in
                            AchievementBadge(
                                achievement: achievement,
                                isUnlocked: progress.achievements.contains(achievement.id),
                                onTap: {
                                    selectedAchievement = achievement
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailSheet(
                achievement: achievement,
                isUnlocked: progress.achievements.contains(achievement.id)
            )
            .presentationDetents([.medium])
        }
    }
}

struct AchievementSummaryHeader: View {
    let unlockedCount: Int
    let totalCount: Int
    
    private var percentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int(Double(unlockedCount) / Double(totalCount) * 100)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: Double(unlockedCount) / Double(totalCount))
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.yellow, .orange]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: unlockedCount)
                
                VStack(spacing: 4) {
                    Text("\(percentage)%")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Stats
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("\(unlockedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    Text("Unlocked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(totalCount - unlockedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(totalCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? Color.yellow.opacity(0.2) : Color(.systemGray5))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 30))
                        .foregroundColor(isUnlocked ? .yellow : .gray)
                    
                    if !isUnlocked {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                
                Text(achievement.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 30)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AchievementDetailSheet: View {
    let achievement: Achievement
    let isUnlocked: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.yellow.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 120, height: 120)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 60))
                    .foregroundColor(isUnlocked ? .yellow : .gray)
                
                if !isUnlocked {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            
            // Title and description
            VStack(spacing: 8) {
                Text(achievement.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(achievement.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if isUnlocked {
                    Label("Unlocked", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }
            }
            
            // XP Reward
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("+\(achievement.xpReward) XP")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.2))
            )
            
            Spacer()
            
            Button("Close") {
                dismiss()
            }
            .foregroundColor(.blue)
        }
        .padding()
        .presentationDragIndicator(.visible)
    }
}
