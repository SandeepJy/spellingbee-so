import Foundation

struct SoloLevelConfig {
    let level: Int
    let requiredStreak: Int
    let wordSource: WordSource
    let timeLimit: Double // seconds per word
    
    enum WordSource {
        case randomAPI(minLength: Int, maxLength: Int)
        case firebaseAPI(minLevel: Int, maxLevel: Int)
    }
    
    var missionText: String {
        "Spell \(requiredStreak) words correctly in a row"
    }
    
    var difficultyDescription: String {
        switch wordSource {
        case .randomAPI(let minLen, let maxLen):
            return "\(minLen)-\(maxLen) letter words"
        case .firebaseAPI(let minLvl, let maxLvl):
            return "Difficulty \(minLvl)-\(maxLvl) words"
        }
    }
    
    var tierName: String {
        switch level {
        case 1...5: return "Beginner"
        case 6...10: return "Intermediate"
        case 11...15: return "Advanced"
        case 16...20: return "Expert"
        default: return "Master"
        }
    }
    
    var tierColor: String {
        switch level {
        case 1...5: return "green"
        case 6...10: return "blue"
        case 11...15: return "purple"
        case 16...20: return "red"
        default: return "yellow"
        }
    }
    
    // Fetch more words than needed since user might get some wrong
    var wordFetchCount: Int {
        return requiredStreak + 15
    }
    
    static func config(for level: Int) -> SoloLevelConfig {
        switch level {
        case 1...5:
            return SoloLevelConfig(
                level: level,
                requiredStreak: 5,
                wordSource: .randomAPI(minLength: 5, maxLength: 7),
                timeLimit: 5.0
            )
        case 6...10:
            return SoloLevelConfig(
                level: level,
                requiredStreak: 7,
                wordSource: .firebaseAPI(minLevel: 1, maxLevel: 3),
                timeLimit: 5.0
            )
        case 11...15:
            return SoloLevelConfig(
                level: level,
                requiredStreak: 10,
                wordSource: .firebaseAPI(minLevel: 4, maxLevel: 6),
                timeLimit: 5.0
            )
        case 16...20:
            return SoloLevelConfig(
                level: level,
                requiredStreak: 12,
                wordSource: .firebaseAPI(minLevel: 7, maxLevel: 9),
                timeLimit: 5.0
            )
        default:
            return SoloLevelConfig(
                level: level,
                requiredStreak: 12,
                wordSource: .firebaseAPI(minLevel: 7, maxLevel: 9),
                timeLimit: 5.0
            )
        }
    }
}
