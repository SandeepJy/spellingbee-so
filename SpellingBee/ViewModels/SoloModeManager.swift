import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SoloModeManager: ObservableObject {
    @Published var soloProgress: SoloProgress?
    @Published var currentSession: SoloSession?
    @Published var isLoading = false
    @Published var loadingMessage = "Loading..."
    @Published var unlockedAchievements: [Achievement] = []
    @Published var errorMessage: String?
    
    private let soloService = SoloModeService()
    private var progressListener: ListenerRegistration?
    
    init() {}
    
    // MARK: - Progress Management
    
    func loadProgress(for userID: String) async {
        do {
            self.soloProgress = try await soloService.loadSoloProgress(for: userID)
            resetDailyHintsIfNeeded()
            updateStreak()
        } catch {
            print("Error loading solo progress: \(error)")
        }
    }
    
    func setupRealtimeListener(for userID: String) {
        progressListener = soloService.soloProgressListener(userID: userID) { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.soloProgress = progress
            }
        }
    }
    
    func removeListener() {
        progressListener?.remove()
        progressListener = nil
    }
    
    private func saveProgress() async {
        guard let progress = soloProgress else { return }
        do {
            try soloService.saveSoloProgress(progress)
        } catch {
            print("Error saving solo progress: \(error)")
        }
    }
    
    // MARK: - Session Management
    
    func createSession(userID: String, level: Int) async throws -> SoloSession {
        guard soloProgress != nil else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Progress not loaded"])
        }
        
        isLoading = true
        loadingMessage = "Preparing Level \(level)..."
        errorMessage = nil
        defer { isLoading = false }
        
        let config = SoloLevelConfig.config(for: level)
        
        var session = SoloSession(
            userID: userID,
            level: level,
            requiredStreak: config.requiredStreak,
            timeLimit: config.timeLimit
        )
        
        // Get user token for Firebase API
        var userToken: String?
        if case .firebaseAPI = config.wordSource {
            guard let user = Auth.auth().currentUser else {
                throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            userToken = try await user.getIDToken()
        }
        
        loadingMessage = "Fetching words..."
        
        let wordsData = try await WordAPIService.shared.fetchWordsForSoloLevel(
            config: config,
            userToken: userToken
        )
        
        session.words = wordsData.map { wordData in
            Word(
                word: wordData.word,
                soundURL: wordData.audioURL != nil ? URL(string: wordData.audioURL!) : nil,
                level: level,
                definition: wordData.definition,
                exampleSentence: wordData.exampleSentence,
                createdByID: "system",
                gameID: nil
            )
        }
        
        currentSession = session
        return session
    }
    
    func updateSession(_ session: SoloSession) async {
        currentSession = session
        do {
            try soloService.saveSession(session)
        } catch {
            print("Error saving session: \(error)")
        }
    }
    
    func recordCorrectWord(word: String) async {
        guard var session = currentSession else { return }
        
        session.currentStreak += 1
        session.correctWords.append(word)
        session.totalWordsAttempted += 1
        session.currentWordIndex += 1
        
        if session.currentStreak >= session.requiredStreak {
            session.isCompleted = true
            session.endDate = Date()
        }
        
        currentSession = session
        await updateSession(session)
    }
    
    func recordIncorrectWord(correctWord: String, userAnswer: String) async {
        guard var session = currentSession else { return }
        
        let misspelled = MisspelledWord(
            correctWord: correctWord,
            userAnswer: userAnswer,
            wordIndex: session.currentWordIndex
        )
        session.misspelledWords.append(misspelled)
        session.currentStreak = 0 // Reset streak
        session.totalWordsAttempted += 1
        session.currentWordIndex += 1
        
        currentSession = session
        await updateSession(session)
    }
    
    func recordTimeout(correctWord: String) async {
        await recordIncorrectWord(correctWord: correctWord, userAnswer: "(timed out)")
    }
    
    func completeSession() async {
        guard var session = currentSession, var progress = soloProgress else { return }
        
        session.endDate = Date()
        session.isCompleted = true
        
        // Update progress stats
        progress.totalWordsSpelled += session.totalWordsAttempted
        progress.totalCorrectWords += session.correctWords.count
        progress.totalIncorrectWords += session.misspelledWords.count
        progress.totalHintsUsed += session.hintsUsed
        
        if progress.totalWordsSpelled > 0 {
            progress.averageAccuracy = Double(progress.totalCorrectWords) / Double(progress.totalWordsSpelled) * 100
        }
        
        // Level up if completed
        if session.isLevelComplete && session.level >= progress.level {
            progress.level = min(session.level + 1, 20)
        }
        
        // Award XP
        let xpEarned = calculateSessionXP(session: session)
        session.totalXPEarned = xpEarned
        progress.xp += xpEarned
        
        // Level up XP
        while progress.xp >= progress.xpToNextLevel {
            progress.xp -= progress.xpToNextLevel
            progress.xpToNextLevel = calculateXPForNextLevel(progress.level)
        }
        
        // Update session and progress
        currentSession = session
        soloProgress = progress
        await updateSession(session)
        await saveProgress()
        
        // Check achievements
        await checkAchievements(session: session)
    }
    
    // MARK: - XP Calculations
    
    private func calculateXPForNextLevel(_ level: Int) -> Int {
        return Int(100 * pow(1.2, Double(level - 1)))
    }
    
    private func calculateSessionXP(session: SoloSession) -> Int {
        var xp = 0
        
        // Base XP per correct word
        xp += session.correctWords.count * 10
        
        // Completion bonus
        if session.isLevelComplete {
            xp += 50
            
            // Perfect run bonus (no mistakes at all)
            if session.misspelledWords.isEmpty {
                xp += 30
            }
        }
        
        // No hints bonus
        if session.hintsUsed == 0 && session.correctWords.count >= 3 {
            xp += 20
        }
        
        // Speed bonus
        if session.sessionStats.averageWordTime < 3.0 && session.correctWords.count >= 3 {
            xp += 15
        }
        
        // Level multiplier
        xp = Int(Double(xp) * (1.0 + Double(session.level) * 0.05))
        
        return xp
    }
    
    // MARK: - Streak Management
    
    private func updateStreak() {
        guard var progress = soloProgress else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastPlayed = progress.lastPlayedDate {
            let lastPlayedDay = calendar.startOfDay(for: lastPlayed)
            let daysDifference = calendar.dateComponents([.day], from: lastPlayedDay, to: today).day ?? 0
            
            if daysDifference == 0 {
                return
            } else if daysDifference == 1 {
                progress.currentStreak += 1
                if progress.currentStreak > progress.longestStreak {
                    progress.longestStreak = progress.currentStreak
                }
            } else {
                progress.currentStreak = 1
            }
        } else {
            progress.currentStreak = 1
            progress.longestStreak = 1
        }
        
        progress.lastPlayedDate = Date()
        soloProgress = progress
        
        Task { await saveProgress() }
    }
    
    // MARK: - Hints
    
    private func resetDailyHintsIfNeeded() {
        guard var progress = soloProgress else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastReset = progress.lastHintResetDate {
            let lastResetDay = calendar.startOfDay(for: lastReset)
            if !calendar.isDate(lastResetDay, inSameDayAs: today) {
                progress.availableHints = 5
                progress.lastHintResetDate = Date()
                soloProgress = progress
                Task { await saveProgress() }
            }
        } else {
            progress.availableHints = 5
            progress.lastHintResetDate = Date()
            soloProgress = progress
            Task { await saveProgress() }
        }
    }
    
    func useHint() async -> Bool {
        guard var progress = soloProgress else { return false }
        if progress.availableHints > 0 {
            progress.availableHints -= 1
            soloProgress = progress
            await saveProgress()
            return true
        }
        return false
    }
    
    // MARK: - Achievements
    
    private func checkAchievements(session: SoloSession) async {
        guard let progress = soloProgress else { return }
        var newAchievements: [Achievement] = []
        
        if progress.totalCorrectWords >= 1 && !progress.achievements.contains("first_word") {
            if let a = Achievement.allAchievements.first(where: { $0.id == "first_word" }) {
                newAchievements.append(a)
            }
        }
        
        if session.sessionStats.longestStreak >= 10 && !progress.achievements.contains("perfect_10") {
            if let a = Achievement.allAchievements.first(where: { $0.id == "perfect_10" }) {
                newAchievements.append(a)
            }
        }
        
        if progress.totalCorrectWords >= 100 && !progress.achievements.contains("century") {
            if let a = Achievement.allAchievements.first(where: { $0.id == "century" }) {
                newAchievements.append(a)
            }
        }
        
        if session.hintsUsed == 0 && session.correctWords.count >= 5 && !progress.achievements.contains("no_hints") {
            if let a = Achievement.allAchievements.first(where: { $0.id == "no_hints" }) {
                newAchievements.append(a)
            }
        }
        
        if progress.level >= 5 && !progress.achievements.contains("level_5") {
            if let a = Achievement.allAchievements.first(where: { $0.id == "level_5" }) {
                newAchievements.append(a)
            }
        }
        
        if progress.level >= 10 && !progress.achievements.contains("level_10") {
            if let a = Achievement.allAchievements.first(where: { $0.id == "level_10" }) {
                newAchievements.append(a)
            }
        }
        
        await unlockAchievements(newAchievements)
    }
    
    private func unlockAchievements(_ achievements: [Achievement]) async {
        guard var progress = soloProgress, !achievements.isEmpty else { return }
        
        for achievement in achievements {
            if !progress.achievements.contains(achievement.id) {
                progress.achievements.append(achievement.id)
                progress.xp += achievement.xpReward
            }
        }
        
        unlockedAchievements = achievements
        soloProgress = progress
        await saveProgress()
    }
}
