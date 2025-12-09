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
        .onChange(of: isAnimating) {newValue in
            if newValue {
                createExplosion()
            }
        }
    }
    
    private func createExplosion() {
        particles = []
        
        // Create 25 star particles
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
        
        // Animate particles outward
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
        
        // Fade out particles
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            for i in particles.indices {
                particles[i].opacity = 0
            }
        }
        
        // Reset animation state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            isAnimating = false
            particles = []
        }
    }
}

// MARK: - Correct Spelling Overlay
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
            
            // Auto dismiss after delay
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

// MARK: - Correct Answer Celebration
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
            
            // Auto dismiss after delay
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
    @Environment(\.presentationMode) var presentationMode
    
    private var currentWord: Word? {
        guard currentWordIndex < game.words.count else { return nil }
        return game.words.indices.contains(currentWordIndex) ? game.words[currentWordIndex] : nil
    }
    
    private var isGameComplete: Bool {
        return completedWordIndices.count >= game.wordCount
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
                        Text("\(correctlySpelledWords.count)/\(game.wordCount) correct")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
                
                // Word Card
                VStack(spacing: 20) {
                    if !isGameComplete, let word = currentWord {
                        // Play button
                        Button(action: playWord) {
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
                        .disabled(isPlaying || isProcessingAnswer)
                        
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
                                .disabled(isProcessingAnswer)
                            
                            if timeElapsed > 0 {
                                Text("Time: \(String(format: "%.1f", timeElapsed))s")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                    } else if isGameComplete {
                        // Game complete
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
                                
                                let bestPossible = game.wordCount * 90
                                let percentage = bestPossible > 0 ? (Double(score) / Double(bestPossible)) * 100 : 0
                                Text("Score Efficiency: \(String(format: "%.1f", percentage))%")
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                            }
                            
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "house.fill")
                                    Text("Back to Games")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .padding(.top, 10)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(15)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
                .shadow(radius: 5)
                
                Spacer()
                
                // Action Buttons
                if !isGameComplete && currentWord != nil {
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
                    .disabled(userInput.isEmpty || isProcessingAnswer)
                    .opacity((userInput.isEmpty || isProcessingAnswer) ? 0.6 : 1.0)
                }
            }
            .padding()
            
            // Overlays
            if showWrongAnswer {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { }
                
                CorrectSpellingOverlay(
                    correctWord: lastCorrectWord,
                    userAnswer: lastUserAnswer,
                    onDismiss: {
                        moveToNextWord()
                    }
                )
                .zIndex(1)
            }
            
            if showCorrectAnswer {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { }
                
                CorrectAnswerOverlay(
                    points: lastPoints,
                    onDismiss: {
                        moveToNextWord()
                    }
                )
                .zIndex(1)
            }
            
            // Star Explosion Animation
            ExplodingStarsView(isAnimating: $showStarExplosion)
                .allowsHitTesting(false)
                .zIndex(2)
        }
        .navigationBarBackButtonHidden(false)
        .onAppear {
            configureAudioSession()
            loadUserProgress()
        }
        .onDisappear {
            timer?.invalidate()
            saveUserProgress()
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
            
            // Find next uncompleted word if current is already done
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
    
    private func saveUserProgress() {
        Task {
            _ = await gameManager.updateUserProgress(
                gameID: game.id,
                wordIndex: currentWordIndex,
                completedWordIndices: completedWordIndices,
                correctlySpelledWords: correctlySpelledWords,
                score: score
            )
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
    
    private func playWord() {
        guard let word = currentWord, let soundURLString = word.soundURL?.absoluteString else { return }
        
        isPlaying = true
        
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
                        
                        // Start timer only on first play for this word
                        if self.timeElapsed == 0 {
                            self.startTimer()
                        }
                        
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
            if timeElapsed >= 30 {
                checkSpelling()
            }
        }
    }
    
    private func checkSpelling() {
        guard let word = currentWord, !isProcessingAnswer else { return }
        
        isProcessingAnswer = true
        timer?.invalidate()
        
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
        
        saveUserProgress()
    }
    
    private func moveToNextWord() {
        showCorrectAnswer = false
        showWrongAnswer = false
        userInput = ""
        timeElapsed = 0
        audioPlayer = nil
        isProcessingAnswer = false
        
        // Check if game is complete
        if completedWordIndices.count >= game.wordCount {
            // Game complete - will show completion screen
            // Auto-navigate back after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            // Find next word
            findNextUncompletedWord()
        }
    }
    
    private func calculatePoints() -> Int {
        let basePoints = 100
        let timePenalty = Int(timeElapsed * 2)
        return max(0, basePoints - timePenalty)
    }
}
