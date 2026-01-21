import SwiftUI
struct HintMenuSheet: View {
    let word: Word
    let availableHints: Int
    let activeHints: Set<HintType>
    let onSelectHint: (HintType) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Available Hints")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("\(availableHints) hints remaining")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                .padding()
                
                Divider()
                
                // Hint options
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach([HintType.wordLength, .firstLetter, .definition, .example], id: \.self) { hint in
                            HintOptionRow(
                                type: hint,
                                isActive: activeHints.contains(hint),
                                canAfford: hint.cost <= availableHints || hint.cost == 0,
                                onTap: {
                                    onSelectHint(hint)
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Info
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Hints reset daily at midnight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HintOptionRow: View {
    let type: HintType
    let isActive: Bool
    let canAfford: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            if canAfford && !isActive {
                onTap()
            }
        }) {
            HStack {
                Image(systemName: type.icon)
                    .foregroundColor(isActive ? .green : (canAfford ? .yellow : .gray))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(isActive ? .green : (canAfford ? .primary : .gray))
                    
                    if type.cost > 0 {
                        Text("Cost: \(type.cost) hint\(type.cost > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Free")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if !canAfford {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.green.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isActive || !canAfford)
    }
}
