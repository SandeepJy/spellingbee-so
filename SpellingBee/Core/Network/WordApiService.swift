import Foundation

enum WordAPIError: Error, Sendable {
    case invalidURL
    case noData
    case decodingError
    case noAudioAvailable
    case networkError(String)
    case insufficientWords
    case authenticationRequired
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .noAudioAvailable:
            return "No audio available for this word"
        case .networkError(let message):
            return "Network error: \(message)"
        case .insufficientWords:
            return "Could not fetch enough words with audio"
        case .authenticationRequired:
            return "Authentication required for this operation"
        }
    }
}

struct WordWithDetails: Sendable {
    let word: String
    let audioURL: String?
    let definition: String?
    let exampleSentence: String?
}

/// Response structure for the Firebase words API
struct FirebaseWordsResponse: Codable, Sendable {
    let minLevel: Int
    let maxLevel: Int
    let count: Int
    let words: [FirebaseWordItem]
}

struct FirebaseWordItem: Codable, Sendable {
    let word: String
    let level: Int
    let audioUrl: String?
    let definition: String?
    let example: String?
}

actor WordAPIService {
    static let shared = WordAPIService()
    
    private let firebaseAPIEndpoint = "https://us-central1-spellingbee-20c3f.cloudfunctions.net/getWordsByLevel"
    
    private init() {}
    
    // MARK: - Random Word API (for levels 1-5)
    
    func fetchRandomWords(count: Int = 10, length: Int = 5) async throws -> [String] {
        let urlString = "https://random-word-api.vercel.app/api?words=\(count)&length=\(length)"
        
        guard let url = URL(string: urlString) else {
            throw WordAPIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        do {
            let words = try JSONDecoder().decode([String].self, from: data)
            return words
        } catch {
            print("Decoding error: \(error)")
            throw WordAPIError.decodingError
        }
    }
    
    /// Fetches random words across a range of lengths
    func fetchRandomWordsInLengthRange(count: Int, minLength: Int, maxLength: Int) async throws -> [String] {
        var allWords: [String] = []
        let wordsPerLength = max(count / (maxLength - minLength + 1), 3)
        
        for length in minLength...maxLength {
            let fetchCount = wordsPerLength + 5
            do {
                let words = try await fetchRandomWords(count: fetchCount, length: length)
                allWords.append(contentsOf: words)
            } catch {
                print("⚠️ Failed to fetch words of length \(length): \(error)")
            }
        }
        
        allWords.shuffle()
        return Array(allWords.prefix(count * 3))
    }
    
    // MARK: - Firebase API (for levels 6+)
    
    /// Fetches words from Firebase API with level range - returns WordWithDetails directly
    func fetchFirebaseWordsWithDetails(count: Int, minLevel: Int, maxLevel: Int, userToken: String) async throws -> [WordWithDetails] {
        let urlString = "\(firebaseAPIEndpoint)?minLevel=\(minLevel)&maxLevel=\(maxLevel)&count=\(count)"
        
        guard let url = URL(string: urlString) else {
            throw WordAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔥 Fetching words from Firebase API (levels \(minLevel)-\(maxLevel), count: \(count))...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordAPIError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No body"
            print("❌ Firebase API returned status code: \(httpResponse.statusCode), body: \(responseBody)")
            throw WordAPIError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        do {
            let firebaseResponse = try JSONDecoder().decode(FirebaseWordsResponse.self, from: data)
            print("✅ Received \(firebaseResponse.words.count) words from Firebase (levels \(minLevel)-\(maxLevel))")
            
            // Convert FirebaseWordItem to WordWithDetails - filter for those with audio
            let wordsWithDetails = firebaseResponse.words
                .filter { $0.audioUrl != nil && !($0.audioUrl?.isEmpty ?? true) }
                .map { item in
                    WordWithDetails(
                        word: item.word,
                        audioURL: item.audioUrl,
                        definition: item.definition,
                        exampleSentence: item.example
                    )
                }
            
            if wordsWithDetails.isEmpty {
                throw WordAPIError.noAudioAvailable
            }
            
            print("🎉 Returning \(wordsWithDetails.count) Firebase words with audio")
            return Array(wordsWithDetails.prefix(count))
        } catch let error as WordAPIError {
            throw error
        } catch {
            print("Decoding error: \(error)")
            throw WordAPIError.decodingError
        }
    }
    
    // MARK: - Dictionary API
    
    func fetchWordDetails(word: String) async throws -> DictionaryResponse {
        let urlString = "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)"
        
        guard let url = URL(string: urlString) else {
            throw WordAPIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        do {
            let responses = try JSONDecoder().decode([DictionaryResponse].self, from: data)
            if let firstResponse = responses.first {
                return firstResponse
            } else {
                throw WordAPIError.noData
            }
        } catch let error as WordAPIError {
            throw error
        } catch {
            throw WordAPIError.decodingError
        }
    }
    
    // MARK: - Solo Mode Fetcher
    
    /// Fetches words for solo mode based on level config
    func fetchWordsForSoloLevel(config: SoloLevelConfig, userToken: String?) async throws -> [WordWithDetails] {
        switch config.wordSource {
        case .randomAPI(let minLength, let maxLength):
            // For random API words, we need to fetch words then get details from Dictionary API
            let words = try await fetchRandomWordsInLengthRange(
                count: config.wordFetchCount,
                minLength: minLength,
                maxLength: maxLength
            )
            print("📥 Got \(words.count) raw words, fetching details from Dictionary API...")
            return try await fetchDetailsForWords(words: words, targetCount: config.wordFetchCount)
            
        case .firebaseAPI(let minLevel, let maxLevel):
            // Firebase API already returns audioUrl, definition, example
            guard let token = userToken else {
                throw WordAPIError.authenticationRequired
            }
            return try await fetchFirebaseWordsWithDetails(
                count: config.wordFetchCount,
                minLevel: minLevel,
                maxLevel: maxLevel,
                userToken: token
            )
        }
    }
    
    // MARK: - Multiplayer Game Fetcher (used by GameService)
    
    /// Fetches words for multiplayer games based on difficulty
    func fetchWordsForMultiplayer(difficulty: Int, count: Int, userToken: String?) async throws -> [WordWithDetails] {
        switch difficulty {
        case 1:
            // Easy: 3-4 letter words
            let length = Int.random(in: 3...4)
            return try await fetchRandomWordsWithDetails(count: count, length: length)
        case 2:
            // Medium: 5 letter words
            return try await fetchRandomWordsWithDetails(count: count, length: 5)
        case 3:
            // Hard: Firebase words level 5-9
            guard let token = userToken else {
                throw WordAPIError.authenticationRequired
            }
            return try await fetchFirebaseWordsWithDetails(
                count: count,
                minLevel: 5,
                maxLevel: 9,
                userToken: token
            )
        default:
            return try await fetchRandomWordsWithDetails(count: count, length: 5)
        }
    }
    
    /// Fetches random words with their details and audio URLs (via Dictionary API)
    func fetchRandomWordsWithDetails(count: Int = 10, length: Int = 5) async throws -> [WordWithDetails] {
        let requestCount = count * 3
        let words = try await fetchRandomWords(count: requestCount, length: length)
        return try await fetchDetailsForWords(words: words, targetCount: count)
    }
    
    /// Fetches details for a single word
    func fetchSingleWordDetails(word: String) async -> WordWithDetails? {
        do {
            let details = try await fetchWordDetails(word: word)
            return await parseWordDetails(from: details)
        } catch {
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private func fetchDetailsForWords(words: [String], targetCount: Int) async throws -> [WordWithDetails] {
        var wordsWithDetails: [WordWithDetails] = []
        
        await withTaskGroup(of: WordWithDetails?.self) { group in
            for word in words {
                group.addTask {
                    do {
                        let details = try await self.fetchWordDetails(word: word)
                        let wordWithDetails = await self.parseWordDetails(from: details)
                        
                        if wordWithDetails.audioURL != nil {
                            return wordWithDetails
                        }
                        return nil
                    } catch {
                        return nil
                    }
                }
            }
            
            for await result in group {
                if let wordWithDetails = result {
                    wordsWithDetails.append(wordWithDetails)
                    if wordsWithDetails.count >= targetCount {
                        group.cancelAll()
                        break
                    }
                }
            }
        }
        
        let finalWords = Array(wordsWithDetails.prefix(targetCount))
        
        if finalWords.isEmpty {
            throw WordAPIError.noAudioAvailable
        }
        
        print("🎉 Returning \(finalWords.count) words with audio")
        return finalWords
    }
    
    private func parseWordDetails(from response: DictionaryResponse) async -> WordWithDetails {
        let audioURL = response.phonetics.first(where: { $0.audio != nil && !$0.audio!.isEmpty })?.audio
        let definition = response.meanings.first?.definitions.first?.definition
        var exampleSentence: String?
        for meaning in response.meanings {
            for def in meaning.definitions {
                if let example = def.example, !example.isEmpty {
                    exampleSentence = example
                    break
                }
            }
            if exampleSentence != nil { break }
        }
        
        return WordWithDetails(
            word: response.word,
            audioURL: audioURL,
            definition: definition,
            exampleSentence: exampleSentence
        )
    }
}
