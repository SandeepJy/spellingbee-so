import SwiftUI

/// A generic horizontal carousel with snapping behavior and peek into adjacent items.
struct SnapCarousel<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let itemWidth: CGFloat
    let itemSpacing: CGFloat
    let peekAmount: CGFloat
    @Binding var currentIndex: Int
    @ViewBuilder let content: (Item) -> Content
    
    @GestureState private var dragOffset: CGFloat = 0
    
    init(
        items: [Item],
        itemWidth: CGFloat = 280,
        itemSpacing: CGFloat = 16,
        peekAmount: CGFloat = 24,
        currentIndex: Binding<Int>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.itemWidth = itemWidth
        self.itemSpacing = itemSpacing
        self.peekAmount = peekAmount
        self._currentIndex = currentIndex
        self.content = content
    }
    
    private var totalItemWidth: CGFloat {
        itemWidth + itemSpacing
    }
    
    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = (geometry.size.width - itemWidth) / 2
            
            HStack(spacing: itemSpacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    content(item)
                        .frame(width: itemWidth)
                        .scaleEffect(scaleFor(index: index))
                        .opacity(opacityFor(index: index))
                        .animation(.easeInOut(duration: 0.2), value: currentIndex)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .offset(x: calculateOffset(containerWidth: geometry.size.width))
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 40.0
                        var newIndex = currentIndex
                        
                        if value.translation.width < -threshold {
                            newIndex = min(currentIndex + 1, items.count - 1)
                        } else if value.translation.width > threshold {
                            newIndex = max(currentIndex - 1, 0)
                        }
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentIndex = newIndex
                        }
                    }
            )
            .onAppear {
                // Ensure currentIndex is within bounds
                if currentIndex >= items.count {
                    currentIndex = max(0, items.count - 1)
                }
            }
            .onChange(of: items.count) { _, newCount in
                // Reset index if items change
                if currentIndex >= newCount {
                    currentIndex = max(0, newCount - 1)
                }
            }
        }
    }
    
    private func calculateOffset(containerWidth: CGFloat) -> CGFloat {
        let baseOffset = -CGFloat(currentIndex) * totalItemWidth
        return baseOffset + dragOffset
    }
    
    private func scaleFor(index: Int) -> CGFloat {
        let distance = abs(index - currentIndex)
        if distance == 0 { return 1.0 }
        if distance == 1 { return 0.95 }
        return 0.9
    }
    
    private func opacityFor(index: Int) -> Double {
        let distance = abs(index - currentIndex)
        if distance == 0 { return 1.0 }
        if distance == 1 { return 0.7 }
        return 0.5
    }
}

/// Page indicator dots for the carousel
struct CarouselPageIndicator: View {
    let totalPages: Int
    let currentPage: Int
    var activeColor: Color = .blue
    var inactiveColor: Color = Color(.systemGray4)
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? activeColor : inactiveColor)
                    .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewItem: Identifiable {
        let id = UUID()
        let title: String
        let color: Color
    }
    
    struct PreviewWrapper: View {
        @State private var currentIndex = 0
        
        let items = [
            PreviewItem(title: "Card 1", color: .blue),
            PreviewItem(title: "Card 2", color: .green),
            PreviewItem(title: "Card 3", color: .orange),
            PreviewItem(title: "Card 4", color: .purple)
        ]
        
        var body: some View {
            VStack {
                SnapCarousel(
                    items: items,
                    itemWidth: 280,
                    itemSpacing: 16,
                    peekAmount: 24,
                    currentIndex: $currentIndex
                ) { item in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(item.color)
                        .overlay(
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                .frame(height: 180)
                
                CarouselPageIndicator(totalPages: items.count, currentPage: currentIndex)
                    .padding(.top, 8)
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
