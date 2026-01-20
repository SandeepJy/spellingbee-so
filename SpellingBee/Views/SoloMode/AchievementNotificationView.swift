import SwiftUI

struct AchievementNotificationView: View {
    @Binding var achievements: [Achievement]
    @State private var currentIndex = 0
    @State private var showNotification = false
    
    var body: some View {
        ZStack {
            if !achievements.isEmpty && showNotification {
                VStack {
                    HStack {
                        Image(systemName: achievements[currentIndex].icon)
                            .font(.title)
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Achievement Unlocked!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(achievements[currentIndex].name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("+\(achievements[currentIndex].xpReward) XP")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.yellow, lineWidth: 2)
                    )
                }
                .padding()
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showNotification)
        .onChange(of: achievements) { _, newValue in
            if !newValue.isEmpty {
                showNextAchievement()
            }
        }
    }
    
    private func showNextAchievement() {
        guard currentIndex < achievements.count else {
            achievements = []
            currentIndex = 0
            return
        }
        
        withAnimation {
            showNotification = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showNotification = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentIndex += 1
                if currentIndex < achievements.count {
                    showNextAchievement()
                } else {
                    achievements = []
                    currentIndex = 0
                }
            }
        }
    }
}
