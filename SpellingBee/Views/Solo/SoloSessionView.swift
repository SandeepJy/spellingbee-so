import SwiftUI
import AVFoundation

struct SoloSessionView: View {
    @EnvironmentObject var soloManager: SoloModeManager
    @Environment(\.dismiss) var dismiss
    
    // Game state
    @State private var userInput = ""
    @State private var isPlaying = false
    @State private var hasPlayedWord = false
    @State private var timeRemaining: Double = 5.0
    @State private var timerTask: Task<Void, Never>?
    @State private var isTimerRunning = false
    
    // Feedback states
    @State private var showCorrectAnswer = false
    @State private var showWrongAnswer = false
    @State private var lastCorrectWord = ""
    @State private var lastUserAnswer = ""
    @State private var lastPoints = 0
    @State private var isProcessingAnswer = false
    @State private var showStarExplosion = false
    @State private var showTimeUp = false
    
    // Audio
    @State private var audioPlayer: AVAudioPlayer?
    
    // Hint states
    @State private var activeHints: Set<HintType> = []
    @State private var showHintMenu = false
    
    // Computed
    private var session: SoloSession? { soloManager.currentSession }
    
    private var currentWord: Word? {
        guard let session = session,
              session.currentWordIndex < session.words.count else { return nil }
        return session.words[session.currentWordIndex]
    }
    
    private var isLevelComplete: Bool {
        session?.isLevelComplete ?? false
    }
    
    private var isOutOfWords: Bool {
        guard let session = session else { return false }
        return session.currentWordIndex >= session.words.count && !session.isLevelComplete
    }
    
    private var config: SoloLevelConfig {
        SoloLevelConfig.config(for: session?.level ?? 1)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header with streak progress
                    SessionHeader(
                        level: session?.level ?? 1,
                        currentStreak: session?.currentStreak ?? 0,
                        requiredStreak: session?.requiredStreak ?? 5,
                        totalCorrect: session?.correctWords.count ?? 0,
                        totalAttempted: session?.totalWordsAttempted ?? 0
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Streak dots
                    StreakDotsView(
                        currentStreak: session?.currentStreak ?? 0,
                        requiredStreak: session?.requiredStreak ?? 5
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    
                    if isLevelComplete {
                        // Level Complete
                        LevelCompleteView(
                            session: session!,
                            xpEarned: calculateXP(),
                            onContinue: {
                                Task {
                                    await soloManager.completeSession()
                                }
                                dismiss()
                            }
                        )
                        .padding()
                    } else if isOutOfWords {
                        // Ran out of words without completing
                        OutOfWordsView(
                            session: session!,
                            onRetry: { dismiss() }
                        )
                        .padding()
                    } else if currentWord != nil {
                        // Active gameplay
                        ScrollView {
                            VStack(spacing: 20) {
                                // Timer
                                TimerView(
                                    timeRemaining: timeRemaining,
                                    timeLimit: config.timeLimit,
                                    isRunning: isTimerRunning
                                )
                                
                                // Play button
                                WordPlayButton(
                                    isPlaying: isPlaying,
                                    hasPlayed: hasPlayedWord,
                                    onPlay: { Task { await playWord() } }
                                )
                                
                                // Hints display
                                if !activeHints.isEmpty, let word = currentWord {
                                    ActiveHintsDisplay(hints: activeHints, word: word)
                                        .padding(.horizontal)
                                }
                                
                                // Input
                                SpellingInputDisplay(
                                    text: userInput,
                                    placeholder: "Type the word you hear..."
                                )
                                .padding(.horizontal)
                                
                                // Hint button
                                if hasPlayedWord {
                                    HintButton(
                                        availableHints: soloManager.soloProgress?.availableHints ?? 0,
                                        onTap: { showHintMenu = true }
                                    )
                                }
                            }
                            .padding(.vertical)
                        }
                        
                        Spacer(minLength: 0)
                        
                        // Keyboard
                        if !showCorrectAnswer && !showWrongAnswer && !showTimeUp {
                            CustomKeyboardView(
                                text: $userInput,
                                onSubmit: { checkSpelling() },
                                isDisabled: isProcessingAnswer || !hasPlayedWord
                            )
                        }
                    }
                }
                
                // Overlays
                if showWrongAnswer {
                    overlayBackground
                    CorrectSpellingOverlay(
                        correctWord: lastCorrectWord,
                        userAnswer: lastUserAnswer,
                        onDismiss: { moveToNextWord() }
                    )
                    .zIndex(1)
                }
                
                if showCorrectAnswer {
                    overlayBackground
                    CorrectAnswerOverlay(
                        points: lastPoints,
                        onDismiss: { moveToNextWord() }
                    )
                    .zIndex(1)
                }
                
                if showTimeUp {
                    overlayBackground
                    TimeUpOverlay(
                        correctWord: lastCorrectWord,
                        onDismiss: { moveToNextWord() }
                    )
                    .zIndex(1)
                }
                
                ExplodingStarsView(isAnimating: $showStarExplosion)
                    .allowsHitTesting(false)
                    .zIndex(2)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        timerTask?.cancel()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showHintMenu) {
            if let word = currentWord {
                HintMenuSheet(
                    word: word,
                    availableHints: soloManager.soloProgress?.availableHints ?? 0,
                    activeHints: activeHints,
                    onSelectHint: useHint
                )
                .presentationDetents([.height(400)])
            }
        }
        .onAppear { configureAudioSession() }
        .onDisappear { timerTask?.cancel() }
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
    
    private func playWord() async {
        guard let word = currentWord, let soundURL = word.soundURL else { return }
        
        isPlaying = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: soundURL)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            if let duration = audioPlayer?.duration {
                try await Task.sleep(for: .seconds(duration))
            }
            
            isPlaying = false
            hasPlayedWord = true
            
            // Start countdown timer after word finishes playing
            startCountdown()
        } catch {
            print("Error playing audio: \(error)")
            isPlaying = false
        }
    }
    
    // MARK: - Timer
    
    private func startCountdown() {
        timeRemaining = config.timeLimit
        isTimerRunning = true
        timerTask?.cancel()
        
        timerTask = Task {
            while !Task.isCancelled && timeRemaining > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                await MainActor.run {
                    timeRemaining -= 0.05
                    if timeRemaining <= 0 {
                        timeRemaining = 0
                        handleTimeout()
                    }
                }
            }
        }
    }
    
    private func handleTimeout() {
        guard !isProcessingAnswer else { return }
        isProcessingAnswer = true
        timerTask?.cancel()
        isTimerRunning = false
        
        lastCorrectWord = currentWord?.word ?? ""
        showTimeUp = true
        
        Task {
            await soloManager.recordTimeout(correctWord: lastCorrectWord)
        }
    }
    
    // MARK: - Spelling
    
    private func checkSpelling() {
        guard let word = currentWord, !isProcessingAnswer else { return }
        
        isProcessingAnswer = true
        timerTask?.cancel()
        isTimerRunning = false
        
        let userAnswer = userInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = userAnswer == word.word.lowercased()
        
        lastCorrectWord = word.word
        lastUserAnswer = userInput
        
        // Update stats
        if var session = soloManager.currentSession {
            let timeUsed = config.timeLimit - timeRemaining
            session.sessionStats.updateWithWordTime(timeUsed, wasCorrect: isCorrect, currentStreak: session.currentStreak + (isCorrect ? 1 : 0))
            soloManager.currentSession = session
        }
        
        if isCorrect {
            lastPoints = calculateWordPoints()
            showStarExplosion = true
            showCorrectAnswer = true
            Task { await soloManager.recordCorrectWord(word: word.word) }
        } else {
            showWrongAnswer = true
            Task { await soloManager.recordIncorrectWord(correctWord: word.word, userAnswer: userInput) }
        }
    }
    
    private func moveToNextWord() {
        showCorrectAnswer = false
        showWrongAnswer = false
        showTimeUp = false
        userInput = ""
        timeRemaining = config.timeLimit
        hasPlayedWord = false
        isProcessingAnswer = false
        isTimerRunning = false
        activeHints = []
    }
    
    private func calculateWordPoints() -> Int {
        let timeUsed = config.timeLimit - timeRemaining
        let basePoints = 100
        let timePenalty = Int(timeUsed * 10) // Faster = more points
        let hintPenalty = activeHints.count * 10
        return max(10, basePoints - timePenalty - hintPenalty)
    }
    
    private func calculateXP() -> Int {
        guard let session = session else { return 0 }
        var xp = session.correctWords.count * 10
        if session.isLevelComplete { xp += 50 }
        if session.misspelledWords.isEmpty { xp += 30 }
        if session.hintsUsed == 0 { xp += 20 }
        xp = Int(Double(xp) * (1.0 + Double(session.level) * 0.05))
        return xp
    }
    
    // MARK: - Hints
    
    private func useHint(_ type: HintType) {
        guard let progress = soloManager.soloProgress else { return }
        
        if type.cost > 0 && progress.availableHints < type.cost {
            return
        }
        
        if type.cost > 0 && !activeHints.contains(type) {
            Task {
                let success = await soloManager.useHint()
                if success {
                    activeHints.insert(type)
                    if var session = soloManager.currentSession {
                        session.hintsUsed += 1
                        soloManager.currentSession = session
                    }
                }
            }
        } else if type.cost == 0 {
            activeHints.insert(type)
        }
        showHintMenu = false
    }
}

// MARK: - Session Header
struct SessionHeader: View {
    let level: Int
    let currentStreak: Int
    let requiredStreak: Int
    let totalCorrect: Int
    let totalAttempted: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Level \(level)")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("\(currentStreak)/\(requiredStreak) in a row")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(totalCorrect)")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                if totalAttempted > 0 {
                    Text("\(totalAttempted) attempted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Streak Dots
struct StreakDotsView: View {
    let currentStreak: Int
    let requiredStreak: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<requiredStreak, id: \.self) { index in
                Circle()
                    .fill(index < currentStreak ? Color.green : Color(.systemGray4))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(index == currentStreak - 1 && currentStreak > 0 ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: currentStreak)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
    }
    
    private var dotSize: CGFloat {
        if requiredStreak <= 7 { return 14 }
        if requiredStreak <= 10 { return 11 }
        return 9
    }
}

// MARK: - Timer View
struct TimerView: View {
    let timeRemaining: Double
    let timeLimit: Double
    let isRunning: Bool
    
    private var progress: Double {
        guard timeLimit > 0 else { return 0 }
        return timeRemaining / timeLimit
    }
    
    private var timerColor: Color {
        if timeRemaining <= 1.0 { return .red }
        if timeRemaining <= 2.0 { return .orange }
        return .green
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: max(0, progress))
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: timeRemaining)
                
                Text(String(format: "%.1f", max(0, timeRemaining)))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
            }
            
            if !isRunning {
                Text("Play word to start timer")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(isRunning || timeRemaining < timeLimit ? 1.0 : 0.5)
    }
}

// MARK: - Word Play Button
struct WordPlayButton: View {
    let isPlaying: Bool
    let hasPlayed: Bool
    let onPlay: () -> Void
    
    var body: some View {
        Button(action: onPlay) {
            VStack(spacing: 10) {
                Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                
                Text(isPlaying ? "Playing..." : (hasPlayed ? "Replay" : "Tap to hear word"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 130, height: 130)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isPlaying ? .orange : .blue,
                                isPlaying ? .red : .purple
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: (isPlaying ? Color.orange : Color.blue).opacity(0.4), radius: 10)
            .scaleEffect(isPlaying ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isPlaying)
        }
        .disabled(isPlaying)
    }
}

// MARK: - Active Hints Display
struct ActiveHintsDisplay: View {
    let hints: Set<HintType>
    let word: Word
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(hints), id: \.self) { hint in
                HStack {
                    Image(systemName: hint.icon)
                        .foregroundColor(.yellow)
                        .frame(width: 20)
                    Text(hintText(for: hint))
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
        }
    }
    
    private func hintText(for type: HintType) -> String {
        switch type {
        case .wordLength: return "\(word.word.count) letters"
        case .firstLetter: return "Starts with '\(word.word.prefix(1).uppercased())'"
        case .definition: return word.definition ?? "No definition available"
        case .example: return word.exampleSentence ?? "No example available"
        }
    }
}



// MARK: - Hint Button
struct HintButton: View {
    let availableHints: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Hints (\(availableHints))")
                    .fontWeight(.medium)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.yellow.opacity(0.2)))
        }
    }
}

// MARK: - Time Up Overlay
struct TimeUpOverlay: View {
    let correctWord: String
    let onDismiss: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Time's Up!")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Text("The word was:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(correctWord)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(12)
            }
            
            Text("Streak reset!")
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 20)
        )
        .scaleEffect(showContent ? 1.0 : 0.5)
        .opacity(showContent ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) { showContent = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
            }
        }
    }
}

// MARK: - Level Complete View
struct LevelCompleteView: View {
    let session: SoloSession
    let xpEarned: Int
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
            
            Text("Level Complete! 🎉")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You spelled \(session.requiredStreak) words correctly in a row!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                CompletionStatRow(icon: "checkmark.circle.fill", label: "Correct", value: "\(session.correctWords.count)", color: .green)
                CompletionStatRow(icon: "xmark.circle.fill", label: "Incorrect", value: "\(session.misspelledWords.count)", color: .red)
                CompletionStatRow(icon: "number", label: "Total Attempts", value: "\(session.totalWordsAttempted)", color: .blue)
                CompletionStatRow(icon: "star.fill", label: "XP Earned", value: "+\(xpEarned)", color: .yellow)
                
                if session.misspelledWords.isEmpty {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("Perfect Run!")
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
            
            Button(action: onContinue) {
                Text("Continue")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(14)
            }
        }
    }
}

struct CompletionStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Out Of Words View
struct OutOfWordsView: View {
    let session: SoloSession
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Not Enough Words")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("You ran out of words before completing the streak. Try again!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                Text("Best streak: \(session.sessionStats.longestStreak)/\(session.requiredStreak)")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Correct: \(session.correctWords.count) | Incorrect: \(session.misspelledWords.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onRetry) {
                Text("Back to Menu")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(14)
            }
        }
    }
}
