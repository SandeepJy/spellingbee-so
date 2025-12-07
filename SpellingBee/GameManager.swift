
import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import AVFoundation
import Combine


class GameManager: ObservableObject {
    @Published var users: [SpellGameUser] = []  // List of available users
    @Published private(set) var currentUser: SpellGameUser?  // Currently logged-in user
    @Published var games: [MultiUserGame] = []  // List of all games
    @Published var userGameProgresses: [UserGameProgress] = []  // List of user game progress records
    @Published var isDataLoaded = false
    
    private var db = Firestore.firestore()
    private var storage = Storage.storage()
    private var userManager: UserManager?
    
    init() {
        // Note: Data loading will be triggered when user is authenticated
    }
    
    /**
     * Sets the user manager reference and sets up observers by listening to
     * current user and authentication state changes
     */
    func setUserManager(_ userManager: UserManager) {
        self.userManager = userManager
        
        // Combine userManager's authentication and current user state
        Publishers.CombineLatest(userManager.$isAuthenticated, userManager.$currentUser)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isAuthenticated, user) in
                guard let self = self else { return }
                
                self.currentUser = user
                
                if isAuthenticated && user != nil {
                    // User is authenticated and we have their details
                    if !self.isDataLoaded {
                        self.loadData()
                    }
                } else if !isAuthenticated {
                    // User is not authenticated, clear all data
                    self.clearData()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /**
     * Loads all data from Firestore (only called after authentication)
     */
    func loadData() {
        guard userManager?.isAuthenticated == true else {
            print("Cannot load data: User not authenticated")
            return
        }
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        loadUsers {
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        loadGames {
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        loadUserGameProgresses {
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isDataLoaded = true
            print("All data loaded successfully")
        }
    }
    
    /**
     * Clears all data when user logs out
     */
    private func clearData() {
        users = []
        games = []
        userGameProgresses = []
        currentUser = nil
        isDataLoaded = false
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func uploadAudio(gameID: UUID, url: URL, word: String, completion: @escaping (String?) -> Void) {
        guard userManager?.isAuthenticated == true else {
            completion(nil)
            return
        }
        
        let storageRef = storage.reference().child("recordings/\(gameID)\(word).m4a")
        let uploadTask = storageRef.putFile(from: url, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading audio: \(error)")
                completion(nil)
            } else {
                storageRef.downloadURL { (downloadURL, error) in
                    guard let downloadURL = downloadURL else {
                        completion(nil)
                        return
                    }
                    completion(downloadURL.absoluteString)
                }
            }
        }
    }
    
    func downloadAudio(gameID: UUID, word: String, completion: @escaping (URL?) -> Void ) {
        guard userManager?.isAuthenticated == true else {
            completion(nil)
            return
        }
        
        let storageRef = storage.reference().child("recordings/\(gameID)\(word).m4a")
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(gameID)\(word).m4a")
        
        storageRef.write(toFile: fileURL) { url, error in
            if let error = error {
                print("Error downloading audio: \(error)")
                completion(nil)
            } else {
                completion(url)
            }
        }
    }

    /**
     * Sets the current user - this is now handled automatically by auth state listener
     * This method is kept for compatibility but shouldn't be called directly
     */
    @available(*, deprecated, message: "Current user is now set automatically via auth state listener")
    func setCurrentUser(_ user: SpellGameUser) {
        // This is now handled automatically by the UserManager auth state listener
        // Keeping this method for backward compatibility
        print("Warning: setCurrentUser is deprecated, user is set automatically via auth state")
    }
    
   /**
     * Adds a new user to the system
     *
     * @param id Unique identifier for the user
     * @param username Display name for the user
     * @param email User's email address
     */
    func addUser(id: String, username: String, email: String) {
        guard userManager?.isAuthenticated == true else {
            print("Cannot add user: Not authenticated")
            return
        }
        
        let newUser = SpellGameUser(id: id, username: username, email: email)
        users.append(newUser)
        saveUser(newUser)
    }
    
    /**
     * Creates a new game with specified creator and participants
     * Now includes difficulty and word count
     */
    func createGame(creatorID: String, participantsIDs: Set<String>, difficulty: Int = 2, wordCount: Int = 10, completion: ((UUID?) -> Void)? = nil) {
        guard userManager?.isAuthenticated == true else {
            print("Cannot create game: Not authenticated")
            completion?(nil)
            return
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
        saveGame(newGame)
        completion?(newGame.id)
    }
    
    /**
     * Generates random words for a game using the API
     * Updated to support difficulty-based word length
     */
    func generateWordsForGame(gameID: UUID, wordCount: Int, difficulty: Int, completion: @escaping (Result<[Word], Error>) -> Void) {
        guard userManager?.isAuthenticated == true else {
            completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])))
            return
        }
        
        guard let gameIndex = games.firstIndex(where: { $0.id == gameID }) else {
            completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Game not found"])))
            return
        }
        
        // Determine word length based on difficulty
        let wordLength: Int
        switch difficulty {
        case 1: // Easy
            wordLength = Int.random(in: 3...4)
        case 2: // Medium
            wordLength = 5
        case 3: // Hard
            wordLength = Int.random(in: 5...6)
        default:
            wordLength = 5
        }
        
        // Fetch random words with audio
        WordAPIService.shared.fetchRandomWordsWithDetails(count: wordCount, length: wordLength) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let wordsData):
                    // Create Word objects from the API data
                    let words = wordsData.map { wordData in
                        Word(
                            word: wordData.word,
                            soundURL: wordData.audioURL != nil ? URL(string: wordData.audioURL!) : nil,
                            level: difficulty,
                            createdByID: "system", // Mark as system-generated
                            gameID: gameID
                        )
                    }
                    
                    // Update game with generated words
                    self.games[gameIndex].words = words
                    self.games[gameIndex].hasGeneratedWords = true
                    self.games[gameIndex].isStarted = true // Auto-start the game
                    self.saveGame(self.games[gameIndex])
                    
                    completion(.success(words))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /**
     * Gets user's correctly spelled word count for a game
     */
    func getCorrectWordCount(for gameID: UUID, userID: String? = nil) -> Int {
        let targetUserID = userID ?? currentUser?.id
        guard let targetUserID = targetUserID else { return 0 }
        
        if let progress = getUserProgress(for: gameID, userID: targetUserID) {
            return progress.correctlySpelledWords.count
        }
        return 0
    }
    
   /**
     * Adds words to an existing game
     *
     * @param gameID The game ID to update
     * @param words List of words to add to the game
     * @return Boolean indicating success
     */
    func addWords(to gameID: UUID, words: [Word]) -> Bool {
        guard userManager?.isAuthenticated == true else {
            print("Cannot add words: Not authenticated")
            return false
        }
        
        guard let index = games.firstIndex(where: { $0.id == gameID }) else {
            return false
        }
        
        games[index].words.append(contentsOf: words)
        saveGame(games[index])
        return true
    }
    
    /**
     * Marks a game as started
     *
     * @param gameID The game ID to start
     * @return Boolean indicating success
     */
    func startGame(gameID: UUID) -> Bool {
        guard userManager?.isAuthenticated == true else {
            print("Cannot start game: Not authenticated")
            return false
        }
        
        guard let index = games.firstIndex(where: { $0.id == gameID }) else {
            return false
        }
        
        games[index].isStarted = true
        saveGame(games[index])
        return true
    }
    
     /**
     * Loads users from Firestore with completion handler
     */
    private func loadUsers(completion: @escaping () -> Void) {
        db.collection("users").getDocuments { (querySnapshot, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading users: \(error)")
                } else {
                    self.users = querySnapshot?.documents.compactMap { document in
                        try? document.data(as: SpellGameUser.self)
                    } ?? []
                }
                completion()
            }
        }
    }
    
    /**
     * Saves a single user to Firestore
     */
    private func saveUser(_ user: SpellGameUser) {
        do {
            try db.collection("users").document(user.id).setData(from: user)
        } catch {
            print("Error saving user: \(error)")
        }
    }
    
    /**
     * Saves all users to Firestore (kept for backward compatibility)
     */
    func saveUsers() {
        guard userManager?.isAuthenticated == true else {
            print("Cannot save users: Not authenticated")
            return
        }
        
        for user in users {
            saveUser(user)
        }
    }
    
    /**
     * Loads games from Firestore with completion handler
     */
    private func loadGames(completion: @escaping () -> Void) {
        db.collection("games").getDocuments { (querySnapshot, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading games: \(error)")
                } else {
                    self.games = querySnapshot?.documents.compactMap { document in
                        try? document.data(as: MultiUserGame.self)
                    } ?? []
                }
                completion()
            }
        }
    }
    
    /**
     * Saves a single game to Firestore
     */
    private func saveGame(_ game: MultiUserGame) {
        do {
            try db.collection("games").document(game.id.uuidString).setData(from: game)
        } catch {
            print("Error saving game: \(error)")
        }
    }
    
    /**
     * Saves all games to Firestore (kept for backward compatibility)
     */
    func saveGames() {
        guard userManager?.isAuthenticated == true else {
            print("Cannot save games: Not authenticated")
            return
        }
        
        for game in games {
            saveGame(game)
        }
    }
    
    // MARK: - User Game Progress Methods
    
    /**
     * Gets user progress for a specific game
     *
     * @param gameID The game to get progress for
     * @param userID The user whose progress to retrieve (defaults to current user)
     * @return UserGameProgress if exists, nil otherwise
     */
    func getUserProgress(for gameID: UUID, userID: String? = nil) -> UserGameProgress? {
        let targetUserID = userID ?? currentUser?.id
        guard let targetUserID = targetUserID else { return nil }
        
        let progressID = UserGameProgress.generateID(userID: targetUserID, gameID: gameID)
        return userGameProgresses.first { $0.id == progressID }
    }
    
    func updateUserProgress(gameID: UUID,
                            wordIndex: Int,
                            completedWordIndices: [Int],
                            correctlySpelledWords: [String],
                            score: Int,
                            userID: String? = nil) -> Bool {
        let targetUserID = userID ?? currentUser?.id
        guard let targetUserID = targetUserID else { return false }
        
        let progressID = UserGameProgress.generateID(userID: targetUserID, gameID: gameID)
        
        if let existingIndex = userGameProgresses.firstIndex(where: { $0.id == progressID }) {
            userGameProgresses[existingIndex].currentWordIndex = wordIndex
            userGameProgresses[existingIndex].completedWordIndices = completedWordIndices
            userGameProgresses[existingIndex].correctlySpelledWords = correctlySpelledWords
            userGameProgresses[existingIndex].score = score
            userGameProgresses[existingIndex].lastUpdated = Date()
            saveUserGameProgress(userGameProgresses[existingIndex])
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
            saveUserGameProgress(newProgress)
            return true
        }
    }
    
    /**
     * Loads user game progress from Firestore with completion handler
     */
    private func loadUserGameProgresses(completion: @escaping () -> Void) {
        db.collection("userGameProgresses").getDocuments { (querySnapshot, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading user game progresses: \(error)")
                } else {
                    self.userGameProgresses = querySnapshot?.documents.compactMap { document in
                        try? document.data(as: UserGameProgress.self)
                    } ?? []
                }
                completion()
            }
        }
    }
    
    /**
     * Saves a single user game progress to Firestore
     */
    private func saveUserGameProgress(_ progress: UserGameProgress) {
        do {
            try db.collection("userGameProgresses").document(progress.id).setData(from: progress)
        } catch {
            print("Error saving user game progress: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    //Gets user object given a User ID
    func getUser(by id: String) -> SpellGameUser? {
        return users.first { $0.id == id }
    }
    
    //Gets display names for all participants
    func getParticipantNames(for game: MultiUserGame) -> [String] {
        return game.participantsIDs.compactMap { getUser(by: $0)?.displayName }
    }
    
    //Gets the display name of the creator
    func getCreatorName(for game: MultiUserGame) -> String? {
        return getUser(by: game.creatorID)?.displayName
    }
    
    // MARK: - Reactive Data Loading
    
    /**
     * Sets up real-time listeners for Firestore collections
     * This ensures data stays synchronized across devices
     */
    func setupRealtimeListeners() {
        guard userManager?.isAuthenticated == true else {
            print("Cannot setup listeners: Not authenticated")
            return
        }
        
        // Listen for users changes
        db.collection("users").addSnapshotListener { [weak self] querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching users: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self?.users = documents.compactMap { document in
                    try? document.data(as: SpellGameUser.self)
                }
            }
        }
        
        // Listen for games changes
        db.collection("games").addSnapshotListener { [weak self] querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching games: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self?.games = documents.compactMap { document in
                    try? document.data(as: MultiUserGame.self)
                }
            }
        }
        
        // Listen for user game progress changes
        db.collection("userGameProgresses").addSnapshotListener { [weak self] querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching user game progresses: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self?.userGameProgresses = documents.compactMap { document in
                    try? document.data(as: UserGameProgress.self)
                }
            }
        }
    }
    
    // Add this to GameManager class

    /**
     * Generates random words for a game using the API
     *
     * @param gameID The game to generate words for
     * @param completion Callback with success status
     */
    func generateWordsForGame(gameID: UUID, completion: @escaping (Result<[Word], Error>) -> Void) {
        guard userManager?.isAuthenticated == true else {
            completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])))
            return
        }
        
        guard let gameIndex = games.firstIndex(where: { $0.id == gameID }) else {
            completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Game not found"])))
            return
        }
        
        // Fetch 10 random words with audio
        WordAPIService.shared.fetchRandomWordsWithDetails(count: 10, length: 5) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let wordsData):
                    // Create Word objects from the API data
                    let words = wordsData.map { wordData in
                        Word(
                            word: wordData.word,
                            soundURL: wordData.audioURL != nil ? URL(string: wordData.audioURL!) : nil,
                            level: self.games[gameIndex].difficultyLevel,
                            createdByID: "system", // Mark as system-generated
                            gameID: gameID
                        )
                    }
                    
                    // Update game with generated words
                    self.games[gameIndex].words = words
                    self.games[gameIndex].hasGeneratedWords = true
                    self.saveGame(self.games[gameIndex])
                    
                    completion(.success(words))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /**
     * Sets the difficulty level for a game
     *
     * @param gameID The game to update
     * @param level Difficulty level (1-5)
     * @return Boolean indicating success
     */
    func setGameDifficulty(gameID: UUID, level: Int) -> Bool {
        guard userManager?.isAuthenticated == true else {
            return false
        }
        
        guard let index = games.firstIndex(where: { $0.id == gameID }) else {
            return false
        }
        
        games[index].difficultyLevel = max(1, min(5, level)) // Clamp between 1-5
        saveGame(games[index])
        return true
    }
}
