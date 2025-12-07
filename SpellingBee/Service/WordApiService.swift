import Foundation

enum WordAPIError: Error {
    case invalidURL
    case noData
    case decodingError
    case noAudioAvailable
    case networkError(Error)
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
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .insufficientWords:
            return "Could not fetch enough words with audio"
        }
    }
}

class WordAPIService {
    static let shared = WordAPIService()
    
    private init() {}
    
    /// Fetches random words from the API
    /// - Parameters:
    ///   - count: Number of words to fetch
    ///   - length: Length of words (default 5)
    ///   - completion: Completion handler with result
    func fetchRandomWords(count: Int = 10, length: Int = 5, completion: @escaping (Result<[String], WordAPIError>) -> Void) {
        let urlString = "https://random-word-api.vercel.app/api?words=\(count)&length=\(length)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let words = try JSONDecoder().decode([String].self, from: data)
                completion(.success(words))
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }.resume()
    }
    
    /// Fetches word details from Dictionary API
    /// - Parameters:
    ///   - word: The word to look up
    ///   - completion: Completion handler with result
    func fetchWordDetails(word: String, completion: @escaping (Result<DictionaryResponse, WordAPIError>) -> Void) {
        let urlString = "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let responses = try JSONDecoder().decode([DictionaryResponse].self, from: data)
                if let firstResponse = responses.first {
                    completion(.success(firstResponse))
                } else {
                    completion(.failure(.noData))
                }
            } catch {
                print("Decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }.resume()
    }
    
    /// Fetches random words with their details and audio URLs
    /// - Parameters:
    ///   - count: Number of words to fetch
    ///   - length: Length of words
    ///   - completion: Completion handler with array of words with details
    func fetchRandomWordsWithDetails(count: Int = 10, length: Int = 5, completion: @escaping (Result<[(word: String, audioURL: String?, definition: String?)], WordAPIError>) -> Void) {
        
        // Request more words than needed to account for filtering
        let requestCount = count * 3 // Request 3x to ensure we get enough with audio
        
        print("🌐 Requesting \(requestCount) words from API to get \(count) with audio...")
        
        fetchRandomWords(count: requestCount, length: length) { [weak self] result in
            switch result {
            case .success(let words):
                print("📥 Received \(words.count) words from random word API")
                
                let group = DispatchGroup()
                var wordsWithDetails: [(word: String, audioURL: String?, definition: String?)] = []
                let lock = NSLock() // Thread-safe access to wordsWithDetails
                
                for word in words {
                    group.enter()
                    self?.fetchWordDetails(word: word) { detailResult in
                        defer { group.leave() }
                        
                        switch detailResult {
                        case .success(let details):
                            // Find the first phonetic with audio
                            let audioURL = details.phonetics.first(where: { $0.audio != nil && !$0.audio!.isEmpty })?.audio
                            
                            // Get the first definition
                            let definition = details.meanings.first?.definitions.first?.definition
                            
                            // Only add if we have audio
                            if audioURL != nil {
                                lock.lock()
                                wordsWithDetails.append((word: word, audioURL: audioURL, definition: definition))
                                lock.unlock()
                            }
                            
                        case .failure(let error):
                            print("⚠️ Failed to fetch details for '\(word)': \(error.localizedDescription)")
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    print("✅ Found \(wordsWithDetails.count) words with audio (needed \(count))")
                    
                    // Take only the requested count
                    let finalWords = Array(wordsWithDetails.prefix(count))
                    
                    if finalWords.count < count {
                        print("⚠️ Warning: Only got \(finalWords.count) words with audio, needed \(count)")
                        // Still return what we have rather than failing completely
                        if finalWords.isEmpty {
                            completion(.failure(.noAudioAvailable))
                        } else {
                            completion(.success(finalWords))
                        }
                    } else {
                        print("🎉 Successfully returning \(finalWords.count) words:")
                        finalWords.forEach { print("   - \($0.word)") }
                        completion(.success(finalWords))
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to fetch random words: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}
