import SwiftUI

struct MainView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var leaderboardManager = LeaderboardManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                HomeTabContent()
                    .environmentObject(gameManager)
                    .environmentObject(userManager)
                    .environmentObject(leaderboardManager)
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            NavigationView {
                LeaderboardView()
                    .environmentObject(leaderboardManager)
            }
            .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }
            .tag(1)
        }
        .task {
            await leaderboardManager.loadAll()
        }
    }
}

// MARK: - Home Tab

struct HomeTabContent: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var leaderboardManager: LeaderboardManager
    @State private var showCreateGameView = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ── Greeting + rank ──
                HomeHeaderView(
                    user: gameManager.currentUser,
                    rank: leaderboardManager.myRank,
                    isLoadingRank: leaderboardManager.isLoadingRank,
                    onSignOut: { userManager.signOut() }
                )
                .padding(.horizontal)

                // ── Play section ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("Play")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        // Solo card
                        NavigationLink(destination:
                            SoloModeMenuView()
                                .environmentObject(SoloModeManager())
                                .environmentObject(gameManager)
                        ) {
                            PlayModeCard(
                                icon: "person.fill",
                                title: "Solo",
                                subtitle: "Practice on your own",
                                colors: [.purple, .blue]
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Challenge card
                        Button(action: { showCreateGameView = true }) {
                            PlayModeCard(
                                icon: "person.2.fill",
                                title: "Challenge",
                                subtitle: "Compete with friends",
                                colors: [.green, .teal]
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .sheet(isPresented: $showCreateGameView) {
                            CreateGameView(showCreateGameView: $showCreateGameView)
                                .environmentObject(gameManager)
                        }
                    }
                    .padding(.horizontal)
                }

                // ── Active games ──
                if !gameManager.isDataLoaded {
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.3)
                        Text("Loading games…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ActiveGamesSection()
                        .environmentObject(gameManager)
                }
            }
            .padding(.vertical)
        }
        .background(
            Color(.systemBackground)
                .overlay(
                    Image("SpellingBee")
                        .resizable()
                        .scaledToFit()
                        .opacity(0.04)
                )
        )
        .navigationBarHidden(true)
        .refreshable {
            await gameManager.loadData()
            await leaderboardManager.loadAll()
        }
    }
}

// MARK: - Home Header

struct HomeHeaderView: View {
    let user: SpellGameUser?
    let rank: MyRankResponse?
    let isLoadingRank: Bool
    let onSignOut: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text(user?.displayName ?? "Speller")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                // Rank badge
                if isLoadingRank {
                    RankBadge(text: "Loading rank…", color: .gray)
                } else if let rank = rank {
                    RankBadge(
                        text: "Rank #\(rank.rank) of \(rank.totalPlayers)",
                        color: rankColor(rank.rank, total: rank.totalPlayers)
                    )
                }
            }

            Spacer()

            Button(action: onSignOut) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.title2)
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default: return "Good evening,"
        }
    }

    private func rankColor(_ rank: Int, total: Int) -> Color {
        guard total > 0 else { return .gray }
        let pct = Double(rank) / Double(total)
        if pct <= 0.10 { return .yellow }
        if pct <= 0.25 { return .blue }
        if pct <= 0.50 { return .green }
        return .secondary
    }
}

struct RankBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
    }
}

// MARK: - Play Mode Card

struct PlayModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle().fill(Color.white.opacity(0.25))
                )

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(
            LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: colors[0].opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Active Games Section

struct ActiveGamesSection: View {
    @EnvironmentObject var gameManager: GameManager

    private var userGames: [MultiUserGame] {
        gameManager.games.filter {
            $0.creatorID == gameManager.currentUser?.id ||
            $0.participantsIDs.contains(gameManager.currentUser?.id ?? "")
        }.sorted { g1, g2 in
            let s1 = gameManager.hasUserStartedGame(g1)
            let s2 = gameManager.hasUserStartedGame(g2)
            if s1 != s2 { return s1 }
            return g1.creationDate > g2.creationDate
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Games")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            if userGames.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No active games")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Start a solo session or challenge a friend!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(userGames) { game in
                        GameCardView(gameID: game.id)
                            .environmentObject(gameManager)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
