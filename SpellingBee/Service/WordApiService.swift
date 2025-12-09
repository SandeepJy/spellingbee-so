import Foundation

enum WordAPIError: Error, Sendable {
    case invalidURL
    case noData
    case decodingError
    case noAudioAvailable
    case networkError(String)
    case insufficientWords
    
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
        }
    }
}

struct WordWithDetails: Sendable {
    let word: String
    let audioURL: String?
    let definition: String?
}

actor WordAPIService {
    static let shared = WordAPIService()
    
    private init() {}
    
    /// Fetches random words from the API
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
    
    /// Fetches random words with their details and audio URLs
    func fetchRandomWordsWithDetails(count: Int = 10, length: Int = 5) async throws -> [WordWithDetails] {
        let requestCount = count * 3
        
        print("🌐 Requesting \(requestCount) words from API to get \(count) with audio...")
        
        let words = try await fetchRandomWords(count: requestCount, length: length)
        print("📥 Received \(words.count) words from random word API")
        
        var wordsWithDetails: [WordWithDetails] = []
        
        await withTaskGroup(of: WordWithDetails?.self) { group in
            for word in words {
                group.addTask {
                    do {
                        let details = try await self.fetchWordDetails(word: word)
                        let audioURL = details.phonetics.first(where: { $0.audio != nil && !$0.audio!.isEmpty })?.audio
                        let definition = details.meanings.first?.definitions.first?.definition
                        
                        if audioURL != nil {
                            return WordWithDetails(word: word, audioURL: audioURL, definition: definition)
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
                    if wordsWithDetails.count >= count {
                        group.cancelAll()
                        break
                    }
                }
            }
        }
        
        print("✅ Found \(wordsWithDetails.count) words with audio (needed \(count))")
        
        let finalWords = Array(wordsWithDetails.prefix(count))
        
        if finalWords.isEmpty {
            throw WordAPIError.noAudioAvailable
        }
        
        print("🎉 Successfully returning \(finalWords.count) words:")
        finalWords.forEach { print("   - \($0.word)") }
        
        return finalWords
    }
}
