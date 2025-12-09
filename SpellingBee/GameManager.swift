import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import AVFoundation

@MainActor
final class GameManager: ObservableObject {
    @Published var users: [SpellGameUser] = []
    @Published private(set) var currentUser: SpellGameUser?
    @Published var games: [MultiUserGame] = []
    @Published var userGameProgresses: [UserGameProgress] = []
    @Published var isDataLoaded = false
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var userManager: UserManager?
    private var gamesListener: ListenerRegistration?
    private var progressListener: ListenerRegistration?
    private var usersListener: ListenerRegistration?
    
    init() {}
    
    func setUserManager(_ userManager: UserManager) {
        self.userManager = userManager
        
        // Observe auth changes
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
    
    func loadData() async {
        guard userManager?.isAuthenticated == true else {
            print("Cannot load data: User not authenticated")
            return
        }
        
        async let usersResult: () = loadUsers()
        async let gamesResult: () = loadGames()
        async let progressResult: () = loadUserGameProgresses()
        
        _ = await (usersResult, gamesResult, progressResult)
        
        isDataLoaded = true
        print("All data loaded successfully")
    }
    
    private func clearData() {
        users = []
        games = []
        userGameProgresses = []
        currentUser = nil
        isDataLoaded = false
        
        gamesListener?.remove()
        progressListener?.remove()
        usersListener?.remove()
        gamesListener = nil
        progressListener = nil
        usersListener = nil
    }
    
    nonisolated func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
//    func uploadAudio(gameID: UUID, url: URL, word: String) async -> String? {
//        guard userManager?.isAuthenticated == true else {
//            return nil
//        }
//        
//        let storageRef = storage.reference().child("recordings/\(gameID)\(word).m4a")
//        
//        do {
//            _ = try await storageRef.putFileAsync(from: url)
//            let downloadURL = try await storageRef.downloadURL()
//            return downloadURL.absoluteString
//        } catch {
//            print("Error uploading audio: \(error)")
//            return nil
//        }
//    }
//    
//    func downloadAudio(gameID: UUID, word: String) async -> URL? {
//        guard userManager?.isAuthenticated == true else {
//            return nil
//        }
//        
//        let storageRef = storage.reference().child("recordings/\(gameID)\(word).m4a")
//        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let fileURL = documentsURL.appendingPathComponent("\(gameID)\(word).m4a")
//        
//        do {
//            _ = try await storageRef.writeAsync(toFile: fileURL)
//            return fileURL
//        } catch {
//            print("Error downloading audio: \(error)")
//            return nil
//        }
//    }
    
    func addUser(id: String, username: String, email: String) async {
        guard userManager?.isAuthenticated == true else {
            print("Cannot add user: Not authenticated")
            return
        }
        
        let newUser = SpellGameUser(id: id, username: username, email: email)
        users.append(newUser)
        await saveUser(newUser)
    }
    
    func createGame(creatorID: String, participantsIDs: Set<String>, difficulty: Int = 2, wordCount: Int = 10) async -> UUID? {
        guard userManager?.isAuthenticated == true else {
            print("Cannot create game: Not authenticated")
            return nil
        }
        
        let newGame = MultiUserGame(
            id: UUID(),
            creatorID: creatorID,
            participantsIDs: participantsIDs,
            words: [],
            isStarted: false,
            hasGeneratedWords: false,
            difficultyLevel: difficulty,
            wordCount: wordCount,
            creationDate: Date()
        )
        
        games.append(newGame)
        await saveGame(newGame)
        return newGame.id
    }
    
    func generateWordsForGame(gameID: UUID, wordCount: Int, difficulty: Int) async throws -> [Word] {
        guard userManager?.isAuthenticated == true else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard let gameIndex = games.firstIndex(where: { $0.id == gameID }) else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Game not found"])
        }
        
        print("🎲 Generating \(wordCount) words for game...")
        
        let wordLength: Int
        switch difficulty {
        case 1:
            wordLength = Int.random(in: 3...4)
        case 2:
            wordLength = 5
        case 3:
            wordLength = Int.random(in: 5...6)
        default:
            wordLength = 5
        }
        
        let wordsData = try await WordAPIService.shared.fetchRandomWordsWithDetails(count: wordCount, length: wordLength)
        
        print("✅ Successfully fetched \(wordsData.count) words from API")
        
        let words = wordsData.map { wordData in
            Word(
                word: wordData.word,
                soundURL: wordData.audioURL != nil ? URL(string: wordData.audioURL!) : nil,
                level: difficulty,
                createdByID: "system",
                gameID: gameID
            )
        }
        
        print("📝 Created \(words.count) Word objects")
        print("   Words: \(words.map { $0.word })")
        
        games[gameIndex].words = words
        games[gameIndex].hasGeneratedWords = true
        games[gameIndex].isStarted = true
        
        await saveGame(games[gameIndex])
        
        print("💾 Game saved with \(games[gameIndex].words.count) words")
        
        return words
    }
    
    func getCorrectWordCount(for gameID: UUID, userID: String? = nil) -> Int {
        let targetUserID = userID ?? currentUser?.id
        guard let targetUserID = targetUserID else { return 0 }
        
        if let progress = getUserProgress(for: gameID, userID: targetUserID) {
            return progress.correctlySpelledWords.count
        }
        return 0
    }
    
    func addWords(to gameID: UUID, words: [Word]) async -> Bool {
        guard userManager?.isAuthenticated == true else {
            print("Cannot add words: Not authenticated")
            return false
        }
        
        guard let index = games.firstIndex(where: { $0.id == gameID }) else {
            return false
        }
        
        games[index].words.append(contentsOf: words)
        await saveGame(games[index])
        return true
    }
    
    func startGame(gameID: UUID) async -> Bool {
        guard userManager?.isAuthenticated == true else {
            print("Cannot start game: Not authenticated")
            return false
        }
        
        guard let index = games.firstIndex(where: { $0.id == gameID }) else {
            return false
        }
        
        games[index].isStarted = true
        await saveGame(games[index])
        return true
    }
    
    private func loadUsers() async {
        do {
            let querySnapshot = try await db.collection("users").getDocuments()
            self.users = querySnapshot.documents.compactMap { document in
                try? document.data(as: SpellGameUser.self)
            }
        } catch {
            print("Error loading users: \(error)")
        }
    }
    
    private func saveUser(_ user: SpellGameUser) async {
        do {
            try db.collection("users").document(user.id).setData(from: user)
        } catch {
            print("Error saving user: \(error)")
        }
    }
    
    func saveUsers() async {
        guard userManager?.isAuthenticated == true else {
            print("Cannot save users: Not authenticated")
            return
        }
        
        for user in users {
            await saveUser(user)
        }
    }
    
    private func loadGames() async {
        do {
            let querySnapshot = try await db.collection("games").getDocuments()
            self.games = querySnapshot.documents.compactMap { document in
                let game = try? document.data(as: MultiUserGame.self)
                if let game = game {
                    print("📦 Loaded game \(game.id) with \(game.words.count) words")
                }
                return game
            }
            print("📦 Total games loaded: \(games.count)")
        } catch {
            print("Error loading games: \(error)")
        }
    }
    
    private func saveGame(_ game: MultiUserGame) async {
        do {
            try db.collection("games").document(game.id.uuidString).setData(from: game)
            print("💾 Saved game \(game.id) to Firestore with \(game.words.count) words")
        } catch {
            print("❌ Error saving game: \(error)")
        }
    }
    
    func saveGames() async {
        guard userManager?.isAuthenticated == true else {
            print("Cannot save games: Not authenticated")
            return
        }
        
        for game in games {
            await saveGame(game)
        }
    }
    
    // MARK: - User Game Progress Methods
    
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
        score: Int,
        userID: String? = nil
    ) async -> Bool {
        let targetUserID = userID ?? currentUser?.id
        guard let targetUserID = targetUserID else { return false }
        
        let progressID = UserGameProgress.generateID(userID: targetUserID, gameID: gameID)
        
        if let existingIndex = userGameProgresses.firstIndex(where: { $0.id == progressID }) {
            userGameProgresses[existingIndex].currentWordIndex = wordIndex
            userGameProgresses[existingIndex].completedWordIndices = completedWordIndices
            userGameProgresses[existingIndex].correctlySpelledWords = correctlySpelledWords
            userGameProgresses[existingIndex].score = score
            userGameProgresses[existingIndex].lastUpdated = Date()
            await saveUserGameProgress(userGameProgresses[existingIndex])
            return true
        } else {
            let newProgress = UserGameProgress(
                userID: targetUserID,
                gameID: gameID,
                completedWordIndices: completedWordIndices,
                correctlySpelledWords: correctlySpelledWords,
                currentWordIndex: wordIndex,
                score: score,
                lastUpdated: Date()
            )
            userGameProgresses.append(newProgress)
            await saveUserGameProgress(newProgress)
            return true
        }
    }
    
    private func loadUserGameProgresses() async {
        do {
            let querySnapshot = try await db.collection("userGameProgresses").getDocuments()
            self.userGameProgresses = querySnapshot.documents.compactMap { document in
                try? document.data(as: UserGameProgress.self)
            }
        } catch {
            print("Error loading user game progresses: \(error)")
        }
    }
    
    private func saveUserGameProgress(_ progress: UserGameProgress) async {
        do {
            try db.collection("userGameProgresses").document(progress.id).setData(from: progress)
        } catch {
            print("Error saving user game progress: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    func getUser(by id: String) -> SpellGameUser? {
        return users.first { $0.id == id }
    }
    
    func getParticipantNames(for game: MultiUserGame) -> [String] {
        return game.participantsIDs.compactMap { getUser(by: $0)?.displayName }
    }
    
    func getCreatorName(for game: MultiUserGame) -> String? {
        return getUser(by: game.creatorID)?.displayName
    }
    
    // MARK: - Reactive Data Loading
    
    func setupRealtimeListeners() {
        guard userManager?.isAuthenticated == true else {
            print("Cannot setup listeners: Not authenticated")
            return
        }
        
        print("🔔 Setting up real-time listeners...")
        
        usersListener = db.collection("users").addSnapshotListener { [weak self] querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching users: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            Task { @MainActor [weak self] in
                self?.users = documents.compactMap { document in
                    try? document.data(as: SpellGameUser.self)
                }
            }
        }
        
        gamesListener = db.collection("games").addSnapshotListener { [weak self] querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching games: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            Task { @MainActor [weak self] in
                let newGames = documents.compactMap { document -> MultiUserGame? in
                    let game = try? document.data(as: MultiUserGame.self)
                    if let game = game {
                        print("🔔 Real-time update: Game \(game.id) has \(game.words.count) words")
                    }
                    return game
                }
                self?.games = newGames
                print("🔔 Games updated via listener: \(newGames.count) total")
            }
        }
        
        progressListener = db.collection("userGameProgresses").addSnapshotListener { [weak self] querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching user game progresses: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            Task { @MainActor [weak self] in
                self?.userGameProgresses = documents.compactMap { document in
                    try? document.data(as: UserGameProgress.self)
                }
                print("🔔 Progress updated via listener: \(self?.userGameProgresses.count ?? 0) records")
            }
        }
    }
    
    func setGameDifficulty(gameID: UUID, level: Int) async -> Bool {
        guard userManager?.isAuthenticated == true else {
            return false
        }
        
        guard let index = games.firstIndex(where: { $0.id == gameID }) else {
            return false
        }
        
        games[index].difficultyLevel = max(1, min(5, level))
        await saveGame(games[index])
        return true
    }
}
