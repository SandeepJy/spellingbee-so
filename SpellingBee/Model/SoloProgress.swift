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

struct Achievement: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let xpReward: Int
    
    static let allAchievements: [Achievement] = [
        Achievement(id: "first_word", name: "First Steps", description: "Spell your first word correctly", icon: "star.fill", xpReward: 10),
        Achievement(id: "streak_3", name: "Getting Started", description: "Maintain a 3-day streak", icon: "flame.fill", xpReward: 25),
        Achievement(id: "streak_7", name: "Week Warrior", description: "Maintain a 7-day streak", icon: "flame.fill", xpReward: 50),
        Achievement(id: "streak_30", name: "Month Master", description: "Maintain a 30-day streak", icon: "flame.fill", xpReward: 200),
        Achievement(id: "perfect_10", name: "Perfect Ten", description: "Get 10 words correct in a row", icon: "checkmark.seal.fill", xpReward: 30),
        Achievement(id: "speed_demon", name: "Speed Demon", description: "Spell 5 words under 5 seconds each", icon: "bolt.fill", xpReward: 40),
        Achievement(id: "level_5", name: "Rising Star", description: "Reach level 5", icon: "star.circle.fill", xpReward: 50),
        Achievement(id: "level_10", name: "Expert", description: "Reach level 10", icon: "crown.fill", xpReward: 100),
        Achievement(id: "accuracy_80", name: "Sharpshooter", description: "Achieve 80% accuracy over 50 words", icon: "target", xpReward: 60),
        Achievement(id: "accuracy_95", name: "Perfectionist", description: "Achieve 95% accuracy over 100 words", icon: "scope", xpReward: 150),
        Achievement(id: "century", name: "Century", description: "Spell 100 words correctly", icon: "100.square.fill", xpReward: 75),
        Achievement(id: "no_hints", name: "Self Made", description: "Complete a session without using hints", icon: "brain.head.profile", xpReward: 40),
    ]
}
