import SwiftUI
import AVFoundation

struct SoloSessionView: View {
    @EnvironmentObject var soloManager: SoloModeManager
    @Environment(\.dismiss) var dismiss
    
    // Game state
    @State private var userInput = ""
    @State private var isPlaying = false
    @State private var hasPlayedWord = false
    @State private var timerTask: Task<Void, Never>?
    @State private var roundTimerStarted = false
    
    // Round timer (cumulative)
    @State private var timeRemaining: Double = 0
    
    // Feedback states
    @State private var showCorrectAnswer = false
    @State private var showWrongAnswer = false
    @State private var lastCorrectWord = ""
    @State private var lastUserAnswer = ""
    @State private var lastPoints = 0
    @State private var isProcessingAnswer = false
    @State private var showStarExplosion = false
    @State private var showTimeUp = false
    
    // Round failed state
    @State private var showRoundFailed = false
    @State private var failedWord = ""
    @State private var failedUserAnswer = ""
    
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
                    } else if showRoundFailed {
                        RoundFailedView(
                            session: session!,
                            failedWord: failedWord,
                            userAnswer: failedUserAnswer,
                            onTryAgain: {
                                Task { await restartLevel() }
                            },
                            onBackToMenu: {
                                dismiss()
                            }
                        )
                    } else if isOutOfWords {
                        OutOfWordsView(
                            session: session!,
                            onRetry: { dismiss() }
                        )
                        .padding()
                    } else if currentWord != nil {
                        // Active gameplay
                        ScrollView {
                            VStack(spacing: 20) {
                                // Round Timer (cumulative)
                                RoundTimerView(
                                    timeRemaining: timeRemaining,
                                    totalTime: config.totalRoundTime,
                                    isRunning: roundTimerStarted && !isProcessingAnswer
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
                        onDismiss: { handleWrongAnswerDismiss() }
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
                        correctWord: "",
                        onDismiss: {
                            showTimeUp = false
                            Task {
                                await soloManager.completeSession()
                            }
                            dismiss()
                        }
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
        .onAppear {
            configureAudioSession()
            timeRemaining = config.totalRoundTime
        }
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
        } catch {
            print("Error playing audio: \(error)")
        }
        
        isPlaying = false
        hasPlayedWord = true
        
        // Start or resume the timer after audio finishes
        if !roundTimerStarted {
            startRoundTimer()
        } else {
            resumeTimerFromCurrent()
        }
    }
    
    // MARK: - Round Timer
    
    private func startRoundTimer() {
        roundTimerStarted = true
        runTimerLoop()
    }
    
    private func resumeTimerFromCurrent() {
        guard timeRemaining > 0 else { return }
        runTimerLoop()
    }
    
    private func runTimerLoop() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && timeRemaining > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                await MainActor.run {
                    timeRemaining -= 0.05
                    if timeRemaining <= 0 {
                        timeRemaining = 0
                        handleRoundTimeout()
                    }
                }
            }
        }
    }
    
    private func pauseTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    private func handleRoundTimeout() {
        guard !isProcessingAnswer else { return }
        isProcessingAnswer = true
        pauseTimer()
        showTimeUp = true
    }
    
    // MARK: - Spelling
    
    private func checkSpelling() {
        guard let word = currentWord, !isProcessingAnswer else { return }
        
        isProcessingAnswer = true
        pauseTimer()
        
        let userAnswer = userInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = userAnswer == word.word.lowercased()
        
        lastCorrectWord = word.word
        lastUserAnswer = userInput
        
        if var session = soloManager.currentSession {
            let wordTime = config.timePerWord
            session.sessionStats.updateWithWordTime(
                wordTime,
                wasCorrect: isCorrect,
                currentStreak: session.currentStreak + (isCorrect ? 1 : 0)
            )
            soloManager.currentSession = session
        }
        
        if isCorrect {
            lastPoints = calculateWordPoints()
            showStarExplosion = true
            showCorrectAnswer = true
            Task { await soloManager.recordCorrectWord(word: word.word) }
        } else {
            // Store failed word info for the round failed screen
            failedWord = word.word
            failedUserAnswer = userInput
            showWrongAnswer = true
            Task { await soloManager.recordIncorrectWord(correctWord: word.word, userAnswer: userInput) }
        }
    }
    
    private func handleWrongAnswerDismiss() {
        showWrongAnswer = false
        userInput = ""
        hasPlayedWord = false
        isProcessingAnswer = false
        activeHints = []
        
        // Show round failed screen instead of continuing
        showRoundFailed = true
    }
    
    private func moveToNextWord() {
        showCorrectAnswer = false
        showWrongAnswer = false
        showTimeUp = false
        userInput = ""
        hasPlayedWord = false
        isProcessingAnswer = false
        activeHints = []
    }
    
    private func restartLevel() async {
        guard let userID = session?.userID, let level = session?.level else {
            dismiss()
            return
        }
        
        // Reset states
        showRoundFailed = false
        showCorrectAnswer = false
        showWrongAnswer = false
        showTimeUp = false
        userInput = ""
        hasPlayedWord = false
        isProcessingAnswer = false
        activeHints = []
        roundTimerStarted = false
        failedWord = ""
        failedUserAnswer = ""
        
        // Reset timer
        timerTask?.cancel()
        timeRemaining = config.totalRoundTime
        
        // Create new session
        do {
            _ = try await soloManager.createSession(userID: userID, level: level)
        } catch {
            print("Failed to restart level: \(error)")
            dismiss()
        }
    }
    
    private func calculateWordPoints() -> Int {
        let basePoints = 100
        let hintPenalty = activeHints.count * 10
        let timeBonus = Int((timeRemaining / config.totalRoundTime) * 20)
        return max(10, basePoints - hintPenalty + timeBonus)
    }
    
    private func calculateXP() -> Int {
        guard let session = session else { return 0 }
        var xp = session.correctWords.count * 10
        if session.isLevelComplete { xp += 50 }
        if session.misspelledWords.isEmpty { xp += 30 }
        if session.hintsUsed == 0 { xp += 20 }
        if timeRemaining > 0 {
            xp += Int(timeRemaining / config.totalRoundTime * 30)
        }
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

// MARK: - Round Failed View

struct RoundFailedView: View {
    let session: SoloSession
    let failedWord: String
    let userAnswer: String
    let onTryAgain: () -> Void
    let onBackToMenu: () -> Void
    
    @State private var showContent = false
    
    private var streakProgress: String {
        "\(session.currentStreak)/\(session.requiredStreak)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.red)
                    }
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .opacity(showContent ? 1.0 : 0.0)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Round Failed")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("You need \(session.requiredStreak) correct in a row")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(showContent ? 1.0 : 0.0)
                    
                    // Failed word card
                    VStack(spacing: 12) {
                        Text("The word was:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(failedWord)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.green.opacity(0.15))
                            )
                        
                        if !userAnswer.isEmpty && userAnswer != "(timed out)" {
                            HStack(spacing: 4) {
                                Text("You typed:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(userAnswer)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                    .opacity(showContent ? 1.0 : 0.0)
                    
                    // Stats
                    VStack(spacing: 12) {
                        RoundFailedStatRow(
                            icon: "flame.fill",
                            label: "Streak Reached",
                            value: streakProgress,
                            color: .orange
                        )
                        RoundFailedStatRow(
                            icon: "checkmark.circle.fill",
                            label: "Words Correct",
                            value: "\(session.correctWords.count)",
                            color: .green
                        )
                        RoundFailedStatRow(
                            icon: "number",
                            label: "Total Attempted",
                            value: "\(session.totalWordsAttempted)",
                            color: .blue
                        )
                        if session.sessionStats.longestStreak > 0 {
                            RoundFailedStatRow(
                                icon: "star.fill",
                                label: "Best Streak",
                                value: "\(session.sessionStats.longestStreak)",
                                color: .yellow
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .opacity(showContent ? 1.0 : 0.0)
                    
                    // Encouragement
                    Text(encouragementMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(showContent ? 1.0 : 0.0)
                    
                    // Bottom padding so content doesn't hide behind pinned buttons
                    Spacer(minLength: 16)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            
            // Pinned action buttons — always visible
            VStack(spacing: 12) {
                Button(action: onTryAgain) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Try Again")
                            .fontWeight(.bold)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Button(action: onBackToMenu) {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                        Text("Back to Menu")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: -2)
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
    
    private var encouragementMessage: String {
        let messages = [
            "Don't give up! Practice makes perfect. 💪",
            "Every mistake is a chance to learn! 📚",
            "You've got this! Try again! 🌟",
            "Keep going — you're improving! 🚀",
            "Almost there! One more try! ✨"
        ]
        return messages.randomElement() ?? messages[0]
    }
}
struct RoundFailedStatRow: View {
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
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
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

// MARK: - Round Timer View

struct RoundTimerView: View {
    let timeRemaining: Double
    let totalTime: Double
    let isRunning: Bool
    
    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return max(0, timeRemaining / totalTime)
    }
    
    private var timerColor: Color {
        if progress <= 0.15 { return .red }
        if progress <= 0.3 { return .orange }
        return .green
    }
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return String(format: "%.1f", max(0, timeRemaining))
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 5)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: timeRemaining)
                
                Image(systemName: "timer")
                    .font(.system(size: 16))
                    .foregroundColor(timerColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTime)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
                
                if !isRunning {
                    Text("Starts on first play")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Round timer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(progress <= 0.15 ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .opacity(isRunning ? 1.0 : 0.6)
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
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Time's Up!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You ran out of time for this round.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Try again to beat the clock!")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: onDismiss) {
                Text("Back to Menu")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 20)
        )
        .padding(.horizontal, 40)
        .scaleEffect(showContent ? 1.0 : 0.5)
        .opacity(showContent ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showContent = true
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
