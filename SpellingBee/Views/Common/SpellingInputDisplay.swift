import SwiftUI

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
