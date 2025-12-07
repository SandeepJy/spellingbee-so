import SwiftUI

import AVFoundation

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
    @Environment(\.presentationMode) var presentationMode
    
    private var currentWord: Word? {
        game.words.indices.contains(currentWordIndex) ? game.words[currentWordIndex] : nil
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spell the Words")
                            .font(.system(size: 28, weight: .bold))
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
                
                // Progress
                VStack(spacing: 8) {
                    ProgressView(value: Double(completedWordIndices.count), total: Double(game.wordCount))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(y: 1.5)
                        .animation(.easeInOut, value: completedWordIndices.count)
                    
                    HStack {
                        Text("Word \(completedWordIndices.count + 1) of \(game.wordCount)")
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
                VStack(spacing: 25) {
                    if let word = currentWord {
                        // Play button
                        Button(action: playWord) {
                            VStack(spacing: 12) {
                                Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                                
                                Text(isPlaying ? "Playing..." : "Tap to hear word")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .frame(width: 140, height: 140)
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
                            
                            if timeElapsed > 0 {
                                Text("Time: \(String(format: "%.1f", timeElapsed))s")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                    } else if completedWordIndices.count == game.wordCount {
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
                            }
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
                
                // Result Popup
                if showResult {
                    ResultPopup(isCorrect: isCorrect, points: calculatePoints())
                        .transition(.scale)
                }
                
                Spacer()
                
                // Action Buttons
                if currentWord != nil {
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
                    .disabled(userInput.isEmpty)
                    .opacity(userInput.isEmpty ? 0.6 : 1.0)
                } else if completedWordIndices.count == game.wordCount {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Finish Game")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            configureAudioSession()
            loadUserProgress()
        }
        .onDisappear {
            timer?.invalidate()
            saveUserProgress()
        }
        .navigationBarBackButtonHidden(completedWordIndices.count < game.wordCount)
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
            self.currentWordIndex = progress.currentWordIndex
            self.completedWordIndices = progress.completedWordIndices
            self.correctlySpelledWords = progress.correctlySpelledWords
            self.score = progress.score
            
            if completedWordIndices.count < game.wordCount {
                if completedWordIndices.contains(currentWordIndex) {
                    findNextUncompletedWord()
                }
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
                        self.audioPlayer?.volume = 1.0 // Set maximum volume
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
        guard let word = currentWord else { return }
        timer?.invalidate()
        
        let userAnswer = userInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        isCorrect = userAnswer == word.word.lowercased()
        
        if isCorrect && !correctlySpelledWords.contains(word.word) {
            correctlySpelledWords.append(word.word)
        }
        
        if !completedWordIndices.contains(currentWordIndex) {
            completedWordIndices.append(currentWordIndex)
        }
        
        score += calculatePoints()
        showResult = true
        
        saveUserProgress()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showResult = false
                userInput = ""
                timeElapsed = 0
                audioPlayer = nil
                
                if completedWordIndices.count < game.wordCount {
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
// Result Popup
struct ResultPopup: View {
    let isCorrect: Bool
    let points: Int
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(isCorrect ? .green : .red)
            
            Text(isCorrect ? "Correct!" : "Wrong!")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("+\(points) points")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
    }
}
