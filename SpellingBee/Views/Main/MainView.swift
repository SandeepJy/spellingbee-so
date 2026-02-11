import SwiftUI

struct MainView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var leaderboardManager = LeaderboardManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                HomeTabContent(selectedTab: $selectedTab)
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
    @Binding var selectedTab: Int
    @State private var showCreateGameView = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Greeting header
                HomeGreetingHeader(
                    user: gameManager.currentUser,
                    onSignOut: { userManager.signOut() }
                )
                .padding(.horizontal)

                // Rank Card (prominent)
                RankCard(
                    rank: leaderboardManager.myRank,
                    isLoading: leaderboardManager.isLoadingRank,
                    onLeaderboardTap: { selectedTab = 1 }
                )
                .padding(.horizontal)

                // Play section
                PlayModesSection(
                    onChallengeTap: { showCreateGameView = true }
                )
                .environmentObject(gameManager)

                // Active Games Carousel
                if !gameManager.isDataLoaded {
                    LoadingGamesPlaceholder()
                } else {
                    ActiveGamesCarouselSection()
                        .environmentObject(gameManager)
                }

                // Top Spellers Card
                TopSpellersShowcaseCard(
                    topSpellers: leaderboardManager.topSpellers,
                    isLoading: leaderboardManager.isLoadingTop,
                    onViewAllTap: { selectedTab = 1 }
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(
            Color(.systemBackground)
                .overlay(
                    Image("SpellingBee")
                        .resizable()
                        .scaledToFit()
                        .opacity(0.03)
                )
        )
        .navigationBarHidden(true)
        .refreshable {
            await gameManager.loadData()
            await leaderboardManager.loadAll()
        }
        .sheet(isPresented: $showCreateGameView) {
            CreateGameView(showCreateGameView: $showCreateGameView)
                .environmentObject(gameManager)
        }
    }
}

// MARK: - Greeting Header

struct HomeGreetingHeader: View {
    let user: SpellGameUser?
    let onSignOut: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(user?.displayName ?? "Speller")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Spacer()

            Button(action: onSignOut) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.title3)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(8)
                    .background(Circle().fill(Color.red.opacity(0.1)))
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
}

// MARK: - Play Modes Section

struct PlayModesSection: View {
    @EnvironmentObject var gameManager: GameManager
    let onChallengeTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Play")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            HStack(spacing: 12) {
                // Solo Mode Card
                NavigationLink(destination:
                    SoloModeMenuView()
                        .environmentObject(SoloModeManager())
                        .environmentObject(gameManager)
                ) {
                    PlayModeCard(
                        icon: "person.fill",
                        title: "Solo",
                        subtitle: "Play at your own pace",
                        colors: [.purple, .blue]
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Challenge Card
                Button(action: onChallengeTap) {
                    PlayModeCard(
                        icon: "person.2.fill",
                        title: "Challenge",
                        subtitle: "Compete with friends",
                        colors: [.green, .teal]
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Play Mode Card

struct PlayModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
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
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130)
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

// MARK: - Loading Placeholder

struct LoadingGamesPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading games…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding()
    }
}

// MARK: - Active Games Carousel Section

struct ActiveGamesCarouselSection: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var currentIndex: Int = 0

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
            HStack {
                Text("Active Games")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                if !userGames.isEmpty {
                    Text("\(userGames.count) game\(userGames.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            if userGames.isEmpty {
                EmptyGamesCard()
                    .padding(.horizontal)
            } else {
                // Carousel
                SnapCarousel(
                    items: userGames,
                    itemWidth: UIScreen.main.bounds.width - 80,
                    itemSpacing: 12,
                    peekAmount: 20
                ) { game in
                    CompactGameCard(game: game)
                        .environmentObject(gameManager)
                }
                .frame(height: 140)
                
                // Page indicator
                if userGames.count > 1 {
                    HStack {
                        Spacer()
                        CarouselPageIndicator(
                            totalPages: userGames.count,
                            currentPage: currentIndex
                        )
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Empty Games Card

struct EmptyGamesCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No active games")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Start a solo session or challenge a friend!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
    }
}
