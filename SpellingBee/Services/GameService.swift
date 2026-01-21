import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct GameService: Sendable {
    
    // MARK: - Game Operations
    
    func saveGame(_ game: MultiUserGame) throws {
        try Firestore.firestore().collection("games").document(game.id.uuidString).setData(from: game)
    }
    
    func loadGames() async throws -> [MultiUserGame] {
        let querySnapshot = try await Firestore.firestore().collection("games").getDocuments()
        return querySnapshot.documents.compactMap { document in
            try? document.data(as: MultiUserGame.self)
        }
    }
    
    func createGameWithWords(
        creatorID: String,
        participantsIDs: Set<String>,
        difficulty: Int,
        wordCount: Int
    ) async throws -> MultiUserGame {
        let gameID = UUID()
        
        // Get user token for hard difficulty
        var userToken: String?
        if difficulty == 3 {
            guard let user = Auth.auth().currentUser else {
                throw GameServiceError.notAuthenticated
            }
            userToken = try await user.getIDToken()
        }
        
        let wordsData = try await WordAPIService.shared.fetchWordsForMultiplayer(
            difficulty: difficulty,
            count: wordCount,
            userToken: userToken
        )
        
        let words = wordsData.map { wordData in
            Word(
                word: wordData.word,
                soundURL: wordData.audioURL != nil ? URL(string: wordData.audioURL!) : nil,
                level: difficulty,
                definition: wordData.definition,
                exampleSentence: wordData.exampleSentence,
                createdByID: "system",
                gameID: gameID
            )
        }
        
        let game = MultiUserGame(
            id: gameID,
            creatorID: creatorID,
            participantsIDs: participantsIDs,
            words: words,
            isStarted: true,
            hasGeneratedWords: true,
            difficultyLevel: difficulty,
            wordCount: wordCount,
            creationDate: Date()
        )
        
        try saveGame(game)
        return game
    }
    
    // MARK: - Progress Operations
    
    func saveProgress(_ progress: UserGameProgress) throws {
        try Firestore.firestore().collection("userGameProgresses").document(progress.id).setData(from: progress)
    }
    
    func loadProgresses() async throws -> [UserGameProgress] {
        let querySnapshot = try await Firestore.firestore().collection("userGameProgresses").getDocuments()
        return querySnapshot.documents.compactMap { document in
            try? document.data(as: UserGameProgress.self)
        }
    }
    
    // MARK: - Real-time Listeners
    
    func gamesListener(
        onUpdate: @escaping @Sendable ([MultiUserGame]) -> Void
    ) -> ListenerRegistration {
        return Firestore.firestore().collection("games").addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching games: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            let games = documents.compactMap { document in
                try? document.data(as: MultiUserGame.self)
            }
            onUpdate(games)
        }
    }
    
    func progressListener(
        onUpdate: @escaping @Sendable ([UserGameProgress]) -> Void
    ) -> ListenerRegistration {
        return Firestore.firestore().collection("userGameProgresses").addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching progress: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            let progresses = documents.compactMap { document in
                try? document.data(as: UserGameProgress.self)
            }
            onUpdate(progresses)
        }
    }
}

enum GameServiceError: Error, Sendable {
    case notAuthenticated
    case gameNotFound
    case saveFailed
}
