import SwiftUI

struct GameHeaderView: View {
    let game: MultiUserGame
    let score: Int
    let correctCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spell the Words")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                Text("\(game.difficultyText) - \(game.wordCount) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Score: \(score)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("\(correctCount) correct")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
    }
}
