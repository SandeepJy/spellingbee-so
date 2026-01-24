import Foundation
import Firebase
import FirebaseFirestore

/// Service responsible for user-related Firebase operations
struct UserService: Sendable {
    
    func saveUser(_ user: SpellGameUser) throws {
        try Firestore.firestore().collection("users").document(user.id).setData(from: user)
    }
    
    func loadUsers() async throws -> [SpellGameUser] {
        let querySnapshot = try await Firestore.firestore().collection("users").getDocuments()
        return querySnapshot.documents.compactMap { document in
            try? document.data(as: SpellGameUser.self)
        }
    }
    
    func fetchUser(uid: String) async throws -> SpellGameUser {
        let document = try await Firestore.firestore().collection("users").document(uid).getDocument()
        
        guard document.exists else {
            throw UserServiceError.userNotFound
        }
        
        return try document.data(as: SpellGameUser.self)
    }
    
    func usersListener(
        onUpdate: @escaping @Sendable ([SpellGameUser]) -> Void
    ) -> ListenerRegistration {
        return Firestore.firestore().collection("users").addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching users: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            let users = documents.compactMap { document in
                try? document.data(as: SpellGameUser.self)
            }
            onUpdate(users)
        }
    }
}

enum UserServiceError: Error, Sendable {
    case userNotFound
    case saveFailed
}
