import Foundation

extension SpellGameUser {
    var displayName: String {
        if !username.isEmpty {
            return username
        }
        return email.components(separatedBy: "@")[0]
    }
    
    var fullDisplayName: String {
        if !username.isEmpty {
            return username
        }
        return email
    }
    
    var initialLetter: String {
        if !username.isEmpty {
            return String(username.prefix(1)).uppercased()
        }
        return String(email.prefix(1)).uppercased()
    }
}
