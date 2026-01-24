import Foundation

struct MisspelledWord: Codable, Hashable, Sendable {
    let correctWord: String
    let userAnswer: String
    let wordIndex: Int
    
    static func == (lhs: MisspelledWord, rhs: MisspelledWord) -> Bool {
        lhs.correctWord == rhs.correctWord && lhs.wordIndex == rhs.wordIndex
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(correctWord)
        hasher.combine(wordIndex)
    }
}
