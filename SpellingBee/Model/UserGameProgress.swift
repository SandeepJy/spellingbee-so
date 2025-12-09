import Foundation

struct UserGameProgress: Identifiable, Codable, Hashable, Sendable {
    var id: String
    let userID: String
    let gameID: UUID
    var completedWordIndices: [Int]
    var correctlySpelledWords: [String]
    var currentWordIndex: Int
    var score: Int
    var lastUpdated: Date
    
    init(userID: String, gameID: UUID, completedWordIndices: [Int] = [], correctlySpelledWords: [String] = [], currentWordIndex: Int = 0, score: Int = 0, lastUpdated: Date = Date()) {
        self.userID = userID
        self.gameID = gameID
        self.completedWordIndices = completedWordIndices
        self.correctlySpelledWords = correctlySpelledWords
        self.currentWordIndex = currentWordIndex
        self.score = score
        self.lastUpdated = lastUpdated
        self.id = Self.generateID(userID: userID, gameID: gameID)
    }
    
    static func generateID(userID: String, gameID: UUID) -> String {
        return "\(userID)-\(gameID.uuidString)"
    }
    
    static func == (lhs: UserGameProgress, rhs: UserGameProgress) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
