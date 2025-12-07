
import Foundation


struct SpellGameUser: Identifiable, Codable, Hashable {
    let id: String  // Unique identifier for each user
    let username: String
    let email: String
    
    // Equatable protocol implementation
    static func == (lhs: SpellGameUser, rhs: SpellGameUser) -> Bool {
        lhs.id == rhs.id
    }
    
    // Hashable protocol implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
