import SwiftUI

struct MultiUserGame: Identifiable, Codable, Hashable {
    let id: UUID
    var creatorID: String
    var participantsIDs: Set<String>
    var words: [Word]
    var isStarted: Bool = false
    var hasGeneratedWords: Bool = false
    var difficultyLevel: Int = 2 // 1: Easy, 2: Medium, 3: Hard
    var wordCount: Int = 10 // Number of words in the game
    let creationDate: Date
    
    static func == (lhs: MultiUserGame, rhs: MultiUserGame) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var difficultyText: String {
        switch difficultyLevel {
        case 1: return "Easy"
        case 2: return "Medium"
        case 3: return "Hard"
        default: return "Medium"
        }
    }
}
