import Foundation

// MARK: - Solo Game Models
struct SoloGameSession: Identifiable, Codable {
    let id: UUID
    let userID: String
    let startDate: Date
    var endDate: Date?
    var wordsCompleted: [SoloWordAttempt]
    var currentStreak: Int
    var sessionXP: Int
    var difficultyLevel: Int
    var isCompleted: Bool
    
    init(userID: String, difficultyLevel: Int) {
        self.id = UUID()
        self.userID = userID
        self.startDate = Date()
        self.wordsCompleted = []
        self.currentStreak = 0
        self.sessionXP = 0
        self.difficultyLevel = difficultyLevel
        self.isCompleted = false
    }
}

struct SoloWordAttempt: Codable {
    let word: String
    let userAnswer: String
    let isCorrect: Bool
    let timeElapsed: Double
    let xpEarned: Int
    let hintsUsed: [HintType]
    let attemptDate: Date
}

enum HintType: String, Codable, CaseIterable {
    case definition = "definition"
    case example = "example"
    case wordLength = "wordLength"
    case firstLetter = "firstLetter"
    
    var cost: Int {
        switch self {
        case .wordLength: return 5
        case .firstLetter: return 10
        case .definition: return 15
        case .example: return 20
        }
    }
    
    var displayName: String {
        switch self {
        case .definition: return "Show Definition"
        case .example: return "Show Example"
        case .wordLength: return "Show Length"
        case .firstLetter: return "Show First Letter"
        }
    }
    
    var icon: String {
        switch self {
        case .definition: return "book.fill"
        case .example: return "text.quote"
        case .wordLength: return "ruler"
        case .firstLetter: return "textformat.abc"
        }
    }
}

// MARK: - User Progress for Solo Mode
struct SoloModeProgress: Codable {
    var totalXP: Int
    var currentLevel: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastPracticeDate: Date?
    var totalWordsSpelled: Int
    var correctWords: Int
    var averageAccuracy: Double
    var unlockedAchievements: [String]
    var dailyXP: [Date: Int] // Track XP by day
    
    init() {
        self.totalXP = 0
        self.currentLevel = 1
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalWordsSpelled = 0
        self.correctWords = 0
        self.averageAccuracy = 0
        self.unlockedAchievements = []
        self.dailyXP = [:]
    }
    
    // XP required for each level
    static func xpRequiredForLevel(_ level: Int) -> Int {
        return level * 100 + (level - 1) * 50 // 100, 250, 450, 700...
    }
    
    // Calculate current level progress
    var progressToNextLevel: Double {
        let currentLevelXP = SoloModeProgress.xpRequiredForLevel(currentLevel)
        let nextLevelXP = SoloModeProgress.xpRequiredForLevel(currentLevel + 1)
        let xpInCurrentLevel = totalXP - currentLevelXP
        let xpNeededForNextLevel = nextLevelXP - currentLevelXP
        return Double(xpInCurrentLevel) / Double(xpNeededForNextLevel)
    }
    
    var xpToNextLevel: Int {
        return SoloModeProgress.xpRequiredForLevel(currentLevel + 1) - totalXP
    }
}
