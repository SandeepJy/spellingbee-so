import SwiftUI
import AVFoundation

struct SoloSessionView: View {
    @EnvironmentObject var soloManager: SoloModeManager
    @Environment(\.dismiss) var dismiss
    
    @State var session: SoloSession
    
    // Game state
    @State private var currentWordIndex = 0
    @State private var userInput = ""
    @State private var isPlaying = false
    @State private var timeElapsed: Double = 0
    @State private var wordStartTime: Date?
    @State private var timerTask: Task<Void, Never>?
    
    // Feedback states
    @State private var showCorrectAnswer = false
    @State private var showWrongAnswer = false
    @State private var lastCorrectWord = ""
    @State private var lastUserAnswer = ""
    @State private var lastPoints = 0
    @State private var isProcessingAnswer = false
    @State private var showStarExplosion = false
    
    // Hint states
    @State private var activeHints: Set<HintType> = []
    @State private var showHintMenu = false
    @State private var showNoHintsAlert = false
    
    // Audio
    @State private var audioPlayer: AVAudioPlayer?
    
    // Session complete
    @State private var showSessionComplete = false
    
    // Computed properties
    private var currentWord: Word? {
        guard currentWordIndex < session.words.count else { return nil }
        return session.words[currentWordIndex]
    }
    
    private var isSessionComplete: Bool {
        session.completedWordIndices.count >= session.wordCount
    }
    
    private var sessionXP: Int {
        var xp = 0
        
        // Base XP per correct word
        xp += session.correctWords.count * 10
        
        // Bonus for accuracy
        if session.accuracy >= 100 {
            xp += 50
        } else if session.accuracy >= 90 {
            xp += 30
        } else if session.accuracy >= 80 {
            xp += 15
        }
        
        // Bonus for not using hints
        if session.hintsUsed == 0 && session.correctWords.count >= 5 {
            xp += 20
        }
        
        // Level multiplier
        xp = Int(Double(xp) * (1.0 + Double(session.level) * 0.1))
        
        return xp
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header
                    SoloSessionHeader(
                        level: session.level,
                        currentWordIndex: currentWordIndex + 1,
                        totalWords: session.wordCount,
                        correctCount: session.correctWords.count
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Progress
                    SessionProgressBar(
                        completed: session.completedWordIndices.count,
                        total: session.wordCount,
                        correctCount: session.correctWords.count
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            if !isSessionComplete && currentWord != nil {
                                // Word playback
                                WordPlaySection(
                                    isPlaying: $isPlaying,
                                    timeElapsed: timeElapsed,
                                    hints: activeHints,
                                    word: currentWord!,
                                    availableHints: soloManager.soloProgress?.availableHints ?? 0,
                                    onPlay: playWord,
                                    onHintTap: { showHintMenu = true }
                                )
                                
                                // Input display
                                SpellingInputDisplay(
                                    text: userInput,
                                    placeholder: "Type the word you hear..."
                                )
                                .padding(.horizontal)
                            } else if isSessionComplete {
                                SessionCompleteView(
                                    session: session,
                                    xpEarned: sessionXP,
                                    onReviewTap: {
                                        // TODO: Implement review
                                    },
                                    onContinue: {
                                        dismiss()
                                    }
                                )
                                .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Keyboard
                    if !isSessionComplete && currentWord != nil && !showCorrectAnswer && !showWrongAnswer {
                        CustomKeyboardView(
                            text: $userInput,
                            onSubmit: checkSpelling,
                            isDisabled: isProcessingAnswer
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                // Answer overlays
                if showWrongAnswer {
                    overlayBackground
                    CorrectSpellingOverlay(
                        correctWord: lastCorrectWord,
                        userAnswer: lastUserAnswer,
                        onDismiss: moveToNextWord
                    )
                    .zIndex(1)
                }
                
                if showCorrectAnswer {
                    overlayBackground
                    CorrectAnswerOverlay(
                        points: lastPoints,
                        onDismiss: moveToNextWord
                    )
                    .zIndex(1)
                }
                
                // Star explosion
                ExplodingStarsView(isAnimating: $showStarExplosion)
                    .allowsHitTesting(false)
                    .zIndex(2)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        // Save progress before exiting
                        Task {
                            await soloManager.updateSession(session)
                        }
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showHintMenu) {
            HintMenuSheet(
                word: currentWord!,
                availableHints: soloManager.soloProgress?.availableHints ?? 0,
                activeHints: activeHints,
                onSelectHint: useHint
            )
            .presentationDetents([.height(400)])
        }
        .alert("No Hints Available", isPresented: $showNoHintsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You've used all your daily hints. Hints reset every day at midnight.")
        }
        .onAppear {
            configureAudioSession()
        }
        .onDisappear {
            timerTask?.cancel()
            Task {
                session.endDate = Date()
                await soloManager.updateSession(session)
                if isSessionComplete {
                    await soloManager.completeSession()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSessionComplete)
    }
    
    private var overlayBackground: some View {
        Color.black.opacity(0.4)
            .edgesIgnoringSafeArea(.all)
            .onTapGesture { }
    }
    
    // MARK: - Audio
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func playWord() {
        guard let word = currentWord,
              let soundURL = word.soundURL else { return }
        
        isPlaying = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: soundURL)
                
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                
                // Start timer if first play
                if wordStartTime == nil {
                    wordStartTime = Date()
                    startTimer()
                }
                
                if let duration = audioPlayer?.duration {
                    try await Task.sleep(for: .seconds(duration))
                }
                
                isPlaying = false
            } catch {
                print("Error playing audio: \(error)")
                isPlaying = false
            }
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run {
                    if let startTime = wordStartTime {
                        timeElapsed = Date().timeIntervalSince(startTime)
                    }
                }
            }
        }
    }
    
    // MARK: - Spelling Check
    
    private func checkSpelling() {
        guard let word = currentWord, !isProcessingAnswer else { return }
        
        isProcessingAnswer = true
        timerTask?.cancel()
        
        let userAnswer = userInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = userAnswer == word.word.lowercased()
        
        lastCorrectWord = word.word
        lastUserAnswer = userInput
        
        // Update session stats
        session.sessionStats.updateWithWordTime(timeElapsed, wasCorrect: isCorrect)
        
        if isCorrect {
            if !session.correctWords.contains(word.word) {
                session.correctWords.append(word.word)
            }
            lastPoints = calculatePoints()
            showStarExplosion = true
            showCorrectAnswer = true
        } else {
            let misspelled = MisspelledWord(
                correctWord: word.word,
                userAnswer: userInput,
                wordIndex: currentWordIndex
            )
            if !session.misspelledWords.contains(where: { $0.correctWord == word.word }) {
                session.misspelledWords.append(misspelled)
            }
            showWrongAnswer = true
        }
        
        if !session.completedWordIndices.contains(currentWordIndex) {
            session.completedWordIndices.append(currentWordIndex)
        }
        
        // Save progress
        Task {
            await soloManager.updateSession(session)
        }
    }
    
    private func calculatePoints() -> Int {
        let basePoints = 100
        let timePenalty = Int(min(timeElapsed * 2, 50)) // Max penalty 50 points
        let hintPenalty = activeHints.count * 10
        return max(10, basePoints - timePenalty - hintPenalty)
    }
    
    private func moveToNextWord() {
        showCorrectAnswer = false
        showWrongAnswer = false
        userInput = ""
        timeElapsed = 0
        wordStartTime = nil
        isProcessingAnswer = false
        activeHints = []
        
        // Find next uncompleted word
        currentWordIndex += 1
        if currentWordIndex >= session.words.count && !isSessionComplete {
            currentWordIndex = 0
        }
        
        // Check if session is complete
        if isSessionComplete {
            completeSession()
        }
    }
    
    private func completeSession() {
        Task {
            session.totalXPEarned = sessionXP
            await soloManager.completeSession()
            showSessionComplete = true
        }
    }
    
    // MARK: - Hints
    
    private func useHint(_ type: HintType) {
        guard let progress = soloManager.soloProgress else { return }
        
        if type.cost > 0 && progress.availableHints < type.cost {
            showNoHintsAlert = true
            return
        }
        
        if type.cost > 0 && !activeHints.contains(type) {
            Task {
                let success = await soloManager.useHint()
                if success {
                    activeHints.insert(type)
                    session.hintsUsed += 1
                }
            }
        } else if type.cost == 0 {
            activeHints.insert(type)
        }
        
        showHintMenu = false
    }
}

// MARK: - Supporting Views

struct SoloSessionHeader: View {
    let level: Int
    let currentWordIndex: Int
    let totalWords: Int
    let correctCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Level \(level)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Word \(currentWordIndex) of \(totalWords)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(correctCount)")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Text("Correct")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SessionProgressBar: View {
    let completed: Int
    let total: Int
    let correctCount: Int
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * Double(completed) / Double(total)), height: 8)
                        .animation(.easeInOut, value: completed)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(completed)/\(total) completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if completed > 0 {
                    Text("\(Int(Double(correctCount) / Double(completed) * 100))% accuracy")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

struct WordPlaySection: View {
    @Binding var isPlaying: Bool
    let timeElapsed: Double
    let hints: Set<HintType>
    let word: Word
    let availableHints: Int
    let onPlay: () -> Void
    let onHintTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Play button
            Button(action: onPlay) {
                VStack(spacing: 12) {
                    Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        //.symbolEffect(.bounce, value: isPlaying)
                    
                    Text(isPlaying ? "Playing..." : "Tap to hear word")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 150, height: 150)
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
                .shadow(color: isPlaying ? Color.orange.opacity(0.5) : Color.blue.opacity(0.5), radius: 10)
            }
            .disabled(isPlaying)
            .scaleEffect(isPlaying ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isPlaying)
            
            // Active hints display
            if !hints.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(hints), id: \.self) { hint in
                        HintDisplay(type: hint, word: word)
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            // Hint button
            Button(action: onHintTap) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Hints (\(availableHints) available)")
                        .fontWeight(.medium)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.2))
                )
            }
            
            if timeElapsed > 0 {
                Text("Time: \(String(format: "%.1f", timeElapsed))s")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }
}

struct HintDisplay: View {
    let type: HintType
    let word: Word
    
    var body: some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(.yellow)
                .frame(width: 20)
            
            Text(hintText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(0.1))
        )
    }
    
    private var hintText: String {
        switch type {
        case .wordLength:
            return "\(word.word.count) letters"
        case .firstLetter:
            return "Starts with '\(word.word.prefix(1).uppercased())'"
        case .definition:
            return word.definition ?? "No definition available"
        case .example:
            return word.exampleSentence ?? "No example available"
        }
    }
}

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
                    Text(type.rawValue)
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

struct SessionCompleteView: View {
    let session: SoloSession
    let xpEarned: Int
    let onReviewTap: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Trophy
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
                //.symbolEffect(.bounce)
            
            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            // Stats
            VStack(spacing: 16) {
                SessionStatRow(
                    icon: "percent",
                    label: "Accuracy",
                    value: "\(session.accuracy)%",
                    color: session.accuracy >= 80 ? .green : .orange
                )
                
                SessionStatRow(
                    icon: "checkmark.circle.fill",
                    label: "Correct Words",
                    value: "\(session.correctWords.count)/\(session.wordCount)",
                    color: .green
                )
                
                SessionStatRow(
                    icon: "timer",
                    label: "Avg. Time",
                    value: String(format: "%.1fs", session.sessionStats.averageWordTime),
                    color: .blue
                )
                
                SessionStatRow(
                    icon: "star.fill",
                    label: "XP Earned",
                    value: "+\(xpEarned) XP",
                    color: .yellow
                )
                
                if session.sessionStats.longestPerfectStreak > 1 {
                    SessionStatRow(
                        icon: "flame.fill",
                        label: "Perfect Streak",
                        value: "\(session.sessionStats.longestPerfectStreak) words",
                        color: .orange
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            
            // Buttons
            VStack(spacing: 12) {
//                Button(action: onReviewTap) {
//                    HStack {
//                        Image(systemName: "list.bullet.clipboard")
//                        Text("Review Words")
//                    }
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(
//                        LinearGradient(
//                            gradient: Gradient(colors: [.purple, .blue]),
//                            startPoint: .leading,
//                            endPoint: .trailing
//                        )
//                    )
//                    .cornerRadius(12)
//                }
                
                Button(action: onContinue) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
        }
    }
}

struct SessionStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}
