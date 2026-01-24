
import Foundation

struct SpellGameUser: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let username: String
    let email: String
    
    static func == (lhs: SpellGameUser, rhs: SpellGameUser) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
