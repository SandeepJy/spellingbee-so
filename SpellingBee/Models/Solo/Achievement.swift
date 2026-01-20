import Foundation

struct Achievement: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let xpReward: Int
    
    static let allAchievements: [Achievement] = [
        Achievement(id: "first_word", name: "First Steps", description: "Spell your first word correctly", icon: "star.fill", xpReward: 10),
        Achievement(id: "streak_3", name: "Getting Started", description: "Maintain a 3-day streak", icon: "flame.fill", xpReward: 25),
        Achievement(id: "streak_7", name: "Week Warrior", description: "Maintain a 7-day streak", icon: "flame.fill", xpReward: 50),
        Achievement(id: "streak_30", name: "Month Master", description: "Maintain a 30-day streak", icon: "flame.fill", xpReward: 200),
        Achievement(id: "perfect_10", name: "Perfect Ten", description: "Get 10 words correct in a row", icon: "checkmark.seal.fill", xpReward: 30),
        Achievement(id: "speed_demon", name: "Speed Demon", description: "Spell 5 words under 5 seconds each", icon: "bolt.fill", xpReward: 40),
        Achievement(id: "level_5", name: "Rising Star", description: "Reach level 5", icon: "star.circle.fill", xpReward: 50),
        Achievement(id: "level_10", name: "Expert", description: "Reach level 10", icon: "crown.fill", xpReward: 100),
        Achievement(id: "accuracy_80", name: "Sharpshooter", description: "Achieve 80% accuracy over 50 words", icon: "target", xpReward: 60),
        Achievement(id: "accuracy_95", name: "Perfectionist", description: "Achieve 95% accuracy over 100 words", icon: "scope", xpReward: 150),
        Achievement(id: "century", name: "Century", description: "Spell 100 words correctly", icon: "100.square.fill", xpReward: 75),
        Achievement(id: "no_hints", name: "Self Made", description: "Complete a session without using hints", icon: "brain.head.profile", xpReward: 40),
    ]
}
