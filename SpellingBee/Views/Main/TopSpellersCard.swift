import SwiftUI

/// A card showing the top speller(s) with their stats
struct TopSpellersShowcaseCard: View {
    let topSpellers: [TopSpellerEntry]
    let isLoading: Bool
    let onViewAllTap: () -> Void
    
    private var topThree: [TopSpellerEntry] {
        Array(topSpellers.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text("Top Spellers")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: onViewAllTap) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            if isLoading {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 100)
                    }
                }
                .redacted(reason: .placeholder)
            } else if topSpellers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.3")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No ranked players yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Podium style display
                HStack(alignment: .bottom, spacing: 8) {
                    // Second place (if exists)
                    if topThree.count > 1 {
                        TopSpellerPodiumItem(
                            player: topThree[1],
                            position: 2,
                            height: 90
                        )
                    }
                    
                    // First place
                    if !topThree.isEmpty {
                        TopSpellerPodiumItem(
                            player: topThree[0],
                            position: 1,
                            height: 110
                        )
                    }
                    
                    // Third place (if exists)
                    if topThree.count > 2 {
                        TopSpellerPodiumItem(
                            player: topThree[2],
                            position: 3,
                            height: 75
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
    }
}

struct TopSpellerPodiumItem: View {
    let player: TopSpellerEntry
    let position: Int
    let height: CGFloat
    
    private var medalColor: Color {
        switch position {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }
    
    private var medalIcon: String {
        position == 1 ? "crown.fill" : "medal.fill"
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Medal
            ZStack {
                Circle()
                    .fill(medalColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: medalIcon)
                    .font(.system(size: 16))
                    .foregroundColor(medalColor)
            }
            
            // Avatar placeholder
            Circle()
                .fill(
                    LinearGradient(
                        colors: [medalColor.opacity(0.3), medalColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: position == 1 ? 50 : 40, height: position == 1 ? 50 : 40)
                .overlay(
                    Text(String(player.username.prefix(1)).uppercased())
                        .font(position == 1 ? .title3 : .subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(medalColor)
                )
            
            // Name
            Text(player.username)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // Stats
            VStack(spacing: 2) {
                Text(String(format: "%.1f%%", player.accuracy))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(medalColor)
                
                Text("Lvl \(player.level)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            // Current user indicator
            if player.isCurrentUser {
                Text("YOU")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: medalColor.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    VStack {
        TopSpellersShowcaseCard(
            topSpellers: [
                TopSpellerEntry(rank: 1, username: "ChampionSpeller", accuracy: 98.5, level: 15, totalWordsSpelled: 1250, isCurrentUser: false),
                TopSpellerEntry(rank: 2, username: "WordMaster", accuracy: 95.2, level: 12, totalWordsSpelled: 980, isCurrentUser: true),
                TopSpellerEntry(rank: 3, username: "SpellWizard", accuracy: 93.8, level: 11, totalWordsSpelled: 856, isCurrentUser: false)
            ],
            isLoading: false,
            onViewAllTap: {}
        )
        
        TopSpellersShowcaseCard(
            topSpellers: [],
            isLoading: true,
            onViewAllTap: {}
        )
    }
    .padding()
}
