import SwiftUI
import AVFoundation
import Combine
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct MainView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var userManager: UserManager
    @State private var showCreateGameView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Spelling Bee")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        
                        // Profile/Settings button
                        Button(action: {
                            // TODO: Add profile/settings action
                        }) {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(gameManager.currentUser?.initialLetter ?? "U")
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                )
                        }
                        
                        // Sign out button
                        Button(action: {
                            userManager.signOut()
                        }) {
                            Image(systemName: "arrow.right.square")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Welcome message
                    if let user = gameManager.currentUser {
                        Text("Welcome back, \(user.displayName)!")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .animation(.easeInOut, value: user.username)
                    }
                    
                    // Loading indicator while data is being fetched
                    if !gameManager.isDataLoaded {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading your games...")
                                .foregroundColor(.secondary)
                        }
                        .frame(minHeight: 200)
                    } else {
                        // New Game Button
                        Button(action: { showCreateGameView = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Start New Game")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(gradient: Gradient(colors: [.green, .blue]),
                                               startPoint: .leading,
                                               endPoint: .trailing)
                            )
                            .cornerRadius(15)
                            .shadow(radius: 5)
                        }
                        .sheet(isPresented: $showCreateGameView) {
                            CreateGameView(showCreateGameView: $showCreateGameView)
                                .environmentObject(gameManager)
                        }
                        .padding(.horizontal)
                        
                        // Games Display - Sort by creation date (most recent first)
                        let userGames = gameManager.games
                            .filter {
                                $0.creatorID == gameManager.currentUser?.id ||
                                $0.participantsIDs.contains(gameManager.currentUser?.id ?? "")
                            }
                            .sorted { $0.creationDate > $1.creationDate }
                        
                        if userGames.isEmpty {
                            // Empty state
                            VStack(spacing: 20) {
                                Image(systemName: "gamecontroller")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("No games yet")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("Create your first spelling bee game to get started!")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(minHeight: 200)
                            .padding()
                        } else {
                            VStack(spacing: 15) {
                                ForEach(userGames) { game in
                                    GameCardView(game: game)
                                        .environmentObject(gameManager)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(
                Color(.systemBackground)
                    .overlay(
                        Image("SpellingBee") // Optional: Add a subtle game-themed background
                            .resizable()
                            .scaledToFit()
                            .opacity(0.05)
                    )
            )
            .navigationBarHidden(true)
            .refreshable {
                // Pull to refresh functionality
                gameManager.loadData()
            }
        }
    }
}

struct GameCardView: View {
    @EnvironmentObject var gameManager: GameManager
    let game: MultiUserGame
    
    // Calculate best possible score (5 seconds per word = 90 points each)
    private var bestPossibleScore: Int {
        return game.wordCount * 90
    }
    
    var body: some View {
        NavigationLink(destination: GamePlayView(game: game).environmentObject(gameManager)) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.difficultyText)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(difficultyColor)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        
                        Text("Created by \(gameManager.getCreatorName(for: game) ?? "Unknown")")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Active badge
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
                
                Divider()
                
                // Game stats
                HStack(spacing: 30) {
                    // Player count
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                            Text("\(game.participantsIDs.count)")
                                .fontWeight(.medium)
                        }
                        Text("Players")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Total words
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "text.book.closed.fill")
                                .foregroundColor(.orange)
                            Text("\(game.wordCount)")
                                .fontWeight(.medium)
                        }
                        Text("Words")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Player Progress
                if game.hasGeneratedWords {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Player Progress")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        ForEach(Array(game.participantsIDs.sorted()), id: \.self) { participantID in
                            if let participant = gameManager.getUser(by: participantID) {
                                PlayerScoreProgressRow(
                                    participant: participant,
                                    gameID: game.id,
                                    bestPossibleScore: bestPossibleScore,
                                    gameManager: gameManager
                                )
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.gray.opacity(0.2), radius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var difficultyColor: Color {
        switch game.difficultyLevel {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .orange
        }
    }
}

struct PlayerScoreProgressRow: View {
    let participant: SpellGameUser
    let gameID: UUID
    let bestPossibleScore: Int
    let gameManager: GameManager
    
    private var userProgress: UserGameProgress? {
        gameManager.getUserProgress(for: gameID, userID: participant.id)
    }
    
    private var score: Int {
        userProgress?.score ?? 0
    }
    
    private var correctCount: Int {
        userProgress?.correctlySpelledWords.count ?? 0
    }
    
    private var completedCount: Int {
        userProgress?.completedWordIndices.count ?? 0
    }
    
    private var totalWords: Int {
        gameManager.games.first(where: { $0.id == gameID })?.wordCount ?? 0
    }
    
    private var progressPercentage: Double {
        guard bestPossibleScore > 0 else { return 0 }
        return min(Double(score) / Double(bestPossibleScore), 1.0)
    }
    
    private var isComplete: Bool {
        completedCount >= totalWords && totalWords > 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(participant.initialLetter)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        )
                    
                    Text(participant.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Score display
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(score) pts")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("\(correctCount)/\(totalWords)")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    progressPercentage > 0.7 ? .green : .orange,
                                    progressPercentage > 0.7 ? .blue : .red
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progressPercentage)
                }
            }
            .frame(height: 8)
            
            // Progress details
            HStack {
                Text("\(Int(progressPercentage * 100))% of best score")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Best: \(bestPossibleScore) pts")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct PlayerProgressRow: View {
    let participant: SpellGameUser
    let correctCount: Int
    let totalCount: Int
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(participant.initialLetter)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                Text(participant.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 4) {
                Text("\(correctCount)/\(totalCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(correctCount == totalCount ? .green : .primary)
                
                if correctCount == totalCount {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

// Status Badge
struct StatusBadge: View {
    let isStarted: Bool
    
    var body: some View {
        Text(isStarted ? "Active" : "Pending")
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isStarted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
            .foregroundColor(isStarted ? .green : .orange)
            .cornerRadius(8)
    }
}

// Word Progress Row
struct WordProgressRow: View {
    let participant: SpellGameUser
    let game: MultiUserGame
    
    var body: some View {
        HStack(spacing: 8) {
            Text(participant.displayName)
                .font(.caption)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            
            ProgressView(value: Double(wordCount), total: 5.0)
                .progressViewStyle(LinearProgressViewStyle(tint: wordCount == 5 ? .green : .blue))
                .frame(height: 8)
            
            Text("\(wordCount)/5")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30)
        }
    }
    
    private var wordCount: Int {
        game.words.filter { $0.createdByID == participant.id }.count
    }
}

struct ContentView: View {
    @StateObject private var userManager = UserManager()
    @StateObject private var gameManager = GameManager()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            Group {
                if userManager.isAuthenticated && gameManager.currentUser != nil {
                    MainView()
                        .environmentObject(userManager)
                        .environmentObject(gameManager)
                        .transition(.opacity)
                } else {
                    LoginRegisterView()
                        .environmentObject(userManager)
                        .environmentObject(gameManager)
                        .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(colorScheme)
        .animation(.easeInOut(duration: 0.3), value: userManager.isAuthenticated)
        .onAppear {
            gameManager.setUserManager(userManager)
        }
    }
}

// Participant Row (reused from previous code)
struct ParticipantRow: View {
    let participant: SpellGameUser?
    let game: MultiUserGame
    
    var body: some View {
        if let participant = participant {
            HStack {
                Text(participant.displayName)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text("\(wordCount)/5 words")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var wordCount: Int {
        game.words.filter { $0.createdByID == participant?.id }.count
    }
}

#Preview {
    ContentView()
}
