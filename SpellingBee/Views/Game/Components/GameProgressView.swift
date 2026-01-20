import SwiftUI

struct GameProgressView: View {
    let completedCount: Int
    let totalCount: Int
    let correctCount: Int
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(completedCount), total: Double(totalCount))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 1.5)
                .animation(.easeInOut, value: completedCount)
            
            HStack {
                Text("Word \(min(completedCount + 1, totalCount)) of \(totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(correctCount)/\(totalCount) correct")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
    }
}
