import Foundation

struct DictionaryResponse: Codable, Sendable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]
    let meanings: [Meaning]
    let license: License?
    let sourceUrls: [String]?
}

struct Phonetic: Codable, Sendable {
    let text: String?
    let audio: String?
    let sourceUrl: String?
    let license: License?
}

struct Meaning: Codable, Sendable {
    let partOfSpeech: String
    let definitions: [Definition]
    let synonyms: [String]?
    let antonyms: [String]?
}

struct Definition: Codable, Sendable {
    let definition: String
    let synonyms: [String]?
    let antonyms: [String]?
    let example: String?
}

struct License: Codable, Sendable {
    let name: String
    let url: String
}
