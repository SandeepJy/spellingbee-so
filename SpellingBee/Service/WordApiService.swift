import Foundation

enum WordAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case noAudioAvailable
    case networkError(Error)
    case insufficientWords
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .noAudioAvailable:
            return "No audio available for this word"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .insufficientWords:
            return "Could not fetch enough words with audio"
        }
    }
}

actor WordAPIService {
    static let shared = WordAPIService()
    
    private init() {}
    
    func fetchRandomWords(count: Int = 10, length: Int = 5) async throws -> [String] {
        let urlString = "https://random-word-api.vercel.app/api?words=\(count)&length=\(length)"
        
        guard let url = URL(string: urlString) else {
            throw WordAPIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw WordAPIError.decodingError
        }
    }
    
    func fetchWordDetails(word: String) async throws -> DictionaryResponse {
        let urlString = "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)"
        
        guard let url = URL(string: urlString) else {
            throw WordAPIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        do {
            let responses = try JSONDecoder().decode([DictionaryResponse].self, from: data)
            guard let firstResponse = responses.first else {
                throw WordAPIError.noData
            }
            return firstResponse
        } catch {
            print("Decoding error: \(error)")
            throw WordAPIError.decodingError
        }
    }
    
    func fetchRandomWordsWithDetails(count: Int = 10, length: Int = 5) async throws -> [(word: String, audioURL: String?, definition: String?)] {
        let requestCount = count * 3 // Request more to ensure enough with audio
        
        print("🌐 Requesting \(requestCount) words from API to get \(count) with audio...")
        
        let words = try await fetchRandomWords(count: requestCount, length: length)
        print("📥 Received \(words.count) words from random word API")
        
        var wordsWithDetails: [(word: String, audioURL: String?, definition: String?)] = []
        
        // Process words concurrently
        await withTaskGroup(of: (String, String?, String?)?.self) { group in
            for word in words {
                group.addTask {
                    do {
                        let details = try await self.fetchWordDetails(word: word)
                        
                        // Find the first phonetic with audio
                        let audioURL = details.phonetics.first(where: { $0.audio != nil && !$0.audio!.isEmpty })?.audio
                        
                        // Get the first definition
                        let definition = details.meanings.first?.definitions.first?.definition
                        
                        // Only return if we have audio
                        if audioURL != nil {
                            return (word, audioURL, definition)
                        }
                        return nil
                    } catch {
                        print("⚠️ Failed to fetch details for '\(word)': \(error.localizedDescription)")
                        return nil
                    }
                }
            }
            
            for await result in group {
                if let result = result {
                    wordsWithDetails.append(result)
                    if wordsWithDetails.count >= count {
                        break
                    }
                }
            }
        }
        
        print("✅ Found \(wordsWithDetails.count) words with audio (needed \(count))")
        
        let finalWords = Array(wordsWithDetails.prefix(count))
        
        if finalWords.count < count {
            print("⚠️ Warning: Only got \(finalWords.count) words with audio, needed \(count)")
            if finalWords.isEmpty {
                throw WordAPIError.noAudioAvailable
            }
        }
        
        print("🎉 Successfully returning \(finalWords.count) words:")
        finalWords.forEach { print("   - \($0.word)") }
        
        return finalWords
    }
}
