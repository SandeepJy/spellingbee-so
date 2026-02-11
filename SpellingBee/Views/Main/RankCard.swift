import SwiftUI

/// A prominent card displaying the user's rank with a link to the leaderboard.
struct RankCard: View {
    let rank: MyRankResponse?
    let isLoading: Bool
    let onLeaderboardTap: () -> Void
    
    private var rankPosition: String {
        guard let rank = rank else { return "--" }
        return "#\(rank.rank)"
    }
    
    private var totalPlayers: String {
        guard let rank = rank else { return "--" }
        return "of \(rank.totalPlayers)"
    }
    
    private var accuracy: String {
        guard let rank = rank else { return "--%"}
        return String(format: "%.1f%%", rank.accuracy)
    }
    
    private var percentile: Int {
        guard let rank = rank, rank.totalPlayers > 0 else { return 0 }
        return Int(ceil(Double(rank.rank) / Double(rank.totalPlayers) * 100))
    }
    
    private var rankTier: (name: String, color: Color, icon: String) {
        guard let rank = rank, rank.totalPlayers > 0 else {
            return ("Unranked", .gray, "questionmark.circle.fill")
        }
        let pct = Double(rank.rank) / Double(rank.totalPlayers)
        switch pct {
        case 0..<0.05: return ("Champion", .yellow, "crown.fill")
        case 0.05..<0.15: return ("Master", .purple, "star.circle.fill")
        case 0.15..<0.30: return ("Expert", .blue, "medal.fill")
        case 0.30..<0.50: return ("Skilled", .green, "hand.thumbsup.fill")
        default: return ("Rising", .orange, "flame.fill")
        }
    }
    
    var body: some View {
        Button(action: onLeaderboardTap) {
            VStack(spacing: 0) {
                // Top section with rank
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: rankTier.icon)
                                .font(.caption)
                                .foregroundColor(rankTier.color)
                            Text(rankTier.name)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(rankTier.color)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(rankTier.color.opacity(0.15))
                        )
                        
                        if isLoading {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(rankPosition)
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(totalPlayers)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Accuracy circle
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 6)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .trim(from: 0, to: (rank?.accuracy ?? 0) / 100)
                            .stroke(
                                accuracyColor,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: rank?.accuracy)
                        
                        VStack(spacing: 0) {
                            Text(accuracy)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(accuracyColor)
                            Text("accuracy")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 12)
                
                // Bottom section - stats and CTA
                HStack {
                    if let rank = rank {
                        HStack(spacing: 16) {
                            StatPill(
                                icon: "text.book.closed.fill",
                                value: "\(rank.totalWordsSpelled)",
                                label: "words"
                            )
                            
                            StatPill(
                                icon: "chart.bar.fill",
                                value: "Top \(percentile)%",
                                label: nil
                            )
                        }
                    } else if !isLoading {
                        Text("Spell words to get ranked!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Leaderboard")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [rankTier.color.opacity(0.5), rankTier.color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var accuracyColor: Color {
        guard let acc = rank?.accuracy else { return .gray }
        if acc >= 90 { return .green }
        if acc >= 70 { return .blue }
        if acc >= 50 { return .orange }
        return .red
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String?
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            if let label = label {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RankCard(
            rank: MyRankResponse(
                rank: 5,
                totalPlayers: 150,
                accuracy: 87.5,
                username: "TestUser",
                totalWordsSpelled: 342
            ),
            isLoading: false,
            onLeaderboardTap: {}
        )
        
        RankCard(rank: nil, isLoading: true, onLeaderboardTap: {})
        
        RankCard(rank: nil, isLoading: false, onLeaderboardTap: {})
    }
    .padding()
}
