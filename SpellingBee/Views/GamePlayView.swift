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
    
    let colors: [Color] = [.yellow, .orange, .pink, .purple, .blue, .green]
    
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
        
        // Create 20 star particles
        for _ in 0..<20 {
            let particle = StarParticle(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height / 2,
                scale: CGFloat.random(in: 0.3...1.0),
                opacity: 1.0,
                rotation: Double.random(in: 0...360),
                color: colors.randomElement() ?? .yellow
            )
            particles.append(particle)
        }
        
        // Animate particles outward
        withAnimation(.easeOut(duration: 0.8)) {
            for i in particles.indices {
                let angle = Double.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 100...250)
                particles[i].x += cos(angle) * distance
                particles[i].y += sin(angle) * distance
                particles[i].scale *= CGFloat.random(in: 0.5...1.5)
                particles[i].rotation += Double.random(in: 180...720)
            }
        }
        
        // Fade out particles
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            for i in particles.indices {
                particles[i].opacity = 0
            }
        }
        
        // Reset animation state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isAnimating = false
            particles = []
        }
    }
}

// MARK: - Result Popup with Correct Answer
struct ResultPopup: View {
    let isCorrect: Bool
    let points: Int
    let correctWord: String?
    let userAnswer: String?
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(isCorrect ? .green : .red)
            
            Text(isCorrect ? "Correct!" : "Incorrect")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if !isCorrect, let correctWord = correctWord {
                VStack(spacing: 4) {
                    Text("Correct spelling:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(correctWord)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    
                    if let userAnswer = userAnswer, !userAnswer.isEmpty {
                        Text("You typed: \(userAnswer)")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
            
            if isCorrect {
                Text("+\(points) points")
                    .font(.headline)
                    .foregroundColor(.blue)
            } else {
                Text("No points")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Main Game Play View
struct GamePlayView: View {
    @EnvironmentObject var gameManager: GameManager
    let game: MultiUserGame
    @State private var currentWordIndex = 0
    @State private var userInput = ""
    @State private var isPlaying = false
    @State private var timer: Timer?
    @State private var timeElapsed: Double = 0
    @State private var score = 0
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var completedWordIndices: [Int] = []
    @State private var correctlySpelledWords: [String] = []
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showStarExplosion = false
    @State private var lastCorrectWord: String?
    @State private var lastUserAnswer: String?
    @Environment(\.presentationMode) var presentationMode
    
    private var currentWord: Word? {
        game.words.indices.contains(currentWordIndex) ? game.words[currentWordIndex] : nil
    }
    
    private var allWordsCompleted: Bool {
        completedWordIndices.count >= game.wordCount
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Header
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
                        Text("\(correctlySpelledWords.count) correct")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
                
                // Word Progress
                VStack(spacing: 8) {
                    ProgressView(value: Double(completedWordIndices.count), total: Double(game.wordCount))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(y: 1.5)
                        .animation(.easeInOut, value: completedWordIndices.count)
                    
                    HStack {
                        Text("Word \(min(completedWordIndices.count + 1, game.wordCount)) of \(game.wordCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(correctlySpelledWords.count)/\(completedWordIndices.count) correct")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
                
                // Word Card
                if let word = currentWord, !allWordsCompleted {
                    VStack(spacing: 20) {
                        // Play button
                        Button(action: playWord) {
                            VStack(spacing: 12) {
                                Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                
                                Text(isPlaying ? "Playing..." : "Tap to hear word")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .frame(width: 120, height: 120)
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
                        .disabled(isPlaying)
                        
                        // Input field
                        VStack(spacing: 8) {
                            TextField("Type the word you hear", text: $userInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .submitLabel(.done)
                                .onSubmit { checkSpelling() }
                                .disabled(showResult)
                            
                            if timeElapsed > 0 {
                                Text("Time: \(String(format: "%.1f", timeElapsed))s")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // Submit button
                        Button(action: checkSpelling) {
                            Text("Submit Answer")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green, Color.blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .disabled(userInput.isEmpty || showResult)
                        .opacity(userInput.isEmpty || showResult ? 0.6 : 1.0)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .shadow(radius: 5)
                } else if allWordsCompleted {
                    // Game complete - this will auto-dismiss
                    VStack(spacing: 20) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Game Complete!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            Text("Final Score: \(score)")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text("Correctly Spelled: \(correctlySpelledWords.count)/\(game.wordCount)")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        
                        Text("Returning to main screen...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                }
                
                Spacer()
            }
            .padding()
            
            // Result Popup Overlay
            if showResult {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { } // Prevent dismissing by tap
                
                ResultPopup(
                    isCorrect: isCorrect,
                    points: calculatePoints(),
                    correctWord: isCorrect ? nil : lastCorrectWord,
                    userAnswer: isCorrect ? nil : lastUserAnswer
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
            
            // Star Explosion Animation
            ExplodingStarsView(isAnimating: $showStarExplosion)
                .allowsHitTesting(false)
                .zIndex(2)
        }
        .navigationBarBackButtonHidden(false) // Allow back button
        .onAppear {
            configureAudioSession()
            loadUserProgress()
        }
        .onDisappear {
            timer?.invalidate()
            saveUserProgress()
        }
        .onChange(of: allWordsCompleted) { _, completed in
            if completed {
                // Auto-dismiss after 2 seconds when all words are completed
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func loadUserProgress() {
        if let progress = gameManager.getUserProgress(for: game.id) {
            self.completedWordIndices = progress.completedWordIndices
            self.correctlySpelledWords = progress.correctlySpelledWords
            self.score = progress.score
            self.currentWordIndex = progress.currentWordIndex
            
            // If current word is already completed, find next uncompleted word
            if completedWordIndices.contains(currentWordIndex) && !allWordsCompleted {
                findNextUncompletedWord()
            }
        } else {
            self.currentWordIndex = 0
            self.completedWordIndices = []
            self.correctlySpelledWords = []
            self.score = 0
        }
    }
    
    private func saveUserProgress() {
        _ = gameManager.updateUserProgress(
            gameID: game.id,
            wordIndex: currentWordIndex,
            completedWordIndices: completedWordIndices,
            correctlySpelledWords: correctlySpelledWords,
            score: score
        )
    }
    
    private func findNextUncompletedWord() {
        for index in 0..<game.wordCount {
            if !completedWordIndices.contains(index) {
                currentWordIndex = index
                return
            }
        }
    }
    
    private func playWord() {
        guard let word = currentWord, let soundURLString = word.soundURL?.absoluteString else { return }
        
        isPlaying = true
        
        // Download and play the audio
        if let url = URL(string: soundURLString) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        self.isPlaying = false
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    do {
                        self.audioPlayer = try AVAudioPlayer(data: data)
                        self.audioPlayer?.volume = 1.0
                        self.audioPlayer?.prepareToPlay()
                        self.audioPlayer?.play()
                        
                        // Start timer only on first play
                        if self.timeElapsed == 0 {
                            self.startTimer()
                        }
                        
                        // Reset playing state after audio finishes
                        DispatchQueue.main.asyncAfter(deadline: .now() + (self.audioPlayer?.duration ?? 1.0)) {
                            self.isPlaying = false
                        }
                    } catch {
                        print("Error playing audio: \(error)")
                        self.isPlaying = false
                    }
                }
            }.resume()
        }
    }
    
    private func startTimer() {
        timeElapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeElapsed += 0.1
            if timeElapsed >= 30 { // Max 30 seconds per word
                checkSpelling()
            }
        }
    }
    
    private func checkSpelling() {
        guard let word = currentWord, !showResult else { return }
        timer?.invalidate()
        
        let userAnswer = userInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        isCorrect = userAnswer == word.word.lowercased()
        
        // Store for showing in result popup
        lastCorrectWord = word.word
        lastUserAnswer = userInput
        
        if isCorrect && !correctlySpelledWords.contains(word.word) {
            correctlySpelledWords.append(word.word)
            // Trigger star explosion for correct answer
            showStarExplosion = true
            score += calculatePoints()
        }
        
        // Mark word as completed (regardless of correctness)
        if !completedWordIndices.contains(currentWordIndex) {
            completedWordIndices.append(currentWordIndex)
        }
        
        showResult = true
        saveUserProgress()
        
        // Show result briefly, then move to next word
        let displayDuration = isCorrect ? 1.5 : 2.5 // Show wrong answers a bit longer
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
            withAnimation {
                showResult = false
                userInput = ""
                timeElapsed = 0
                audioPlayer = nil
                
                // Move to next word if not all completed
                if !allWordsCompleted {
                    findNextUncompletedWord()
                }
            }
        }
    }
    
    private func calculatePoints() -> Int {
        if !isCorrect { return 0 }
        let basePoints = 100
        let timePenalty = Int(timeElapsed * 2) // 2 points per second
        return max(0, basePoints - timePenalty)
    }
}
