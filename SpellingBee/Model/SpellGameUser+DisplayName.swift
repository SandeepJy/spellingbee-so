import Foundation

extension SpellGameUser {
    // Returns username if available, otherwise returns email (optionally truncated)
    var displayName: String {
        if !username.isEmpty {
            return username
        }
        // Remove everything after @ in email for a cleaner display
        return email.components(separatedBy: "@")[0]
    }
    
    // Returns the full display name (including email domain if using email)
    var fullDisplayName: String {
        if !username.isEmpty {
            return username
        }
        return email
    }
    
    // Returns first letter/character for avatar displays
    var initialLetter: String {
        if !username.isEmpty {
            return String(username.prefix(1)).uppercased()
        }
        return String(email.prefix(1)).uppercased()
    }
}
