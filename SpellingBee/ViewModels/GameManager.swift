import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore

@MainActor
final class GameManager: ObservableObject {
    @Published var users: [SpellGameUser] = []
    @Published private(set) var currentUser: SpellGameUser?
    @Published var games: [MultiUserGame] = []
    @Published var userGameProgresses: [UserGameProgress] = []
    @Published var isDataLoaded = false
    
    private let gameService = GameService()
    private let userService = UserService()
    private var userManager: UserManager?
    
    private var gamesListener: ListenerRegistration?
    private var progressListener: ListenerRegistration?
    private var usersListener: ListenerRegistration?
    private var gameIDsBeingCreated: Set<UUID> = []
    
    init() {}
    
    func setUserManager(_ userManager: UserManager) {
        self.userManager = userManager
        
        Task {
            for await _ in userManager.$isAuthenticated.values {
                await handleAuthChange(userManager: userManager)
            }
        }
    }
    
    private func handleAuthChange(userManager: UserManager) async {
        self.currentUser = userManager.currentUser
        
        if userManager.isAuthenticated && userManager.currentUser != nil {
            if !isDataLoaded {
                await loadData()
                setupRealtimeListeners()
            }
        } else if !userManager.isAuthenticated {
            clearData()
        }
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        guard userManager?.isAuthenticated == true else { return }
        
        async let usersResult: () = loadUsers()
        async let gamesResult: () = loadGames()
        async let progressResult: () = loadUserGameProgresses()
        
        _ = await (usersResult, gamesResult, progressResult)
        isDataLoaded = true
    }
    
    private func loadUsers() async {
        do {
            users = try await userService.loadUsers()
        } catch {
            print("Error loading users: \(error)")
        }
    }
    
    private func loadGames() async {
        do {
            games = try await gameService.loadGames()
        } catch {
            print("Error loading games: \(error)")
        }
    }
    
    private func loadUserGameProgresses() async {
        do {
            userGameProgresses = try await gameService.loadProgresses()
        } catch {
            print("Error loading progress: \(error)")
        }
    }
    
    private func clearData() {
        users = []
        games = []
        userGameProgresses = []
        currentUser = nil
        isDataLoaded = false
        gameIDsBeingCreated = []
        
        gamesListener?.remove()
        progressListener?.remove()
        usersListener?.remove()
    }
    
    // MARK: - Game Operations
    
    func createGameWithWords(
        creatorID: String,
        participantsIDs: Set<String>,
        difficulty: Int = 2,
        wordCount: Int = 10
    ) async throws -> UUID {
        let gameID = UUID()
        gameIDsBeingCreated.insert(gameID)
        defer { gameIDsBeingCreated.remove(gameID) }
        
        let game = try await gameService.createGameWithWords(
            creatorID: creatorID,
            participantsIDs: participantsIDs,
            difficulty: difficulty,
            wordCount: wordCount
        )
        
        games.append(game)
        return game.id
    }
    
    // MARK: - Progress Management
    
    func getUserProgress(for gameID: UUID, userID: String? = nil) -> UserGameProgress? {
        let targetUserID = userID ?? currentUser?.id
        guard let targetUserID = targetUserID else { return nil }
        
        let progressID = UserGameProgress.generateID(userID: targetUserID, gameID: gameID)
        return userGameProgresses.first { $0.id == progressID }
    }
    
    func updateUserProgress(
        gameID: UUID,
        wordIndex: Int,
        completedWordIndices: [Int],
        correctlySpelledWords: [String],
        misspelledWords: [MisspelledWord],
        score: Int,
        userID: String? = nil
    ) async -> Bool {
        let targetUserID = userID ?? currentUser?.id
        guard let targetUserID = targetUserID else { return false }
        
        let progressID = UserGameProgress.generateID(userID: targetUserID, gameID: gameID)
        
        let progress: UserGameProgress
        if let existingIndex = userGameProgresses.firstIndex(where: { $0.id == progressID }) {
            var existing = userGameProgresses[existingIndex]
            existing.currentWordIndex = wordIndex
            existing.completedWordIndices = completedWordIndices
            existing.correctlySpelledWords = correctlySpelledWords
            existing.misspelledWords = misspelledWords
            existing.score = score
            existing.lastUpdated = Date()
            userGameProgresses[existingIndex] = existing
            progress = existing
        } else {
            progress = UserGameProgress(
                userID: targetUserID,
                gameID: gameID,
                completedWordIndices: completedWordIndices,
                correctlySpelledWords: correctlySpelledWords,
                misspelledWords: misspelledWords,
                currentWordIndex: wordIndex,
                score: score
            )
            userGameProgresses.append(progress)
        }
        
        do {
            try gameService.saveProgress(progress)
            return true
        } catch {
            print("Error saving progress: \(error)")
            return false
        }
    }
    
    // MARK: - Utility Methods
    
    func getUser(by id: String) -> SpellGameUser? {
        users.first { $0.id == id }
    }
    
    func getCreatorName(for game: MultiUserGame) -> String? {
        getUser(by: game.creatorID)?.displayName
    }
    
    func getCorrectWordCount(for gameID: UUID, userID: String? = nil) -> Int {
        getUserProgress(for: gameID, userID: userID)?.correctlySpelledWords.count ?? 0
    }
    
    // MARK: - Game State Helpers
    
    func isGameFinished(_ game: MultiUserGame) -> Bool {
        game.participantsIDs.allSatisfy { participantID in
            let progress = getUserProgress(for: game.id, userID: participantID)
            return (progress?.completedWordIndices.count ?? 0) >= game.wordCount
        }
    }
    
    func getGameWinner(_ game: MultiUserGame) -> SpellGameUser? {
        guard isGameFinished(game) else { return nil }
        
        var highestScore = 0
        var winnerId: String?
        
        for participantID in game.participantsIDs {
            if let progress = getUserProgress(for: game.id, userID: participantID),
               progress.score > highestScore {
                highestScore = progress.score
                winnerId = participantID
            }
        }
        
        return winnerId.flatMap { getUser(by: $0) }
    }
    
    func hasUserStartedGame(_ game: MultiUserGame) -> Bool {
        guard let userID = currentUser?.id else { return false }
        let progress = getUserProgress(for: game.id, userID: userID)
        return progress != nil && progress!.completedWordIndices.count > 0
    }
    
    // MARK: - Real-time Listeners
    
    func setupRealtimeListeners() {
        guard userManager?.isAuthenticated == true else { return }
        
        usersListener = userService.usersListener { [weak self] users in
            Task { @MainActor in
                self?.users = users
            }
        }
        
        gamesListener = gameService.gamesListener { [weak self] games in
            Task { @MainActor in
                guard let self = self else { return }
                
                var updatedGames = games.filter { game in
                    !self.gameIDsBeingCreated.contains(game.id)
                }
                
                for gameID in self.gameIDsBeingCreated {
                    if let localGame = self.games.first(where: { $0.id == gameID }) {
                        updatedGames.append(localGame)
                    }
                }
                
                self.games = updatedGames
            }
        }
        
        progressListener = gameService.progressListener { [weak self] progresses in
            Task { @MainActor in
                self?.userGameProgresses = progresses
            }
        }
    }
}
