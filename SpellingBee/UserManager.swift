import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class UserManager: ObservableObject {
    @Published var currentUser: SpellGameUser?
    @Published var isAuthenticated = false
    
    private let db = Firestore.firestore()
    nonisolated(unsafe) private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                if let user = user {
                    do {
                        let spellGameUser = try await self?.fetchUserFromFirestore(uid: user.uid)
                        self?.currentUser = spellGameUser
                        self?.isAuthenticated = true
                    } catch {
                        print("Error fetching user from Firestore: \(error)")
                        // Create fallback user
                        let fallbackUser = SpellGameUser(
                            id: user.uid,
                            username: user.displayName ?? "User",
                            email: user.email ?? ""
                        )
                        self?.currentUser = fallbackUser
                        self?.isAuthenticated = true
                        await self?.saveUserToFirestore(user: fallbackUser)
                    }
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    private func fetchUserFromFirestore(uid: String) async throws -> SpellGameUser {
        let document = try await db.collection("users").document(uid).getDocument()
        
        guard document.exists else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found in Firestore"])
        }
        
        return try document.data(as: SpellGameUser.self)
    }
    
    private func saveUserToFirestore(user: SpellGameUser) async {
        do {
            try db.collection("users").document(user.id).setData(from: user)
        } catch {
            print("Error saving user to Firestore: \(error)")
        }
    }
    
    func register(username: String, email: String, password: String) async throws -> SpellGameUser {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        let user = authResult.user
        
        // Create SpellGameUser
        let newUser = SpellGameUser(
            id: user.uid,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email
        )
        
        // Save user to Firestore
        await saveUserToFirestore(user: newUser)
        
        // Update display name
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = username
        try await changeRequest.commitChanges()
        
        return newUser
    }
    
    func login(email: String, password: String) async throws -> SpellGameUser {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        let user = authResult.user
        
        do {
            return try await fetchUserFromFirestore(uid: user.uid)
        } catch {
            // Create fallback user if not in Firestore
            let fallbackUser = SpellGameUser(
                id: user.uid,
                username: user.displayName ?? "User",
                email: email
            )
            await saveUserToFirestore(user: fallbackUser)
            return fallbackUser
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    func updateUserProfile(username: String) async throws -> SpellGameUser {
        guard let currentUser = currentUser else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let updatedUser = SpellGameUser(id: currentUser.id, username: username, email: currentUser.email)
        
        // Update in Firestore
        await saveUserToFirestore(user: updatedUser)
        
        // Update Firebase Auth display name
        if let user = Auth.auth().currentUser {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = username
            try await changeRequest.commitChanges()
        }
        
        self.currentUser = updatedUser
        return updatedUser
    }
}
