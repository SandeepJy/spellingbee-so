import Foundation

struct SoloProgress: Identifiable, Codable, Hashable, Sendable {
    var id: String // userID
    var level: Int
    var xp: Int
    var xpToNextLevel: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastPlayedDate: Date?
    var totalWordsSpelled: Int
    var totalCorrectWords: Int
    var totalIncorrectWords: Int
    var averageAccuracy: Double
    var totalHintsUsed: Int
    var availableHints: Int // Daily free hints
    var lastHintResetDate: Date?
    var achievements: [String] // Achievement IDs
    var levelHistory: [LevelStats] // Performance per level
    
    init(userID: String) {
        self.id = userID
        self.level = 1
        self.xp = 0
        self.xpToNextLevel = 100
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastPlayedDate = nil
        self.totalWordsSpelled = 0
        self.totalCorrectWords = 0
        self.totalIncorrectWords = 0
        self.averageAccuracy = 0.0
        self.totalHintsUsed = 0
        self.availableHints = 5
        self.lastHintResetDate = Date()
        self.achievements = []
        self.levelHistory = []
    }
    
    static func == (lhs: SoloProgress, rhs: SoloProgress) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var accuracyPercentage: Int {
        guard totalWordsSpelled > 0 else { return 0 }
        return Int((Double(totalCorrectWords) / Double(totalWordsSpelled)) * 100)
    }
    
    var progressToNextLevel: Double {
        guard xpToNextLevel > 0 else { return 0 }
        return Double(xp) / Double(xpToNextLevel)
    }
}

struct LevelStats: Codable, Hashable, Sendable {
    let level: Int
    var attempts: Int
    var correctWords: Int
    var totalWords: Int
    var averageTime: Double
    var bestAccuracy: Int
    
    var accuracy: Int {
        guard totalWords > 0 else { return 0 }
        return Int((Double(correctWords) / Double(totalWords)) * 100)
    }
}
