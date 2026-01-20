import SwiftUI

struct UserScoreProgressBar: View {
    let currentScore: Int
    let bestPossibleScore: Int
    let userName: String
    let correctCount: Int
    let totalWords: Int
    
    private var progress: Double {
        guard bestPossibleScore > 0 else { return 0 }
        return min(Double(currentScore) / Double(bestPossibleScore), 1.0)
    }
    
    private var progressColor: Color {
        if progress >= 0.8 {
            return .green
        } else if progress >= 0.5 {
            return .blue
        } else if progress >= 0.3 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                Text(userName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Text("\(currentScore) pts")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor)
                
                Text("(\(correctCount)/\(totalWords))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [progressColor.opacity(0.7), progressColor]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * progress), height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}
