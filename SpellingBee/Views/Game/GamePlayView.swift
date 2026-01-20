import SwiftUI
import AVFoundation


// MARK: - Word Review Data Model
struct WordReviewData: Identifiable {
    let id: UUID
    let word: String
    let wasCorrect: Bool
    let userAnswer: String?
    let definition: String?
    let exampleSentence: String?
    let soundURL: URL?
    
    init(word: Word, wasCorrect: Bool, userAnswer: String? = nil) {
        self.id = word.id
        self.word = word.word
        self.wasCorrect = wasCorrect
        self.userAnswer = userAnswer
        self.soundURL = word.soundURL
        self.definition = word.definition
        self.exampleSentence = word.exampleSentence
    }
}

// MARK: - Word Detail Sheet
struct WordDetailSheet: View {
    let wordData: WordReviewData
    @Environment(\.dismiss) var dismiss
    @State private var isPlayingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isLoadingDetails = false
    @State private var fetchedDefinition: String?
    @State private var fetchedExample: String?
    
    private var displayDefinition: String {
        fetchedDefinition ?? wordData.definition ?? "Definition not available"
    }
    
    private var displayExample: String {
        fetchedExample ?? wordData.exampleSentence ?? "No example sentence available"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Word header
                    VStack(spacing: 12) {
                        Text(wordData.word)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: wordData.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(wordData.wasCorrect ? .green : .red)
                            Text(wordData.wasCorrect ? "Spelled Correctly" : "Spelled Incorrectly")
                                .font(.subheadline)
                                .foregroundColor(wordData.wasCorrect ? .green : .red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(wordData.wasCorrect ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        )
                        
                        if !wordData.wasCorrect, let userAnswer = wordData.userAnswer, !userAnswer.isEmpty {
                            Text("You typed: \"\(userAnswer)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    Divider()
                    
                    // Play pronunciation button
                    Button(action: {
                        Task {
                            await playPronunciation()
                        }
                    }) {
                        HStack {
                            Image(systemName: isPlayingAudio ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                //.symbolEffect(.bounce, value: isPlayingAudio)
                            Text(isPlayingAudio ? "Playing..." : "Play Pronunciation")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isPlayingAudio || wordData.soundURL == nil)
                    .opacity(wordData.soundURL == nil ? 0.5 : 1.0)
                    
                    // Definition section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Definition", systemImage: "book.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        if isLoadingDetails && wordData.definition == nil {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            Text(displayDefinition)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    
                    // Example sentence section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Example Sentence", systemImage: "text.quote")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        if isLoadingDetails && wordData.exampleSentence == nil {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            Text(displayExample)
                                .font(.body)
                                .italic()
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadWordDetailsIfNeeded()
            }
        }
    }
    
    private func loadWordDetailsIfNeeded() async {
        // Only fetch if we don't have the data
        guard wordData.definition == nil || wordData.exampleSentence == nil else { return }
        
        isLoadingDetails = true
        
        if let details = await WordAPIService.shared.fetchSingleWordDetails(word: wordData.word) {
            fetchedDefinition = details.definition
            fetchedExample = details.exampleSentence
        }
        
        isLoadingDetails = false
    }
    
    private func playPronunciation() async {
        guard let soundURL = wordData.soundURL else { return }
        
        isPlayingAudio = true
        
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
        
        isPlayingAudio = false
    }
}

// MARK: - Word Review Row
struct WordReviewRow: View {
    let wordData: WordReviewData
    let index: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Index number with status color
                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(wordData.wasCorrect ? Color.green : Color.red))
                
                // Word
                VStack(alignment: .leading, spacing: 2) {
                    Text(wordData.word)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !wordData.wasCorrect, let userAnswer = wordData.userAnswer, !userAnswer.isEmpty {
                        Text("You typed: \(userAnswer)")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Status icon and chevron
                HStack(spacing: 8) {
                    Image(systemName: wordData.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(wordData.wasCorrect ? .green : .red)
                        .font(.title3)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(wordData.wasCorrect ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Review Summary Header
struct ReviewSummaryHeader: View {
    let correctCount: Int
    let incorrectCount: Int
    let totalCount: Int
    
    private var accuracyPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int(Double(correctCount) / Double(totalCount) * 100)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Score circles
            HStack(spacing: 30) {
                ScoreCircle(value: correctCount, label: "Correct", color: .green)
                ScoreCircle(value: incorrectCount, label: "Incorrect", color: .red)
                ScoreCircle(value: totalCount, label: "Total", color: .blue)
            }
            
            // Accuracy bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        if correctCount > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green)
                                .frame(width: geometry.size.width * CGFloat(correctCount) / CGFloat(totalCount))
                        }
                        if incorrectCount > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: geometry.size.width * CGFloat(incorrectCount) / CGFloat(totalCount))
                        }
                    }
                }
                .frame(height: 10)
                .background(Color(.systemGray5))
                .cornerRadius(5)
                
                Text("\(accuracyPercentage)% Accuracy")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Score Circle
struct ScoreCircle: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Review Game Button
struct ReviewGameButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                Text("Review Your Words")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.purple.opacity(0.3), radius: 5, x: 0, y: 3)
        }
    }
}


// MARK: - Active Game Content View
struct ActiveGameContentView: View {
    let isPlaying: Bool
    let isProcessingAnswer: Bool
    let timeElapsed: Double
    let showDefinition: Bool
    let definition: String?
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
                
                // Definition hint after 5 seconds
                if showDefinition, let definition = definition {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Hint")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(definition)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.yellow.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .shadow(radius: 5)
        .animation(.easeInOut(duration: 0.3), value: showDefinition)
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
    let onReviewTap: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                //.symbolEffect(.pulse)
            
            Text("You've finished!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Waiting for other players...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ReviewGameButton(action: onReviewTap)
                .padding(.horizontal)
            
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
                    if scoreData.userID == winnerID {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                    
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
    let onReviewTap: () -> Void
    
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
            
            ReviewGameButton(action: onReviewTap)
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
    let correctlySpelledWords: [String]
    let misspelledWords: [MisspelledWord]
    let onBackToGames: () -> Void
    
    @State private var showReviewSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content area
            ScrollView {
                VStack(spacing: 20) {
                    if !allPlayersFinished {
                        WaitingForPlayersView(
                            game: game,
                            gameManager: gameManager,
                            onReviewTap: { showReviewSheet = true }
                        )
                    } else {
                        GameCompleteView(
                            winner: gameWinner,
                            scores: scores,
                            onReviewTap: { showReviewSheet = true }
                        )
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
        .sheet(isPresented: $showReviewSheet) {
            GameReviewView(
                game: game,
                correctlySpelledWords: correctlySpelledWords,
                misspelledWords: misspelledWords
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
    @State private var definitionTask: Task<Void, Never>?
    @State private var timeElapsed: Double = 0
    @State private var score = 0
    @State private var showCorrectAnswer = false
    @State private var showWrongAnswer = false
    @State private var isCorrect = false
    @State private var completedWordIndices: [Int] = []
    @State private var correctlySpelledWords: [String] = []
    @State private var misspelledWords: [MisspelledWord] = []
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showStarExplosion = false
    @State private var lastCorrectWord: String = ""
    @State private var lastUserAnswer: String = ""
    @State private var lastPoints: Int = 0
    @State private var isProcessingAnswer = false
    @State private var gameWinner: SpellGameUser? = nil
    @State private var allPlayersFinished = false
    @State private var nextGames: [MultiUserGame] = []
    @State private var showDefinition = false
    
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
                        correctlySpelledWords: correctlySpelledWords,
                        misspelledWords: misspelledWords,
                        onBackToGames: {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                } else if currentWord != nil {
                    ActiveGameContentView(
                        isPlaying: isPlaying,
                        isProcessingAnswer: isProcessingAnswer,
                        timeElapsed: timeElapsed,
                        showDefinition: showDefinition,
                        definition: currentWord?.definition,
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
    }
    
    private func handleViewDisappear() {
        timerTask?.cancel()
        definitionTask?.cancel()
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
            
            // Wait for the audio to finish playing
            if let duration = audioPlayer?.duration {
                try await Task.sleep(for: .seconds(duration))
            }
            
            isPlaying = false
            
            // Start the timer AFTER the word has been fully played
            if timeElapsed == 0 {
                startTimer()
                startDefinitionTimer()
            }
            
        } catch {
            print("Error playing audio: \(error)")
            isPlaying = false
        }
    }
    
    private func startDefinitionTimer() {
        definitionTask?.cancel()
        showDefinition = false
        
        definitionTask = Task {
            do {
                try await Task.sleep(for: .seconds(5))
                await MainActor.run {
                    if !isProcessingAnswer && !showCorrectAnswer && !showWrongAnswer {
                        withAnimation {
                            showDefinition = true
                        }
                    }
                }
            } catch {
                // Task was cancelled
            }
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
            self.misspelledWords = progress.misspelledWords
            self.score = progress.score
            self.currentWordIndex = progress.currentWordIndex
            
            if completedWordIndices.contains(currentWordIndex) && !isGameComplete {
                findNextUncompletedWord()
            }
        } else {
            self.currentWordIndex = 0
            self.completedWordIndices = []
            self.correctlySpelledWords = []
            self.misspelledWords = []
            self.score = 0
        }
    }
    
    private func saveUserProgress() async {
        _ = await gameManager.updateUserProgress(
            gameID: game.id,
            wordIndex: currentWordIndex,
            completedWordIndices: completedWordIndices,
            correctlySpelledWords: correctlySpelledWords,
            misspelledWords: misspelledWords,
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
            // Add to misspelled words
            let misspelled = MisspelledWord(
                correctWord: word.word,
                userAnswer: userInput,
                wordIndex: currentWordIndex
            )
            if !misspelledWords.contains(where: { $0.correctWord == word.word }) {
                misspelledWords.append(misspelled)
            }
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
        showDefinition = false
        userInput = ""
        timeElapsed = 0
        audioPlayer = nil
        isProcessingAnswer = false
        definitionTask?.cancel()
        
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
