import SwiftUI

struct CorrectAnswerOverlay: View {
    let points: Int
    let onDismiss: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Correct!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("+\(points) points")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .scaleEffect(showContent ? 1.0 : 0.5)
        .opacity(showContent ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showContent = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showContent = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

struct CorrectSpellingOverlay: View {
    let correctWord: String
    let userAnswer: String
    let onDismiss: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Incorrect")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Text("Correct spelling:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(correctWord)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(12)
                
                if !userAnswer.isEmpty {
                    Text("You typed: \(userAnswer)")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                        .padding(.top, 4)
                }
            }
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .scaleEffect(showContent ? 1.0 : 0.5)
        .opacity(showContent ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showContent = true
            }
            
            // Fixed: Use asyncAfter instead of async(after:)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showContent = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.4)
        VStack(spacing: 40) {
            CorrectAnswerOverlay(points: 85, onDismiss: {})
            CorrectSpellingOverlay(correctWord: "hello", userAnswer: "helo", onDismiss: {})
        }
    }
}
