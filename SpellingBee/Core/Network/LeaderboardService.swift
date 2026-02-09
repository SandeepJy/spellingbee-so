import Foundation
import FirebaseAuth

// MARK: - Response Models

struct MyRankResponse: Codable, Sendable {
    let rank: Int
    let totalPlayers: Int
    let accuracy: Double
    let username: String
    let totalWordsSpelled: Int
}

struct TopSpellerEntry: Codable, Identifiable, Sendable {
    var id: String { "\(rank)-\(username)" }
    let rank: Int
    let username: String
    let accuracy: Double
    let level: Int
    let totalWordsSpelled: Int
    let isCurrentUser: Bool
}

struct TopSpellersResponse: Codable, Sendable {
    let players: [TopSpellerEntry]
}

// MARK: - Service

actor LeaderboardService {
    static let shared = LeaderboardService()
    private let baseURL = "https://us-central1-spellingbee-20c3f.cloudfunctions.net"
    private init() {}

    func fetchMyRank(userToken: String) async throws -> MyRankResponse {
        guard let url = URL(string: "\(baseURL)/getMyRank") else {
            throw LeaderboardError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response)
        return try JSONDecoder().decode(MyRankResponse.self, from: data)
    }

    func fetchTopSpellers(userToken: String, limit: Int = 10) async throws -> [TopSpellerEntry] {
        guard var components = URLComponents(string: "\(baseURL)/getTopSpellers") else {
            throw LeaderboardError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        guard let url = components.url else { throw LeaderboardError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response)
        let decoded = try JSONDecoder().decode(TopSpellersResponse.self, from: data)
        return decoded.players
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LeaderboardError.invalidResponse
        }
        switch http.statusCode {
        case 200: return
        case 401, 403: throw LeaderboardError.unauthorized
        default: throw LeaderboardError.serverError(http.statusCode)
        }
    }
}

enum LeaderboardError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .unauthorized: return "Authentication required"
        case .serverError(let code): return "Server error (\(code))"
        }
    }
}
