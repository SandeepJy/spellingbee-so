import Foundation

struct SoloSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let userID: String
    let level: Int
    let requiredStreak: Int
    let timeLimit: Double
    var words: [Word]
    var currentWordIndex: Int
    var currentStreak: Int
    var correctWords: [String]
    var misspelledWords: [MisspelledWord]
    var totalWordsAttempted: Int
    var hintsUsed: Int
    var totalXPEarned: Int
    var startDate: Date
    var endDate: Date?
    var isCompleted: Bool
    var sessionStats: SessionStats
    
    init(userID: String, level: Int, requiredStreak: Int, timeLimit: Double) {
        self.id = UUID()
        self.userID = userID
        self.level = level
        self.requiredStreak = requiredStreak
        self.timeLimit = timeLimit
        self.words = []
        self.currentWordIndex = 0
        self.currentStreak = 0
        self.correctWords = []
        self.misspelledWords = []
        self.totalWordsAttempted = 0
        self.hintsUsed = 0
        self.totalXPEarned = 0
        self.startDate = Date()
        self.endDate = nil
        self.isCompleted = false
        self.sessionStats = SessionStats()
    }
    
    var isLevelComplete: Bool {
        currentStreak >= requiredStreak
    }
    
    var accuracy: Int {
        guard totalWordsAttempted > 0 else { return 0 }
        return Int((Double(correctWords.count) / Double(totalWordsAttempted)) * 100)
    }
    
    var hasMoreWords: Bool {
        currentWordIndex < words.count
    }
}

struct SessionStats: Codable, Hashable, Sendable {
    var fastestWordTime: Double = 999
    var slowestWordTime: Double = 0
    var averageWordTime: Double = 0
    var totalWordTimes: Double = 0
    var wordTimesCount: Int = 0
    var longestStreak: Int = 0
    
    mutating func updateWithWordTime(_ time: Double, wasCorrect: Bool, currentStreak: Int) {
        if time < fastestWordTime {
            fastestWordTime = time
        }
        if time > slowestWordTime {
            slowestWordTime = time
        }
        
        totalWordTimes += time
        wordTimesCount += 1
        averageWordTime = totalWordTimes / Double(wordTimesCount)
        
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
    }
}
