import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
final class LeaderboardManager: ObservableObject {
    @Published var myRank: MyRankResponse?
    @Published var topSpellers: [TopSpellerEntry] = []
    @Published var isLoadingRank = false
    @Published var isLoadingTop = false
    @Published var error: String?

    private let service = LeaderboardService.shared

    func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMyRank() }
            group.addTask { await self.loadTopSpellers() }
        }
    }

    func loadMyRank() async {
        isLoadingRank = true
        defer { isLoadingRank = false }
        do {
            let token = try await getToken()
            myRank = try await service.fetchMyRank(userToken: token)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadTopSpellers() async {
        isLoadingTop = true
        defer { isLoadingTop = false }
        do {
            let token = try await getToken()
            topSpellers = try await service.fetchTopSpellers(userToken: token)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func getToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw LeaderboardError.unauthorized
        }
        return try await user.getIDToken()
    }
}
