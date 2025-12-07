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
            return "Could not find enough words with audio"
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
    /// Will keep fetching until we have the requested count of words with audio
    /// - Parameters:
    ///   - count: Number of words to fetch (with audio)
    ///   - length: Length of words
    ///   - completion: Completion handler with array of words with details
    func fetchRandomWordsWithDetails(count: Int = 10, length: Int = 5, completion: @escaping (Result<[(word: String, audioURL: String?, definition: String?)], WordAPIError>) -> Void) {
        
        var wordsWithAudio: [(word: String, audioURL: String?, definition: String?)] = []
        var attemptCount = 0
        let maxAttempts = 5
        
        func fetchBatch() {
            attemptCount += 1
            let remainingCount = count - wordsWithAudio.count
            // Fetch more words than needed since some won't have audio
            let fetchCount = min(remainingCount * 3, 30)
            
            print("📚 Fetching batch \(attemptCount): need \(remainingCount) more words, fetching \(fetchCount)")
            
            fetchRandomWords(count: fetchCount, length: length) { [weak self] result in
                switch result {
                case .success(let words):
                    let group = DispatchGroup()
                    var batchResults: [(word: String, audioURL: String?, definition: String?)] = []
                    let lock = NSLock()
                    
                    for word in words {
                        // Skip if we already have this word
                        if wordsWithAudio.contains(where: { $0.word.lowercased() == word.lowercased() }) {
                            continue
                        }
                        
                        group.enter()
                        self?.fetchWordDetails(word: word) { detailResult in
                            defer { group.leave() }
                            
                            switch detailResult {
                            case .success(let details):
                                // Find the first phonetic with a valid audio URL
                                let audioURL = details.phonetics.first(where: {
                                    $0.audio != nil && !$0.audio!.isEmpty
                                })?.audio
                                
                                // Only add if we have audio
                                if let audioURL = audioURL, !audioURL.isEmpty {
                                    let definition = details.meanings.first?.definitions.first?.definition
                                    
                                    lock.lock()
                                    batchResults.append((word: word, audioURL: audioURL, definition: definition))
                                    lock.unlock()
                                    
                                    print("✅ Found word with audio: \(word)")
                                } else {
                                    print("⚠️ No audio for word: \(word)")
                                }
                                
                            case .failure(let error):
                                print("❌ Failed to fetch details for '\(word)': \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    group.notify(queue: .main) {
                        // Add batch results to our collection
                        wordsWithAudio.append(contentsOf: batchResults)
                        
                        print("📊 Progress: \(wordsWithAudio.count)/\(count) words with audio")
                        
                        // Check if we have enough words
                        if wordsWithAudio.count >= count {
                            // Return exactly the requested count
                            let finalWords = Array(wordsWithAudio.prefix(count))
                            print("🎉 Successfully found \(finalWords.count) words with audio")
                            completion(.success(finalWords))
                        } else if attemptCount < maxAttempts {
                            // Try another batch
                            print("🔄 Need more words, fetching another batch...")
                            fetchBatch()
                        } else {
                            // Max attempts reached
                            if wordsWithAudio.isEmpty {
                                completion(.failure(.noAudioAvailable))
                            } else {
                                // Return what we have
                                print("⚠️ Max attempts reached, returning \(wordsWithAudio.count) words")
                                completion(.success(wordsWithAudio))
                            }
                        }
                    }
                    
                case .failure(let error):
                    if attemptCount < maxAttempts {
                        // Retry on failure
                        print("❌ Fetch failed, retrying...")
                        fetchBatch()
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
        
        // Start fetching
        fetchBatch()
    }
}
