import Foundation

enum HintType: String, Codable, CaseIterable, Sendable {
    case wordLength = "Word Length"
    case firstLetter = "First Letter"
    case definition = "Definition"
    case example = "Example Sentence"
    
    var cost: Int {
        switch self {
        case .wordLength: return 0
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
    
    var displayName: String {
        rawValue
    }
}
