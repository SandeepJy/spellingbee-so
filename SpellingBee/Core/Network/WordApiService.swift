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

/// Response structure for the Firebase hard words API
struct HardWordsResponse: Codable, Sendable {
    let words: [String]
}

actor WordAPIService {
    static let shared = WordAPIService()
    
    private let hardWordsAPIEndpoint = "https://us-central1-spellingbee-20c3f.cloudfunctions.net/getWordsByLevel"
    
    private init() {}
    
    /// Fetches random words from the public API (for easy/medium difficulty)
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
    
    /// Fetches hard difficulty words from Firebase API (requires authentication)
    func fetchHardWords(count: Int, userToken: String) async throws -> [String] {
        let urlString = "\(hardWordsAPIEndpoint)?level=8&count=\(count)"
        
        guard let url = URL(string: urlString) else {
            throw WordAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔥 Fetching hard words from Firebase API...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordAPIError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ Firebase API returned status code: \(httpResponse.statusCode)")
            throw WordAPIError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        do {
            let hardWordsResponse = try JSONDecoder().decode(HardWordsResponse.self, from: data)
            print("✅ Received \(hardWordsResponse.words.count) hard words from Firebase")
            return hardWordsResponse.words
        } catch {
            print("Decoding error: \(error)")
            throw WordAPIError.decodingError
        }
    }
    
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
            print("Decoding error: \(error)")
            throw WordAPIError.decodingError
        }
    }
    
    /// Extracts the best audio URL from phonetics array
    private func extractAudioURL(from phonetics: [Phonetic]) -> String? {
        // Find first phonetic with a non-empty audio URL
        return phonetics.first(where: { $0.audio != nil && !$0.audio!.isEmpty })?.audio
    }
    
    /// Extracts the first definition from meanings
    private func extractDefinition(from meanings: [Meaning]) -> String? {
        // Get the first definition from the first meaning
        return meanings.first?.definitions.first?.definition
    }
    
    /// Extracts the first example sentence from meanings
    private func extractExampleSentence(from meanings: [Meaning]) -> String? {
        // Search through all meanings and definitions to find the first example
        for meaning in meanings {
            for definition in meaning.definitions {
                if let example = definition.example, !example.isEmpty {
                    return example
                }
            }
        }
        return nil
    }
    
    /// Parses DictionaryResponse into WordWithDetails
    private func parseWordDetails(from response: DictionaryResponse) async -> WordWithDetails {
        let audioURL = extractAudioURL(from: response.phonetics)
        let definition = extractDefinition(from: response.meanings)
        let exampleSentence = extractExampleSentence(from: response.meanings)
        
        return WordWithDetails(
            word: response.word,
            audioURL: audioURL,
            definition: definition,
            exampleSentence: exampleSentence
        )
    }
    
    /// Fetches random words with their details and audio URLs (for easy/medium difficulty)
    func fetchRandomWordsWithDetails(count: Int = 10, length: Int = 5) async throws -> [WordWithDetails] {
        let requestCount = count * 3
        
        print("🌐 Requesting \(requestCount) words from API to get \(count) with audio...")
        
        let words = try await fetchRandomWords(count: requestCount, length: length)
        print("📥 Received \(words.count) words from random word API")
        
        return try await fetchDetailsForWords(words: words, targetCount: count)
    }
    
    /// Fetches hard words with their details and audio URLs (for hard difficulty)
    func fetchHardWordsWithDetails(count: Int, userToken: String) async throws -> [WordWithDetails] {
        let requestCount = count
        
        print("🔥 Requesting \(requestCount) hard words from Firebase API to get \(count) with audio...")
        
        let words = try await fetchHardWords(count: requestCount, userToken: userToken)
        print("📥 Received \(words.count) hard words from Firebase API")
        
        return try await fetchDetailsForWords(words: words, targetCount: count)
    }
    
    /// Helper function to fetch details for a list of words
    private func fetchDetailsForWords(words: [String], targetCount: Int) async throws -> [WordWithDetails] {
        var wordsWithDetails: [WordWithDetails] = []
        
        await withTaskGroup(of: WordWithDetails?.self) { group in
            for word in words {
                group.addTask {
                    do {
                        let details = try await self.fetchWordDetails(word: word)
                        let wordWithDetails =  await self.parseWordDetails(from: details)
                        
                        // Only include words that have audio
                        if wordWithDetails.audioURL != nil {
                            return wordWithDetails
                        }
                        return nil
                    } catch {
                        print("⚠️ Failed to fetch details for '\(word)': \(error.localizedDescription)")
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
        
        print("✅ Found \(wordsWithDetails.count) words with audio (needed \(targetCount))")
        
        let finalWords = Array(wordsWithDetails.prefix(targetCount))
        
        if finalWords.isEmpty {
            throw WordAPIError.noAudioAvailable
        }
        
        print("🎉 Successfully returning \(finalWords.count) words:")
        finalWords.forEach { print("   - \($0.word): \($0.definition?.prefix(50) ?? "No definition")...") }
        
        return finalWords
    }
    
    /// Fetches details for a single word (used for review screen)
    func fetchSingleWordDetails(word: String) async -> WordWithDetails? {
        do {
            let details = try await fetchWordDetails(word: word)
            return await parseWordDetails(from: details)
        } catch {
            print("⚠️ Failed to fetch details for '\(word)': \(error.localizedDescription)")
            return nil
        }
    }
}

// Add to WordAPIService
extension WordAPIService {
    /// Fetch words for solo mode based on level
    func fetchWordsForSoloMode(level: Int, count: Int = 10, userToken: String? = nil) async throws -> [WordWithDetails] {
        if level <= 10 {
            // Levels 1-10: Use word length for difficulty
            let wordLength = calculateWordLengthForLevel(level)
            return try await fetchRandomWordsWithDetails(count: count, length: wordLength)
        } else {
            // Levels 11+: Use Firebase curated hard words
            guard let token = userToken else {
                throw WordAPIError.authenticationRequired
            }
            
            // Map level to Firebase difficulty (11+ maps to increasingly harder words)
            let firebaseLevel = min(level - 8, 10) // Level 11 = 3, Level 12 = 4, etc.
            return try await fetchHardWordsWithDetails(count: count, userToken: token, level: firebaseLevel)
        }
    }
    
    private func calculateWordLengthForLevel(_ level: Int) -> Int {
        switch level {
        case 1...2: return 3
        case 3...4: return 4
        case 5...6: return 5
        case 7...8: return 6
        case 9...10: return 7
        default: return 8
        }
    }
    
    /// Modified to support custom difficulty level for Firebase
    func fetchHardWordsWithDetails(count: Int, userToken: String, level: Int = 8) async throws -> [WordWithDetails] {
        let urlString = "\(hardWordsAPIEndpoint)?level=\(level)&count=\(count)"
        
        guard let url = URL(string: urlString) else {
            throw WordAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔥 Fetching hard words from Firebase API with level: \(level)...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordAPIError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ Firebase API returned status code: \(httpResponse.statusCode)")
            throw WordAPIError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        do {
            let hardWordsResponse = try JSONDecoder().decode(HardWordsResponse.self, from: data)
            print("✅ Received \(hardWordsResponse.words.count) hard words from Firebase")
            
            let words = hardWordsResponse.words
            return try await fetchDetailsForWords(words: words, targetCount: count)
        } catch {
            print("Decoding error: \(error)")
            throw WordAPIError.decodingError
        }
    }
}
