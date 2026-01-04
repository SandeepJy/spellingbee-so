import SwiftUI
import AVFoundation

// MARK: - Star Particle for Animation
struct StarParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double
    var rotation: Double
    var color: Color
}

// MARK: - Exploding Stars View
struct ExplodingStarsView: View {
    @Binding var isAnimating: Bool
    @State private var particles: [StarParticle] = []
    
    private let colors: [Color] = [.yellow, .orange, .pink, .purple, .blue, .green]
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Image(systemName: "star.fill")
                    .foregroundColor(particle.color)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(x: particle.x, y: particle.y)
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                createExplosion()
            }
        }
    }
    
    private func createExplosion() {
        particles = []
        
        for _ in 0..<25 {
            let particle = StarParticle(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height / 2 - 50,
                scale: CGFloat.random(in: 0.3...1.2),
                opacity: 1.0,
                rotation: Double.random(in: 0...360),
                color: colors.randomElement() ?? .yellow
            )
            particles.append(particle)
        }
        
        withAnimation(.easeOut(duration: 1.0)) {
            for i in particles.indices {
                let angle = Double.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 120...280)
                particles[i].x += cos(angle) * distance
                particles[i].y += sin(angle) * distance
                particles[i].scale *= CGFloat.random(in: 0.5...1.8)
                particles[i].rotation += Double.random(in: 180...720)
            }
        }
        
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            for i in particles.indices {
                particles[i].opacity = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            isAnimating = false
            particles = []
        }
    }
}

// MARK: - Answer Overlay Views
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

// MARK: - Game Header View
struct GameHeaderView: View {
    let game: MultiUserGame
    let score: Int
    let correctCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spell the Words")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                Text("\(game.difficultyText) - \(game.wordCount) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Score: \(score)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("\(correctCount) correct")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Game Progress View
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

// MARK: - Word Playback Button
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
                    .symbolEffect(.bounce, value: isPlaying)
                
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

// MARK: - Active Game Content View
struct ActiveGameContentView: View {
    let isPlaying: Bool
    let isProcessingAnswer: Bool
    let timeElapsed: Double
    @Binding var userInput: String
    let onPlayWord: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            WordPlaybackButton(
                isPlaying: isPlaying,
                isDisabled: isPlaying || isProcessingAnswer,
                onTap: onPlayWord
            )
            
            VStack(spacing: 8) {
                SpellingInputDisplay(
                    text: userInput,
                    placeholder: "Type the word you hear..."
                )
                
                if timeElapsed > 0 {
                    Text("Time: \(String(format: "%.1f", timeElapsed))s")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

// MARK: - Player Progress Item
struct PlayerProgressItem: View {
    let participant: SpellGameUser
    let completed: Int
    let total: Int
    
    var body: some View {
        HStack {
            Circle()
                .fill(completed >= total ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            
            Text(participant.displayName)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if completed >= total {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Text("\(completed)/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Player Progress List View
struct PlayerProgressListView: View {
    let game: MultiUserGame
    let gameManager: GameManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Player Progress:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ForEach(Array(game.participantsIDs), id: \.self) { participantID in
                if let participant = gameManager.getUser(by: participantID) {
                    let progress = gameManager.getUserProgress(for: game.id, userID: participantID)
                    let completed = progress?.completedWordIndices.count ?? 0
                    
                    PlayerProgressItem(
                        participant: participant,
                        completed: completed,
                        total: game.wordCount
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Waiting For Players View
struct WaitingForPlayersView: View {
    let game: MultiUserGame
    let gameManager: GameManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .symbolEffect(.pulse)
            
            Text("All words entered!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Waiting for other players to finish...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            PlayerProgressListView(game: game, gameManager: gameManager)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

// MARK: - Score Data Model
struct ScoreData: Identifiable {
    let id: String
    let userID: String
    let displayName: String
    let score: Int
}

// MARK: - Winner Display View
struct WinnerDisplayView: View {
    let winner: SpellGameUser
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Winner:")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(winner.initialLetter)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    )
                
                Text(winner.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Final Scores View
struct FinalScoresView: View {
    let scores: [ScoreData]
    let winnerID: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Final Scores:")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(scores) { scoreData in
                HStack {
                    Text(scoreData.displayName)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(scoreData.score) pts")
                        .fontWeight(.bold)
                        .foregroundColor(scoreData.userID == winnerID ? .yellow : .blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Game Complete View
struct GameCompleteView: View {
    let winner: SpellGameUser?
    let scores: [ScoreData]
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Game Complete!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let winner = winner {
                WinnerDisplayView(winner: winner)
            }
            
            FinalScoresView(scores: scores, winnerID: winner?.id)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

// MARK: - Next Game Row
struct NextGameRow: View {
    let game: MultiUserGame
    let gameManager: GameManager
    
    private var difficultyColor: Color {
        switch game.difficultyLevel {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .orange
        }
    }
    
    var body: some View {
        NavigationLink(destination: GamePlayView(game: game).environmentObject(gameManager)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.difficultyText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Text("by \(gameManager.getCreatorName(for: game) ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let progress = gameManager.getUserProgress(for: game.id) {
                    Text("\(progress.completedWordIndices.count)/\(game.wordCount)")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Not started")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Next Games Section View
struct NextGamesSectionView: View {
    let games: [MultiUserGame]
    let gameManager: GameManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Games:")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(games.prefix(5)) { nextGame in
                NextGameRow(game: nextGame, gameManager: gameManager)
            }
        }
    }
}

// MARK: - Back To Games Button
struct BackToGamesButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.left.circle.fill")
                Text("Back to Games")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
}

// MARK: - Finished Game Content View
struct FinishedGameContentView: View {
    let game: MultiUserGame
    let gameManager: GameManager
    let allPlayersFinished: Bool
    let gameWinner: SpellGameUser?
    let nextGames: [MultiUserGame]
    let scores: [ScoreData]
    let onBackToGames: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content area
            ScrollView {
                VStack(spacing: 20) {
                    if !allPlayersFinished {
                        WaitingForPlayersView(game: game, gameManager: gameManager)
                    } else {
                        GameCompleteView(winner: gameWinner, scores: scores)
                    }
                    
                    if !nextGames.isEmpty {
                        NextGamesSectionView(games: nextGames, gameManager: gameManager)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            
            // Fixed back button at bottom
            BackToGamesButton(action: onBackToGames)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(
                    Color(.systemBackground)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                )
        }
    }
}

// MARK: - Main Game Play View
struct GamePlayView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.presentationMode) var presentationMode
    
    let game: MultiUserGame
    
    // MARK: - State Properties
    @State private var currentWordIndex = 0
    @State private var userInput = ""
    @State private var isPlaying = false
    @State private var timerTask: Task<Void, Never>?
    @State private var timeElapsed: Double = 0
    @State private var score = 0
    @State private var showCorrectAnswer = false
    @State private var showWrongAnswer = false
    @State private var isCorrect = false
    @State private var completedWordIndices: [Int] = []
    @State private var correctlySpelledWords: [String] = []
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showStarExplosion = false
    @State private var lastCorrectWord: String = ""
    @State private var lastUserAnswer: String = ""
    @State private var lastPoints: Int = 0
    @State private var isProcessingAnswer = false
    @State private var gameWinner: SpellGameUser? = nil
    @State private var allPlayersFinished = false
    @State private var nextGames: [MultiUserGame] = []
    
    // MARK: - Computed Properties
    private var hasUserFinished: Bool {
        completedWordIndices.count >= game.wordCount
    }
    
    private var currentWord: Word? {
        guard currentWordIndex < game.words.count else { return nil }
        return game.words.indices.contains(currentWordIndex) ? game.words[currentWordIndex] : nil
    }
    
    private var isGameComplete: Bool {
        completedWordIndices.count >= game.wordCount
    }
    
    private var shouldShowKeyboard: Bool {
        !isGameComplete && currentWord != nil && !showCorrectAnswer && !showWrongAnswer
    }
    
    private var sortedScores: [ScoreData] {
        game.participantsIDs.compactMap { participantID in
            guard let user = gameManager.getUser(by: participantID),
                  let progress = gameManager.getUserProgress(for: game.id, userID: participantID) else {
                return nil
            }
            return ScoreData(
                id: participantID,
                userID: participantID,
                displayName: user.displayName,
                score: progress.score
            )
        }.sorted { $0.score > $1.score }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                GameHeaderView(
                    game: game,
                    score: score,
                    correctCount: correctlySpelledWords.count
                )
                
                GameProgressView(
                    completedCount: completedWordIndices.count,
                    totalCount: game.wordCount,
                    correctCount: correctlySpelledWords.count
                )
                
                if hasUserFinished {
                    FinishedGameContentView(
                        game: game,
                        gameManager: gameManager,
                        allPlayersFinished: allPlayersFinished,
                        gameWinner: gameWinner,
                        nextGames: nextGames,
                        scores: sortedScores,
                        onBackToGames: {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                } else if currentWord != nil {
                    ActiveGameContentView(
                        isPlaying: isPlaying,
                        isProcessingAnswer: isProcessingAnswer,
                        timeElapsed: timeElapsed,
                        userInput: $userInput,
                        onPlayWord: {
                            Task { await playWord() }
                        }
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
                
                if shouldShowKeyboard {
                    CustomKeyboardView(
                        text: $userInput,
                        onSubmit: {
                            Task { await checkSpelling() }
                        },
                        isDisabled: isProcessingAnswer
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Answer Overlays
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
            
            ExplodingStarsView(isAnimating: $showStarExplosion)
                .allowsHitTesting(false)
                .zIndex(2)
        }
        .navigationBarBackButtonHidden(false)
        .onAppear(perform: handleViewAppear)
        .onDisappear(perform: handleViewDisappear)
        .task(id: hasUserFinished) {
                // This task automatically cancels when the view disappears
                guard hasUserFinished else { return }
                
                while !Task.isCancelled && !allPlayersFinished {
                    checkIfAllPlayersFinished()
                    
                    if allPlayersFinished {
                        break
                    }
                    
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        .animation(.easeInOut(duration: 0.3), value: shouldShowKeyboard)
    }
    
    // MARK: - View Components
    private var overlayBackground: some View {
        Color.black.opacity(0.4)
            .edgesIgnoringSafeArea(.all)
            .onTapGesture { }
    }
}

// MARK: - GamePlayView Lifecycle Methods
extension GamePlayView {
    private func handleViewAppear() {
        configureAudioSession()
        loadUserProgress()
        loadNextGames()
        if hasUserFinished {
            checkIfAllPlayersFinished()
        }
    }
    
    private func handleViewDisappear() {
        timerTask?.cancel()
        Task {
            await saveUserProgress()
        }
    }
}

// MARK: - GamePlayView Audio Methods
extension GamePlayView {
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func playWord() async {
        guard let word = currentWord, let soundURLString = word.soundURL?.absoluteString else { return }
        
        isPlaying = true
        
        guard let url = URL(string: soundURLString) else {
            isPlaying = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            if timeElapsed == 0 {
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

// MARK: - GamePlayView Timer Methods
extension GamePlayView {
    private func startTimer() {
        timeElapsed = 0
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run {
                    timeElapsed += 0.1
                    if timeElapsed >= 30 {
                        Task { await checkSpelling() }
                    }
                }
            }
        }
    }
}

// MARK: - GamePlayView Progress Methods
extension GamePlayView {
    private func loadUserProgress() {
        if let progress = gameManager.getUserProgress(for: game.id) {
            self.completedWordIndices = progress.completedWordIndices
            self.correctlySpelledWords = progress.correctlySpelledWords
            self.score = progress.score
            self.currentWordIndex = progress.currentWordIndex
            
            if completedWordIndices.contains(currentWordIndex) && !isGameComplete {
                findNextUncompletedWord()
            }
        } else {
            self.currentWordIndex = 0
            self.completedWordIndices = []
            self.correctlySpelledWords = []
            self.score = 0
        }
    }
    
    private func saveUserProgress() async {
        _ = await gameManager.updateUserProgress(
            gameID: game.id,
            wordIndex: currentWordIndex,
            completedWordIndices: completedWordIndices,
            correctlySpelledWords: correctlySpelledWords,
            score: score
        )
        
        if hasUserFinished {
            checkIfAllPlayersFinished()
        }
    }
    
    private func findNextUncompletedWord() {
        for index in 0..<game.wordCount {
            if !completedWordIndices.contains(index) {
                currentWordIndex = index
                return
            }
        }
    }
}

// MARK: - GamePlayView Game Logic Methods
extension GamePlayView {
    private func checkSpelling() async {
        guard let word = currentWord, !isProcessingAnswer else { return }
        
        isProcessingAnswer = true
        timerTask?.cancel()
        
        let userAnswer = userInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        isCorrect = userAnswer == word.word.lowercased()
        
        lastCorrectWord = word.word
        lastUserAnswer = userInput
        
        if isCorrect {
            if !correctlySpelledWords.contains(word.word) {
                correctlySpelledWords.append(word.word)
            }
            lastPoints = calculatePoints()
            score += lastPoints
            showStarExplosion = true
            showCorrectAnswer = true
        } else {
            showWrongAnswer = true
        }
        
        if !completedWordIndices.contains(currentWordIndex) {
            completedWordIndices.append(currentWordIndex)
        }
        
        await saveUserProgress()
    }
    
    private func moveToNextWord() {
        showCorrectAnswer = false
        showWrongAnswer = false
        userInput = ""
        timeElapsed = 0
        audioPlayer = nil
        isProcessingAnswer = false
        
        findNextUncompletedWord()
    }
    
    private func calculatePoints() -> Int {
        let basePoints = 100
        let timePenalty = Int(timeElapsed * 2)
        return max(0, basePoints - timePenalty)
    }
    
    private func checkIfAllPlayersFinished() {
        let allFinished = game.participantsIDs.allSatisfy { participantID in
            let progress = gameManager.getUserProgress(for: game.id, userID: participantID)
            return (progress?.completedWordIndices.count ?? 0) >= game.wordCount
        }
        
        allPlayersFinished = allFinished
        
        if allFinished {
            determineWinner()
        }
    }
    
    private func determineWinner() {
        var highestScore = 0
        var winnerId: String?
        
        for participantID in game.participantsIDs {
            if let progress = gameManager.getUserProgress(for: game.id, userID: participantID) {
                if progress.score > highestScore {
                    highestScore = progress.score
                    winnerId = participantID
                }
            }
        }
        
        if let winnerId = winnerId {
            gameWinner = gameManager.getUser(by: winnerId)
        }
    }
    
    private func loadNextGames() {
        let allGames = gameManager.games.filter { nextGame in
            nextGame.id != game.id &&
            (nextGame.participantsIDs.contains(gameManager.currentUser?.id ?? "") ||
             nextGame.creatorID == gameManager.currentUser?.id)
        }
        
        let startedGames = allGames.filter { nextGame in
            let progress = gameManager.getUserProgress(for: nextGame.id)
            return progress != nil && progress!.completedWordIndices.count > 0
        }
        
        let notStartedGames = allGames.filter { nextGame in
            let progress = gameManager.getUserProgress(for: nextGame.id)
            return progress == nil || progress!.completedWordIndices.count == 0
        }
        
        nextGames = startedGames.sorted { $0.creationDate > $1.creationDate } +
                    notStartedGames.sorted { $0.creationDate > $1.creationDate }
    }
}
