import SwiftUI

struct GameCardView: View {
    @EnvironmentObject var gameManager: GameManager
    let gameID: UUID
    
    private var game: MultiUserGame? {
        gameManager.games.first { $0.id == gameID }
    }
    
    private var bestPossibleScore: Int {
        return (game?.wordCount ?? 0) * 90
    }
    
    var body: some View {
        if let game = game {
            NavigationLink(destination: GamePlayView(game: game).environmentObject(gameManager)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.difficultyText)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(difficultyColor)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            
                            Text("Created by \(gameManager.getCreatorName(for: game) ?? "Unknown")")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            if gameManager.isGameFinished(game) {
                                if let winner = gameManager.getGameWinner(game) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trophy.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                        Text(winner.id == gameManager.currentUser?.id ? "You won!" : "\(winner.displayName) won")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                                }
                            } else {
                                Text("Active")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }
                            
                            Text(formattedDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: 30) {
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.blue)
                                Text("\(game.participantsIDs.count)")
                                    .fontWeight(.medium)
                            }
                            Text("Players")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "text.book.closed.fill")
                                    .foregroundColor(.orange)
                                Text("\(game.wordCount)")
                                    .fontWeight(.medium)
                            }
                            Text("Words")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(bestPossibleScore)")
                                    .fontWeight(.medium)
                            }
                            Text("Max Pts")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if game.hasGeneratedWords {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Player Scores")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Best: \(bestPossibleScore) pts")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            ForEach(Array(game.participantsIDs), id: \.self) { participantID in
                                if let participant = gameManager.getUser(by: participantID) {
                                    let progress = gameManager.getUserProgress(for: game.id, userID: participantID)
                                    let score = progress?.score ?? 0
                                    let correctCount = progress?.correctlySpelledWords.count ?? 0
                                    
                                    UserScoreProgressBar(
                                        currentScore: score,
                                        bestPossibleScore: bestPossibleScore,
                                        userName: participant.displayName,
                                        correctCount: correctCount,
                                        totalWords: game.wordCount
                                    )
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(.systemGray6))
                        .shadow(color: Color.gray.opacity(0.2), radius: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var difficultyColor: Color {
        guard let game = game else { return .orange }
        switch game.difficultyLevel {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .orange
        }
    }
    
    private var formattedDate: String {
        guard let game = game else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: game.creationDate, relativeTo: Date())
    }
}

