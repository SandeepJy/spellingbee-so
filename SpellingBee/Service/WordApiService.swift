import Foundation

enum WordAPIError: Error {
    case invalidURL
    case noData
    case decodingError
    case noAudioAvailable
    case networkError(Error)
    
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
        fetchRandomWords(count: count, length: length) { [weak self] result in
            switch result {
            case .success(let words):
                let group = DispatchGroup()
                var wordsWithDetails: [(word: String, audioURL: String?, definition: String?)] = []
                var hasError = false
                
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
                            
                            wordsWithDetails.append((word: word, audioURL: audioURL, definition: definition))
                            
                        case .failure(let error):
                            print("Failed to fetch details for '\(word)': \(error.localizedDescription)")
                            // Still add the word but without audio/definition
                            wordsWithDetails.append((word: word, audioURL: nil, definition: nil))
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    // Filter out words without audio
                    let validWords = wordsWithDetails.filter { $0.audioURL != nil }
                    
                    if validWords.isEmpty {
                        completion(.failure(.noAudioAvailable))
                    } else {
                        completion(.success(validWords))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
