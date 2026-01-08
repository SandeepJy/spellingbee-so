import Foundation

struct SoloSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let userID: String
    let level: Int
    let difficulty: Int // Word length for levels 1-10
    let wordCount: Int
    var words: [Word]
    var completedWordIndices: [Int]
    var correctWords: [String]
    var misspelledWords: [MisspelledWord]
    var hintsUsed: Int
    var totalXPEarned: Int
    var startDate: Date
    var endDate: Date?
    var sessionStats: SessionStats
    
    init(userID: String, level: Int, wordCount: Int = 10) {
        self.id = UUID()
        self.userID = userID
        self.level = level
        self.difficulty = Self.calculateDifficulty(for: level)
        self.wordCount = wordCount
        self.words = []
        self.completedWordIndices = []
        self.correctWords = []
        self.misspelledWords = []
        self.hintsUsed = 0
        self.totalXPEarned = 0
        self.startDate = Date()
        self.endDate = nil
        self.sessionStats = SessionStats()
    }
    
    static func calculateDifficulty(for level: Int) -> Int {
        // Levels 1-10: Use word length as difficulty
        // Level 1-2: 3-4 letters
        // Level 3-4: 4-5 letters
        // Level 5-6: 5-6 letters
        // Level 7-8: 6-7 letters
        // Level 9-10: 7-8 letters
        // Level 11+: Use curated hard words from Firebase
        
        switch level {
        case 1...2: return 3
        case 3...4: return 4
        case 5...6: return 5
        case 7...8: return 6
        case 9...10: return 7
        default: return 8 // Firebase curated words
        }
    }
    
    var isComplete: Bool {
        completedWordIndices.count >= wordCount
    }
    
    var accuracy: Int {
        guard wordCount > 0 else { return 0 }
        return Int((Double(correctWords.count) / Double(wordCount)) * 100)
    }
}

struct SessionStats: Codable, Hashable, Sendable {
    var fastestWordTime: Double = 999
    var slowestWordTime: Double = 0
    var averageWordTime: Double = 0
    var perfectStreak: Int = 0 // Consecutive correct words
    var longestPerfectStreak: Int = 0
    
    mutating func updateWithWordTime(_ time: Double, wasCorrect: Bool) {
        if time < fastestWordTime {
            fastestWordTime = time
        }
        if time > slowestWordTime {
            slowestWordTime = time
        }
        
        if wasCorrect {
            perfectStreak += 1
            if perfectStreak > longestPerfectStreak {
                longestPerfectStreak = perfectStreak
            }
        } else {
            perfectStreak = 0
        }
    }
}

enum HintType: String, Codable, Sendable {
    case wordLength = "Word Length"
    case firstLetter = "First Letter"
    case definition = "Enhanced Definition"
    case example = "Example Sentence"
    
    var cost: Int {
        switch self {
        case .wordLength: return 0 // Free
        case .firstLetter: return 1
        case .definition: return 1
        case .example: return 1
        }
    }
    
    var icon: String {
        switch self {
        case .wordLength: return "ruler"
        case .firstLetter: return "a.circle.fill"
        case .definition: return "book.fill"
        case .example: return "text.quote"
        }
    }
}
