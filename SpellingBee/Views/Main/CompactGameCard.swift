import SwiftUI

/// A compact version of the game card designed for carousel display
struct CompactGameCard: View {
    @EnvironmentObject var gameManager: GameManager
    let game: MultiUserGame
    let onTap: () -> Void
    
    private var progress: UserGameProgress? {
        gameManager.getUserProgress(for: game.id)
    }
    
    private var completedCount: Int {
        progress?.completedWordIndices.count ?? 0
    }
    
    private var progressPercentage: Double {
        guard game.wordCount > 0 else { return 0 }
        return Double(completedCount) / Double(game.wordCount)
    }
    
    private var isFinished: Bool {
        gameManager.isGameFinished(game)
    }
    
    private var difficultyColor: Color {
        switch game.difficultyLevel {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .orange
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: difficulty + status
                HStack {
                    Text(game.difficultyText)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(difficultyColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    if isFinished {
                        if let winner = gameManager.getGameWinner(game) {
                            HStack(spacing: 2) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 10))
                                Text(winner.id == gameManager.currentUser?.id ? "Won!" : winner.displayName)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .foregroundColor(.yellow)
                        }
                    } else {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Active")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Creator
                Text("by \(gameManager.getCreatorName(for: game) ?? "Unknown")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Progress bar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progressPercentage)
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Text("\(completedCount)/\(game.wordCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 9))
                            Text("\(game.participantsIDs.count)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isFinished ? Color.yellow.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let gameManager = GameManager()
    
    return VStack {
        CompactGameCard(
            game: MultiUserGame(
                id: UUID(),
                creatorID: "user1",
                participantsIDs: ["user1", "user2"],
                words: [],
                isStarted: true,
                hasGeneratedWords: true,
                difficultyLevel: 2,
                wordCount: 10,
                creationDate: Date()
            ),
            onTap: {}
        )
        .environmentObject(gameManager)
        .frame(width: 280)
    }
    .padding()
}
