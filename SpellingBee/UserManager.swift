
import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

class UserManager: ObservableObject {
    // Published property that will trigger view updates when changed
    @Published var currentUser: SpellGameUser?
    @Published var isAuthenticated = false
    
    private var db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        // Set up auth state listener to handle authentication state changes
        setupAuthStateListener()
    }
    
    deinit {
        // Remove the auth state listener when the object is deallocated
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    /**
     * Sets up authentication state listener to automatically handle login/logout
     */
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                // User is signed in, fetch their details from Firestore
                self?.fetchUserFromFirestore(uid: user.uid) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let spellGameUser):
                            self?.currentUser = spellGameUser
                            self?.isAuthenticated = true
                        case .failure(let error):
                            print("Error fetching user from Firestore: \(error)")
                            // If user doesn't exist in Firestore, create them with basic info
                            let fallbackUser = SpellGameUser(
                                id: user.uid,
                                username: user.displayName ?? "User",
                                email: user.email ?? ""
                            )
                            self?.currentUser = fallbackUser
                            self?.isAuthenticated = true
                            // Save the fallback user to Firestore
                            self?.saveUserToFirestore(user: fallbackUser)
                        }
                    }
                }
            } else {
                // User is signed out
                DispatchQueue.main.async {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    /**
     * Fetches user details from Firestore
     *
     * @param uid The user's Firebase Auth UID
     * @param completion Callback with result containing SpellGameUser on success or Error on failure
     */
    private func fetchUserFromFirestore(uid: String, completion: @escaping (Result<SpellGameUser, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found in Firestore"])))
                return
            }
            
            do {
                let user = try document.data(as: SpellGameUser.self)
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /**
     * Saves user to Firestore
     *
     * @param user The SpellGameUser to save
     */
    private func saveUserToFirestore(user: SpellGameUser) {
        do {
            try db.collection("users").document(user.id).setData(from: user)
        } catch {
            print("Error saving user to Firestore: \(error)")
        }
    }
    
    /**
     * Registers a new user with the given credentials
     *
     * @param username The display name for the user
     * @param email The email address for authentication
     * @param password The user's password
     * @param completion Callback with result containing User on success or Error on failure
     */
    func register(username: String, email: String, password: String, completion: @escaping (Result<SpellGameUser, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = authResult?.user else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create user"])))
                return
            }
            
            // Create SpellGameUser with the provided username (or empty if not provided)
            let newUser = SpellGameUser(id: user.uid, username: username.trimmingCharacters(in: .whitespacesAndNewlines), email: email)
            
            // Save user to Firestore
            self?.saveUserToFirestore(user: newUser)
            
            // Update the display name in Firebase Auth for consistency
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = username
            changeRequest.commitChanges { error in
                if let error = error {
                    print("Error updating display name: \(error)")
                }
            }
            
            // The auth state listener will automatically update currentUser
            completion(.success(newUser))
        }
    }
    
    /**
     * Authenticates a user with provided credentials
     *
     * @param email The email address for authentication
     * @param password The user's password
     * @param completion Callback with result containing User on success or Error on failure
     */
    func login(email: String, password: String, completion: @escaping (Result<SpellGameUser, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = authResult?.user else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to sign in user"])))
                return
            }
            
            // Fetch the complete user details from Firestore
            self?.fetchUserFromFirestore(uid: user.uid) { result in
                switch result {
                case .success(let spellGameUser):
                    completion(.success(spellGameUser))
                case .failure(_):
                    // If user doesn't exist in Firestore, create them with available info
                    let fallbackUser = SpellGameUser(
                        id: user.uid,
                        username: user.displayName ?? "User",
                        email: email
                    )
                    self?.saveUserToFirestore(user: fallbackUser)
                    completion(.success(fallbackUser))
                }
            }
            
            // Note: The auth state listener will automatically update currentUser
        }
    }
    
    /**
     * Signs out the current user
     */
    func signOut() {
        do {
            try Auth.auth().signOut()
            // The auth state listener will automatically update currentUser and isAuthenticated
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    /**
     * Updates the current user's details
     *
     * @param username New username
     * @param completion Callback with result
     */
    func updateUserProfile(username: String, completion: @escaping (Result<SpellGameUser, Error>) -> Void) {
        guard let currentUser = currentUser else {
            completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])))
            return
        }
        
        let updatedUser = SpellGameUser(id: currentUser.id, username: username, email: currentUser.email)
        
        // Update in Firestore
        saveUserToFirestore(user: updatedUser)
        
        // Update Firebase Auth display name
        if let user = Auth.auth().currentUser {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = username
            changeRequest.commitChanges { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                DispatchQueue.main.async {
                    self.currentUser = updatedUser
                    completion(.success(updatedUser))
                }
            }
        }
    }
}
