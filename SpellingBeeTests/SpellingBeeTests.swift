//
//  SpellingBeeTests.swift
//  SpellingBeeTests
//
//  Created by owner on 2025-11-08.
//

import Testing
@testable import SpellingBee
import Foundation

struct SpellGameUserDisplayNameTests {
    
    @Test("Uses username when available")
    func displayNamePrefersUsername() {
        let user = SpellGameUser(
            id: "user-1",
            username: "BeeMaster",
            email: "bee.master@example.com"
        )
        
        #expect(user.displayName == "BeeMaster")
        #expect(user.fullDisplayName == "BeeMaster")
        #expect(user.initialLetter == "B")
    }
    
    @Test("Falls back to email when username is empty")
    func displayNameFallsBackToEmail() {
        let user = SpellGameUser(
            id: "user-2",
            username: "",
            email: "honeycomb@example.com"
        )
        
        #expect(user.displayName == "honeycomb")
        #expect(user.fullDisplayName == "honeycomb@example.com")
        #expect(user.initialLetter == "H")
    }
}

struct UserGameProgressModelTests {
    
    @Test("generateID combines user and game IDs")
    func generateIDCombinesUserAndGame() {
        let gameID = UUID()
        let expected = "player-1-\(gameID.uuidString)"
        
        #expect(UserGameProgress.generateID(userID: "player-1", gameID: gameID) == expected)
    }
    
    @Test("Initializer sets ID using helper")
    func initializerAssignsGeneratedID() {
        let gameID = UUID()
        let progress = UserGameProgress(userID: "player-2", gameID: gameID, completedWordIndices: [0, 1], currentWordIndex: 2, score: 8)
        
        #expect(progress.id == UserGameProgress.generateID(userID: "player-2", gameID: gameID))
    }
    
    @Test("Equality is determined by the identifier")
    func equalityUsesIdentifierOnly() {
        let sharedGameID = UUID()
        
        var first = UserGameProgress(userID: "user-123", gameID: sharedGameID, completedWordIndices: [0], currentWordIndex: 1, score: 5)
        var second = UserGameProgress(userID: "user-123", gameID: sharedGameID, completedWordIndices: [0, 2], currentWordIndex: 3, score: 12)
        
        #expect(first == second)
        
        let different = UserGameProgress(userID: "user-456", gameID: sharedGameID)
        #expect(first != different)
    }
}

struct MultiUserGameModelTests {
    
    @Test("Two games with same ID are equal")
    func equalityByIdentifier() {
        let gameID = UUID()
        let first = MultiUserGame(id: gameID, creatorID: "creator", participantsIDs: ["a", "b"], words: [], creationDate: Date())
        let second = MultiUserGame(id: gameID, creatorID: "someone-else", participantsIDs: [], words: [], creationDate: Date())
        
        #expect(first == second)
    }
    
    @Test("Different IDs produce inequality")
    func inequalityWithDifferentIdentifiers() {
        let first = MultiUserGame(id: UUID(), creatorID: "creator", participantsIDs: [], words: [], creationDate: Date())
        let second = MultiUserGame(id: UUID(), creatorID: "creator", participantsIDs: [], words: [], creationDate: Date())
        
        #expect(first != second)
    }
}

struct GameManagerUtilityTests {
    
    @Test("Retrieves user by identifier")
    func getUserByIdentifier() {
        let manager = GameManager()
        let alice = SpellGameUser(id: "alice", username: "Alice", email: "alice@example.com")
        manager.users = [alice, SpellGameUser(id: "bob", username: "Bob", email: "bob@example.com")]
        
        #expect(manager.getUser(by: "alice") == alice)
        #expect(manager.getUser(by: "charlie") == nil)
    }
    
    @Test("Maps participant IDs to display names")
    func participantNamesUseDisplayNames() {
        let manager = GameManager()
        manager.users = [
            SpellGameUser(id: "alice", username: "Alice", email: "alice@example.com"),
            SpellGameUser(id: "bob", username: "", email: "bobby@example.com")
        ]
        
        let game = MultiUserGame(
            id: UUID(),
            creatorID: "alice",
            participantsIDs: ["alice", "bob", "missing"],
            words: [],
            creationDate: Date()
        )
        
        let names = manager.getParticipantNames(for: game)
        
        #expect(Set(names) == Set(["Alice", "bobby"]))
    }
    
    @Test("Provides the creator's display name when available")
    func creatorNameIfUserExists() {
        let manager = GameManager()
        manager.users = [
            SpellGameUser(id: "creator", username: "", email: "creator@example.com")
        ]
        
        let game = MultiUserGame(
            id: UUID(),
            creatorID: "creator",
            participantsIDs: [],
            words: [],
            creationDate: Date()
        )
        
        #expect(manager.getCreatorName(for: game) == "creator")
        
        let otherGame = MultiUserGame(
            id: UUID(),
            creatorID: "missing",
            participantsIDs: [],
            words: [],
            creationDate: Date()
        )
        
        #expect(manager.getCreatorName(for: otherGame) == nil)
    }
    
    @Test("Fetches user progress for specific game and user")
    func getUserProgressByIdentifiers() {
        let manager = GameManager()
        let gameID = UUID()
        
        let progress = UserGameProgress(
            userID: "player-1",
            gameID: gameID,
            completedWordIndices: [0, 2],
            currentWordIndex: 3,
            score: 12
        )
        
        manager.userGameProgresses = [progress]
        
        #expect(manager.getUserProgress(for: gameID, userID: "player-1") == progress)
        #expect(manager.getUserProgress(for: gameID, userID: "player-2") == nil)
    }
}
