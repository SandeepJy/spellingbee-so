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
    @Published var unlockedAchievements: [Achievement] = []
    
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
    
    func createSession(userID: String, level: Int, wordCount: Int = 10) async throws -> SoloSession {
        guard soloProgress != nil else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Progress not loaded"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        var session = SoloSession(userID: userID, level: level, wordCount: wordCount)
        
        let wordsData: [WordWithDetails]
        
        if level <= 10 {
            let wordLength = SoloSession.calculateDifficulty(for: level)
            wordsData = try await WordAPIService.shared.fetchRandomWordsWithDetails(
                count: wordCount,
                length: wordLength
            )
        } else {
            guard let user = Auth.auth().currentUser else {
                throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            let token = try await user.getIDToken()
            wordsData = try await WordAPIService.shared.fetchHardWordsWithDetails(
                count: wordCount,
                userToken: token
            )
        }
        
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
    
    func completeSession() async {
        guard var session = currentSession, var progress = soloProgress else { return }
        
        session.endDate = Date()
        
        // Update progress stats
        progress.totalWordsSpelled += session.wordCount
        progress.totalCorrectWords += session.correctWords.count
        progress.totalIncorrectWords += session.misspelledWords.count
        progress.totalHintsUsed += session.hintsUsed
        
        // Recalculate average accuracy
        if progress.totalWordsSpelled > 0 {
            progress.averageAccuracy = Double(progress.totalCorrectWords) / Double(progress.totalWordsSpelled) * 100
        }
        
        // Award XP
        let xpEarned = calculateSessionXP(session: session)
        session.totalXPEarned = xpEarned
        await addXP(xpEarned)
        
        // Update level history
        updateLevelHistory(session: session)
        
        // Check achievements
        await checkAchievements(session: session)
        
        // Update session
        currentSession = session
        await updateSession(session)
        
        // Save progress
        soloProgress = progress
        await saveProgress()
    }
    
    // MARK: - XP and Leveling
    
    func addXP(_ amount: Int) async {
        guard var progress = soloProgress else { return }
        
        progress.xp += amount
        
        while progress.xp >= progress.xpToNextLevel {
            progress.xp -= progress.xpToNextLevel
            progress.level += 1
            progress.xpToNextLevel = calculateXPForNextLevel(progress.level)
            
            await checkLevelAchievement(level: progress.level)
        }
        
        soloProgress = progress
        await saveProgress()
    }
    
    private func calculateXPForNextLevel(_ level: Int) -> Int {
        return Int(100 * pow(1.2, Double(level - 1)))
    }
    
    private func calculateSessionXP(session: SoloSession) -> Int {
        var xp = 0
        
        xp += session.correctWords.count * 10
        
        if session.accuracy >= 100 {
            xp += 50
        } else if session.accuracy >= 90 {
            xp += 30
        } else if session.accuracy >= 80 {
            xp += 15
        }
        
        if session.hintsUsed == 0 {
            xp += 20
        }
        
        if session.sessionStats.longestPerfectStreak >= 5 {
            xp += session.sessionStats.longestPerfectStreak * 2
        }
        
        xp = Int(Double(xp) * (1.0 + Double(session.level) * 0.1))
        
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
        
        Task {
            await saveProgress()
            await checkStreakAchievements()
        }
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
                
                Task {
                    await saveProgress()
                }
            }
        } else {
            progress.availableHints = 5
            progress.lastHintResetDate = Date()
            soloProgress = progress
            
            Task {
                await saveProgress()
            }
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
        
        if progress.totalCorrectWords == 1 && !progress.achievements.contains("first_word") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "first_word" }) {
                newAchievements.append(achievement)
            }
        }
        
        if session.sessionStats.longestPerfectStreak >= 10 && !progress.achievements.contains("perfect_10") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "perfect_10" }) {
                newAchievements.append(achievement)
            }
        }
        
        if session.sessionStats.fastestWordTime < 5.0 && session.correctWords.count >= 5 && !progress.achievements.contains("speed_demon") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "speed_demon" }) {
                newAchievements.append(achievement)
            }
        }
        
        if progress.totalCorrectWords >= 100 && !progress.achievements.contains("century") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "century" }) {
                newAchievements.append(achievement)
            }
        }
        
        if session.hintsUsed == 0 && session.correctWords.count >= 5 && !progress.achievements.contains("no_hints") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "no_hints" }) {
                newAchievements.append(achievement)
            }
        }
        
        if progress.totalWordsSpelled >= 50 && progress.accuracyPercentage >= 80 && !progress.achievements.contains("accuracy_80") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "accuracy_80" }) {
                newAchievements.append(achievement)
            }
        }
        
        if progress.totalWordsSpelled >= 100 && progress.accuracyPercentage >= 95 && !progress.achievements.contains("accuracy_95") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "accuracy_95" }) {
                newAchievements.append(achievement)
            }
        }
        
        await unlockAchievements(newAchievements)
    }
    
    private func checkStreakAchievements() async {
        guard let progress = soloProgress else { return }
        
        var newAchievements: [Achievement] = []
        
        if progress.currentStreak >= 3 && !progress.achievements.contains("streak_3") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "streak_3" }) {
                newAchievements.append(achievement)
            }
        }
        
        if progress.currentStreak >= 7 && !progress.achievements.contains("streak_7") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "streak_7" }) {
                newAchievements.append(achievement)
            }
        }
        
        if progress.currentStreak >= 30 && !progress.achievements.contains("streak_30") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "streak_30" }) {
                newAchievements.append(achievement)
            }
        }
        
        await unlockAchievements(newAchievements)
    }
    
    private func checkLevelAchievement(level: Int) async {
        guard let progress = soloProgress else { return }
        
        var newAchievements: [Achievement] = []
        
        if level >= 5 && !progress.achievements.contains("level_5") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "level_5" }) {
                newAchievements.append(achievement)
            }
        }
        
        if level >= 10 && !progress.achievements.contains("level_10") {
            if let achievement = Achievement.allAchievements.first(where: { $0.id == "level_10" }) {
                newAchievements.append(achievement)
            }
        }
        
        await unlockAchievements(newAchievements)
    }
    
    private func unlockAchievements(_ achievements: [Achievement]) async {
        guard var progress = soloProgress, !achievements.isEmpty else { return }
        
        for achievement in achievements {
            if !progress.achievements.contains(achievement.id) {
                progress.achievements.append(achievement.id)
                await addXP(achievement.xpReward)
            }
        }
        
        unlockedAchievements = achievements
        
        soloProgress = progress
        await saveProgress()
    }
    
    // MARK: - Level History
    
    private func updateLevelHistory(session: SoloSession) {
        guard var progress = soloProgress else { return }
        
        if let index = progress.levelHistory.firstIndex(where: { $0.level == session.level }) {
            var stats = progress.levelHistory[index]
            stats.attempts += 1
            stats.correctWords += session.correctWords.count
            stats.totalWords += session.wordCount
            
            let sessionAccuracy = session.accuracy
            if sessionAccuracy > stats.bestAccuracy {
                stats.bestAccuracy = sessionAccuracy
            }
            
            let totalTime = stats.averageTime * Double(stats.attempts - 1)
            let sessionAvgTime = session.sessionStats.averageWordTime
            stats.averageTime = (totalTime + sessionAvgTime) / Double(stats.attempts)
            
            progress.levelHistory[index] = stats
        } else {
            let newStats = LevelStats(
                level: session.level,
                attempts: 1,
                correctWords: session.correctWords.count,
                totalWords: session.wordCount,
                averageTime: session.sessionStats.averageWordTime,
                bestAccuracy: session.accuracy
            )
            progress.levelHistory.append(newStats)
        }
        
        soloProgress = progress
    }
}
