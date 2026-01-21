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
    
    /// Fetches random words from the public API with a specific length
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
            let fetchCount = wordsPerLength + 5 // fetch extra to account for filtering
            do {
                let words = try await fetchRandomWords(count: fetchCount, length: length)
                allWords.append(contentsOf: words)
            } catch {
                print("⚠️ Failed to fetch words of length \(length): \(error)")
            }
        }
        
        // Shuffle and return requested count
        allWords.shuffle()
        return Array(allWords.prefix(count * 3)) // Return extra for audio filtering
    }
    
    // MARK: - Firebase API (for levels 6+)
    
    /// Fetches words from Firebase API with level range
    func fetchFirebaseWords(count: Int, minLevel: Int, maxLevel: Int, userToken: String) async throws -> [FirebaseWordItem] {
        let urlString = "\(firebaseAPIEndpoint)?minLevel=\(minLevel)&maxLevel=\(maxLevel)&count=\(count)"
        
        guard let url = URL(string: urlString) else {
            throw WordAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔥 Fetching words from Firebase API (levels \(minLevel)-\(maxLevel))...")
        
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
            return firebaseResponse.words
        } catch {
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString.prefix(500))")
            }
            throw WordAPIError.decodingError
        }
    }
    
    // MARK: - Dictionary API
    
    /// Fetches word details from Dictionary API
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
    
    // MARK: - Combined Fetchers
    
    /// Fetches words for solo mode based on level config
    func fetchWordsForSoloLevel(config: SoloLevelConfig, userToken: String?) async throws -> [WordWithDetails] {
        switch config.wordSource {
        case .randomAPI(let minLength, let maxLength):
            // For random API, fetch words and get details from dictionary
            let words = try await fetchRandomWordsInLengthRange(
                count: config.wordFetchCount,
                minLength: minLength,
                maxLength: maxLength
            )
            
            print("📥 Got \(words.count) random words, fetching details...")
            return try await fetchDetailsForWords(words: words, targetCount: config.wordFetchCount)
            
        case .firebaseAPI(let minLevel, let maxLevel):
            // For Firebase API, words already come with details
            guard let token = userToken else {
                throw WordAPIError.authenticationRequired
            }
            
            let firebaseWords = try await fetchFirebaseWords(
                count: config.wordFetchCount,
                minLevel: minLevel,
                maxLevel: maxLevel,
                userToken: token
            )
            
            print("📥 Got \(firebaseWords.count) Firebase words with details")
            
            // Convert Firebase words to WordWithDetails
            let wordsWithDetails = firebaseWords.map { item in
                WordWithDetails(
                    word: item.word,
                    audioURL: item.audioUrl,
                    definition: item.definition,
                    exampleSentence: item.example
                )
            }
            
            // Filter out words without audio
            let withAudio = wordsWithDetails.filter { $0.audioURL != nil && !$0.audioURL!.isEmpty }
            
            print("🎉 Returning \(withAudio.count) Firebase words with audio")
            
            if withAudio.count < config.requiredStreak + 5 {
                print("⚠️ Warning: Only \(withAudio.count) words with audio, may need more than required streak")
            }
            
            return Array(withAudio.prefix(config.wordFetchCount))
        }
    }
    
    /// Fetches random words with their details and audio URLs (for multiplayer games)
    func fetchRandomWordsWithDetails(count: Int = 10, length: Int = 5) async throws -> [WordWithDetails] {
        let requestCount = count * 3
        let words = try await fetchRandomWords(count: requestCount, length: length)
        return try await fetchDetailsForWords(words: words, targetCount: count)
    }
    
    /// Fetches hard words for multiplayer games using Firebase API
    func fetchHardWordsWithDetails(count: Int, userToken: String, level: Int = 8) async throws -> [WordWithDetails] {
        let firebaseWords = try await fetchFirebaseWords(
            count: count * 2, // fetch extra to ensure we have enough with audio
            minLevel: level,
            maxLevel: level,
            userToken: userToken
        )
        
        let wordsWithDetails = firebaseWords.map { item in
            WordWithDetails(
                word: item.word,
                audioURL: item.audioUrl,
                definition: item.definition,
                exampleSentence: item.example
            )
        }
        
        // Filter for audio
        let withAudio = wordsWithDetails.filter { $0.audioURL != nil && !$0.audioURL!.isEmpty }
        
        if withAudio.count < count {
            throw WordAPIError.insufficientWords
        }
        
        return Array(withAudio.prefix(count))
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
