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
                        
                        // Games Display
                        let userGames = gameManager.games.filter {
                            $0.creatorID == gameManager.currentUser?.id ||
                            $0.participantsIDs.contains(gameManager.currentUser?.id ?? "")
                        }
                        
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(Array(game.participantsIDs.prefix(3)), id: \.self) { participantID in
                            if let participant = gameManager.getUser(by: participantID) {
                                PlayerProgressRow(
                                    participant: participant,
                                    correctCount: gameManager.getCorrectWordCount(for: game.id, userID: participantID),
                                    totalCount: game.wordCount
                                )
                            }
                        }
                        
                        if game.participantsIDs.count > 3 {
                            Text("... and \(game.participantsIDs.count - 3) more")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
        .preferredColorScheme(colorScheme) // Adapts to system dark/light mode
        .animation(.easeInOut(duration: 0.3), value: userManager.isAuthenticated)
        .onAppear {
            // Set up the relationship between managers
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
