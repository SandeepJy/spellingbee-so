import SwiftUI
import AVFoundation
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
                        
                        Button(action: {
                            userManager.signOut()
                        }) {
                            Image(systemName: "arrow.right.square")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let user = gameManager.currentUser {
                        Text("Welcome back, \(user.displayName)!")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .animation(.easeInOut, value: user.username)
                    }
                    
                    if !gameManager.isDataLoaded {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading your games...")
                                .foregroundColor(.secondary)
                        }
                        .frame(minHeight: 200)
                    } else {
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
                        
                        let userGames = gameManager.games.filter {
                            $0.creatorID == gameManager.currentUser?.id ||
                            $0.participantsIDs.contains(gameManager.currentUser?.id ?? "")
                        }.sorted { game1, game2 in
                            let game1Started = gameManager.hasUserStartedGame(game1)
                            let game2Started = gameManager.hasUserStartedGame(game2)
                            
                            if game1Started && !game2Started {
                                return true
                            } else if !game1Started && game2Started {
                                return false
                            } else {
                                return game1.creationDate > game2.creationDate
                            }
                        }
                        
                        if userGames.isEmpty {
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
                                    GameCardView(gameID: game.id)
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
                        Image("SpellingBee")
                            .resizable()
                            .scaledToFit()
                            .opacity(0.05)
                    )
            )
            .navigationBarHidden(true)
            .refreshable {
                await gameManager.loadData()
            }
        }
    }
}

// MARK: - Score Progress Bar for Game Card
struct UserScoreProgressBar: View {
    let currentScore: Int
    let bestPossibleScore: Int
    let userName: String
    let correctCount: Int
    let totalWords: Int
    
    private var progress: Double {
        guard bestPossibleScore > 0 else { return 0 }
        return min(Double(currentScore) / Double(bestPossibleScore), 1.0)
    }
    
    private var progressColor: Color {
        if progress >= 0.8 {
            return .green
        } else if progress >= 0.5 {
            return .blue
        } else if progress >= 0.3 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                Text(userName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Text("\(currentScore) pts")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor)
                
                Text("(\(correctCount)/\(totalWords))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [progressColor.opacity(0.7), progressColor]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * progress), height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

struct GameCardView: View {
    @EnvironmentObject var gameManager: GameManager
    let gameID: UUID
    
    private var game: MultiUserGame? {
        gameManager.games.first { $0.id == gameID }
    }
    
    private var bestPossibleScore: Int {
        return (game?.wordCount ?? 0) * 90
    }
    
    var body: some View {
        if let game = game {
            NavigationLink(destination: GamePlayView(game: game).environmentObject(gameManager)) {
                VStack(alignment: .leading, spacing: 12) {
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
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            if gameManager.isGameFinished(game) {
                                if let winner = gameManager.getGameWinner(game) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trophy.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                        Text(winner.id == gameManager.currentUser?.id ? "You won!" : "\(winner.displayName) won")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                                }
                            } else {
                                Text("Active")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }
                            
                            Text(formattedDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: 30) {
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
                        
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(bestPossibleScore)")
                                    .fontWeight(.medium)
                            }
                            Text("Max Pts")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if game.hasGeneratedWords {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Player Scores")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Best: \(bestPossibleScore) pts")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            ForEach(Array(game.participantsIDs), id: \.self) { participantID in
                                if let participant = gameManager.getUser(by: participantID) {
                                    let progress = gameManager.getUserProgress(for: game.id, userID: participantID)
                                    let score = progress?.score ?? 0
                                    let correctCount = progress?.correctlySpelledWords.count ?? 0
                                    
                                    UserScoreProgressBar(
                                        currentScore: score,
                                        bestPossibleScore: bestPossibleScore,
                                        userName: participant.displayName,
                                        correctCount: correctCount,
                                        totalWords: game.wordCount
                                    )
                                }
                            }
                        }
                        .padding(.top, 4)
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
    }
    
    private var difficultyColor: Color {
        guard let game = game else { return .orange }
        switch game.difficultyLevel {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .orange
        }
    }
    
    private var formattedDate: String {
        guard let game = game else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: game.creationDate, relativeTo: Date())
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


// Add this extension at the bottom of ContentView.swift
extension GameManager {
    func isGameFinished(_ game: MultiUserGame) -> Bool {
        return game.participantsIDs.allSatisfy { participantID in
            let progress = getUserProgress(for: game.id, userID: participantID)
            return (progress?.completedWordIndices.count ?? 0) >= game.wordCount
        }
    }
    
    func getGameWinner(_ game: MultiUserGame) -> SpellGameUser? {
        guard isGameFinished(game) else { return nil }
        
        var highestScore = 0
        var winnerId: String?
        
        for participantID in game.participantsIDs {
            if let progress = getUserProgress(for: game.id, userID: participantID) {
                if progress.score > highestScore {
                    highestScore = progress.score
                    winnerId = participantID
                }
            }
        }
        
        return winnerId != nil ? getUser(by: winnerId!) : nil
    }
    
    func hasUserStartedGame(_ game: MultiUserGame) -> Bool {
        guard let userID = currentUser?.id else { return false }
        let progress = getUserProgress(for: game.id, userID: userID)
        return progress != nil && progress!.completedWordIndices.count > 0
    }
}
