import Foundation

struct Word: Identifiable, Codable, Hashable {
    let id = UUID()
    let word: String
    let soundURL: URL?
    let level: Int
    var createdByID: String // "system" for API-generated words
    var gameID: UUID?
    
    static func == (lhs: Word, rhs: Word) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
