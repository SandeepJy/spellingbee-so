import SwiftUI
import AudioToolbox

// MARK: - Keyboard Sound Manager
struct KeyboardSoundManager {
    // System sound IDs for keyboard
    static let keyPressSound: SystemSoundID = 1104      // Regular key click
    static let deleteSound: SystemSoundID = 1155        // Delete key sound
    static let modifierSound: SystemSoundID = 1156      // Modifier key sound (used for submit)
    
    static func playKeyPress() {
        AudioServicesPlaySystemSound(keyPressSound)
    }
    
    static func playDelete() {
        AudioServicesPlaySystemSound(deleteSound)
    }
    
    static func playModifier() {
        AudioServicesPlaySystemSound(modifierSound)
    }
}

struct CustomKeyboardView: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var isDisabled: Bool = false
    
    private let topRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let middleRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    private let bottomRow = ["Z", "X", "C", "V", "B", "N", "M"]
    
    private let keySpacing: CGFloat = 5
    private let rowSpacing: CGFloat = 8
    
    var body: some View {
        VStack(spacing: rowSpacing) {
            // Top row
            HStack(spacing: keySpacing) {
                ForEach(topRow, id: \.self) { key in
                    KeyButton(key: key, isDisabled: isDisabled) {
                        text += key.lowercased()
                        KeyboardSoundManager.playKeyPress()
                        provideHapticFeedback()
                    }
                }
            }
            
            // Middle row (slightly indented like real keyboard)
            HStack(spacing: keySpacing) {
                Spacer(minLength: 15)
                ForEach(middleRow, id: \.self) { key in
                    KeyButton(key: key, isDisabled: isDisabled) {
                        text += key.lowercased()
                        KeyboardSoundManager.playKeyPress()
                        provideHapticFeedback()
                    }
                }
                Spacer(minLength: 15)
            }
            
            // Bottom row with delete
            HStack(spacing: keySpacing) {
                // Clear all button
                Button(action: {
                    text = ""
                    KeyboardSoundManager.playDelete()
                    provideHapticFeedback()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.red.opacity(0.8), Color.pink.opacity(0.9)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(6)
                        .shadow(color: Color.red.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .disabled(isDisabled || text.isEmpty)
                .opacity(isDisabled || text.isEmpty ? 0.5 : 1.0)
                
                ForEach(bottomRow, id: \.self) { key in
                    KeyButton(key: key, isDisabled: isDisabled) {
                        text += key.lowercased()
                        KeyboardSoundManager.playKeyPress()
                        provideHapticFeedback()
                    }
                }
                
                // Delete button (backspace)
                Button(action: {
                    if !text.isEmpty {
                        text.removeLast()
                        KeyboardSoundManager.playDelete()
                        provideHapticFeedback()
                    }
                }) {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange, Color.yellow.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(6)
                        .shadow(color: Color.orange.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .disabled(isDisabled || text.isEmpty)
                .opacity(isDisabled || text.isEmpty ? 0.5 : 1.0)
            }
            
            // Submit button
            Button(action: {
                KeyboardSoundManager.playModifier()
                provideHapticFeedback(style: .medium)
                onSubmit()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text("Submit Answer")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: (text.isEmpty || isDisabled) ? [.gray, .gray] : [.green, .blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: (text.isEmpty || isDisabled) ? Color.clear : Color.green.opacity(0.3), radius: 3, x: 0, y: 2)
            }
            .disabled(text.isEmpty || isDisabled)
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            Color(.systemGray5)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
        )
    }
    
    private func provideHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
}

struct KeyButton: View {
    let key: String
    var isDisabled: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
                )
                .scaleEffect(isPressed ? 1.15 : 1.0)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .buttonStyle(KeyPressButtonStyle(isPressed: $isPressed))
    }
}

// Custom button style for key press animation
struct KeyPressButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                withAnimation(.easeOut(duration: 0.1)) {
                    isPressed = newValue
                }
            }
    }
}

// MARK: - Text display that looks like a normal input field
struct SpellingInputDisplay: View {
    let text: String
    let placeholder: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if text.isEmpty {
                // Placeholder with cursor
                EmptyStateWithCursor(placeholder: placeholder)
            } else {
                // Text content that wraps with inline cursor
                InlineTextWithCursor(text: text)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
        )
    }
}

// MARK: - Empty state with blinking cursor and placeholder
struct EmptyStateWithCursor: View {
    let placeholder: String
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let showCursor = calculateCursorVisibility(date: timeline.date)
            
            HStack(spacing: 2) {
                Text("│")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(showCursor ? .blue : .clear)
                
                Text(placeholder)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }
    
    private func calculateCursorVisibility(date: Date) -> Bool {
        Int(date.timeIntervalSince1970 * 2) % 2 == 0
    }
}

// MARK: - Inline text with cursor that stays after last character
struct InlineTextWithCursor: View {
    let text: String
    
    private let textFont = Font.system(size: 24, weight: .medium, design: .rounded)
    private let cursorFont = Font.system(size: 24, weight: .medium)
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let showCursor = calculateCursorVisibility(date: timeline.date)
            
            createTextWithCursor(showCursor: showCursor)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }
    
    private func calculateCursorVisibility(date: Date) -> Bool {
        Int(date.timeIntervalSince1970 * 2) % 2 == 0
    }
    
    private func createTextWithCursor(showCursor: Bool) -> Text {
        Text(text)
            .font(textFont)
            .foregroundColor(.primary)
        +
        Text("│")
            .font(cursorFont)
            .foregroundColor(showCursor ? .blue : .clear)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Empty state
        SpellingInputDisplay(text: "", placeholder: "Type the word you hear...")
            .padding(.horizontal)
        
        // Short word
        SpellingInputDisplay(text: "hello", placeholder: "Type the word you hear...")
            .padding(.horizontal)
        
        // Medium word
        SpellingInputDisplay(text: "extraordinary", placeholder: "Type the word you hear...")
            .padding(.horizontal)
        
        // Long word that wraps
        SpellingInputDisplay(text: "supercalifragilistic", placeholder: "Type the word you hear...")
            .padding(.horizontal)
        
        // Very long word that wraps multiple lines
        SpellingInputDisplay(text: "supercalifragilisticexpialidocious", placeholder: "Type the word you hear...")
            .padding(.horizontal)
        
        Spacer()
        
        CustomKeyboardView(text: .constant("hello"), onSubmit: {})
    }
    .background(Color(.systemGray6))
}
