import Foundation

struct Word: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let word: String
    let soundURL: URL?
    let level: Int
    var createdByID: String
    var gameID: UUID?
    
    init(id: UUID = UUID(), word: String, soundURL: URL?, level: Int, createdByID: String, gameID: UUID? = nil) {
        self.id = id
        self.word = word
        self.soundURL = soundURL
        self.level = level
        self.createdByID = createdByID
        self.gameID = gameID
    }
    
    static func == (lhs: Word, rhs: Word) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
