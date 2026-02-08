import SwiftUI

struct LeaderboardView: View {
    @StateObject private var manager = LeaderboardManager()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // My rank card
                MyRankCard(rank: manager.myRank, isLoading: manager.isLoadingRank)

                // Top spellers
                TopSpellersCard(
                    players: manager.topSpellers,
                    isLoading: manager.isLoadingTop
                )
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await manager.loadAll()
        }
        .task {
            await manager.loadAll()
        }
        .alert("Error", isPresented: .init(
            get: { manager.error != nil },
            set: { if !$0 { manager.error = nil } }
        )) {
            Button("OK") { manager.error = nil }
        } message: {
            Text(manager.error ?? "")
        }
    }
}

// MARK: - My Rank Card

struct MyRankCard: View {
    let rank: MyRankResponse?
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Your Rank", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let rank = rank {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("#\(rank.rank)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)

                    Text("of \(rank.totalPlayers)")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(rank.accuracy, specifier: "%.1f")%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(accuracyColor(rank.accuracy))
                        Text("accuracy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Progress bar showing position in all players
                if rank.totalPlayers > 1 {
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))

                                let pct = 1.0 - (Double(rank.rank - 1) / Double(rank.totalPlayers - 1))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, geo.size.width * pct))
                                    .animation(.easeInOut(duration: 0.8), value: pct)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("Top \(topPercentLabel(rank: rank.rank, total: rank.totalPlayers))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(rank.totalPlayers) players ranked")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else if !isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Spell some words to get ranked!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(height: 60)
                    .redacted(reason: .placeholder)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private func accuracyColor(_ acc: Double) -> Color {
        if acc >= 90 { return .green }
        if acc >= 70 { return .blue }
        if acc >= 50 { return .orange }
        return .red
    }

    private func topPercentLabel(rank: Int, total: Int) -> String {
        guard total > 1 else { return "1%" }
        let pct = Int(ceil(Double(rank) / Double(total) * 100))
        return "\(pct)%"
    }
}

// MARK: - Top Spellers Card

struct TopSpellersCard: View {
    let players: [TopSpellerEntry]
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Top Spellers", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if isLoading && players.isEmpty {
                VStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 52)
                            .redacted(reason: .placeholder)
                    }
                }
            } else if players.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.3")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No ranked players yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(players) { player in
                        TopSpellerRow(player: player)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Top Speller Row

struct TopSpellerRow: View {
    let player: TopSpellerEntry

    private var rankColor: Color {
        switch player.rank {
        case 1: return .yellow
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // bronze
        default: return .secondary
        }
    }

    private var rankIcon: String {
        switch player.rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(player.rank <= 3 ? 0.2 : 0.08))
                    .frame(width: 36, height: 36)

                if !rankIcon.isEmpty {
                    Image(systemName: rankIcon)
                        .font(.system(size: 16))
                        .foregroundColor(rankColor)
                } else {
                    Text("\(player.rank)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            // Username + level
            VStack(alignment: .leading, spacing: 2) {
                Text(player.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("Level \(player.level) · \(player.totalWordsSpelled) words")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Accuracy
            Text("\(player.accuracy, specifier: "%.1f")%")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(player.rank <= 3 ? rankColor : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}
