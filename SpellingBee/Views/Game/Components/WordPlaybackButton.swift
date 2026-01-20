import SwiftUI

struct WordPlaybackButton: View {
    let isPlaying: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                
                Text(isPlaying ? "Playing..." : "Tap to hear word")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 130, height: 130)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isPlaying ? Color.orange : Color.blue,
                                isPlaying ? Color.red : Color.purple
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(isPlaying ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isPlaying)
        }
        .disabled(isDisabled)
    }
}
