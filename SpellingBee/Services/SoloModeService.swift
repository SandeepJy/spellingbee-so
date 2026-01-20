import Foundation
import Firebase
import FirebaseFirestore

/// Service responsible for solo mode Firebase operations
struct SoloModeService: Sendable {
    
    // MARK: - Solo Progress Operations
    
    func saveSoloProgress(_ progress: SoloProgress) throws {
        try Firestore.firestore().collection("soloProgress").document(progress.id).setData(from: progress)
    }
    
    func loadSoloProgress(for userID: String) async throws -> SoloProgress {
        let document = try await Firestore.firestore().collection("soloProgress").document(userID).getDocument()
        
        if document.exists {
            return try document.data(as: SoloProgress.self)
        } else {
            let newProgress = SoloProgress(userID: userID)
            try saveSoloProgress(newProgress)
            return newProgress
        }
    }
    
    // MARK: - Solo Session Operations
    
    func saveSession(_ session: SoloSession) throws {
        try Firestore.firestore().collection("soloSessions").document(session.id.uuidString).setData(from: session)
    }
    
    func loadSessions(for userID: String) async throws -> [SoloSession] {
        let querySnapshot = try await Firestore.firestore().collection("soloSessions")
            .whereField("userID", isEqualTo: userID)
            .order(by: "startDate", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return querySnapshot.documents.compactMap { document in
            try? document.data(as: SoloSession.self)
        }
    }
    
    // MARK: - Real-time Listener
    
    func soloProgressListener(
        userID: String,
        onUpdate: @escaping @Sendable (SoloProgress?) -> Void
    ) -> ListenerRegistration {
        return Firestore.firestore().collection("soloProgress").document(userID)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching solo progress: \(error?.localizedDescription ?? "Unknown")")
                    onUpdate(nil)
                    return
                }
                
                let progress = try? document.data(as: SoloProgress.self)
                onUpdate(progress)
            }
    }
}
