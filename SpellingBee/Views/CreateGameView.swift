import SwiftUI

struct CreateGameView: View {
    @EnvironmentObject var gameManager: GameManager
    @Binding var showCreateGameView: Bool
    @State private var selectedUsers = Set<SpellGameUser>()
    @State private var selectedDifficulty = 2 // Default to medium
    @State private var numberOfWords = 10 // Default word count
    @State private var isCreatingGame = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    
    let wordCountOptions = [5, 10, 15, 20]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Create New Game")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Cancel") {
                        showCreateGameView = false
                    }
                    .foregroundColor(.red)
                    .disabled(isCreatingGame)
                }
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Select Players Section
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Select Players", systemImage: "person.2.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if gameManager.users.filter({ $0.id != gameManager.currentUser?.id }).isEmpty {
                                Text("No other users available")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                List(gameManager.users.filter { $0.id != gameManager.currentUser?.id }, id: \.self, selection: $selectedUsers) { user in
                                    HStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 35, height: 35)
                                            .overlay(
                                                Text(user.initialLetter)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.blue)
                                            )
                                        Text(user.displayName)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .environment(\.editMode, .constant(.active))
                                .frame(minHeight: 200, maxHeight: 300)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            
                            Text("\(selectedUsers.count) player(s) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Difficulty Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Difficulty Level", systemImage: "slider.horizontal.3")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Picker("Difficulty", selection: $selectedDifficulty) {
                                Text("Easy").tag(1)
                                Text("Medium").tag(2)
                                Text("Hard").tag(3)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Text(difficultyDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Number of Words Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Number of Words", systemImage: "text.book.closed")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 15) {
                                ForEach(wordCountOptions, id: \.self) { count in
                                    Button(action: {
                                        numberOfWords = count
                                    }) {
                                        Text("\(count)")
                                            .font(.headline)
                                            .foregroundColor(numberOfWords == count ? .white : .primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                numberOfWords == count ? Color.blue : Color(.systemGray5)
                                            )
                                            .cornerRadius(8)
                                    }
                                    .disabled(isCreatingGame)
                                }
                            }
                            
                            Text("Select how many words players will spell")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Status Message
                        if let statusMessage = statusMessage {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Create Game Button
                Button(action: createGame) {
                    HStack {
                        if isCreatingGame {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Creating Game...")
                        } else {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Game")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(isCreatingGame)
                .opacity(isCreatingGame ? 0.6 : 1.0)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }
    
    private var difficultyDescription: String {
        switch selectedDifficulty {
        case 1:
            return "Simple, common words (3-4 letters)"
        case 2:
            return "Moderate difficulty words (4-5 letters)"
        case 3:
            return "Challenging words (5-6 letters)"
        default:
            return ""
        }
    }
    
    private func createGame() {
        guard let currentUser = gameManager.currentUser else { return }
        
        isCreatingGame = true
        errorMessage = nil
        statusMessage = "Creating game..."
        
        var participantsIDs = selectedUsers.map { $0.id }
        participantsIDs.append(currentUser.id)
        
        print("🎮 Creating game with \(participantsIDs.count) participants, \(numberOfWords) words, difficulty \(selectedDifficulty)")
        
        // Create the game first
        gameManager.createGame(
            creatorID: currentUser.id,
            participantsIDs: Set(participantsIDs),
            difficulty: selectedDifficulty,
            wordCount: numberOfWords
        ) { gameID in
            guard let gameID = gameID else {
                DispatchQueue.main.async {
                    self.isCreatingGame = false
                    self.statusMessage = nil
                    self.errorMessage = "Failed to create game"
                }
                return
            }
            
            print("🎮 Game created with ID: \(gameID), generating words...")
            
            DispatchQueue.main.async {
                self.statusMessage = "Generating words with audio..."
            }
            
            // Generate words for the game
            gameManager.generateWordsForGame(gameID: gameID, wordCount: numberOfWords, difficulty: selectedDifficulty) { result in
                DispatchQueue.main.async {
                    self.isCreatingGame = false
                    self.statusMessage = nil
                    
                    switch result {
                    case .success(let words):
                        print("🎮 Successfully generated \(words.count) words")
                        // Start the game
                        _ = gameManager.startGame(gameID: gameID)
                        self.showCreateGameView = false
                        
                    case .failure(let error):
                        print("❌ Failed to generate words: \(error)")
                        self.errorMessage = "Failed to generate words: \(error.localizedDescription). Please try again."
                    }
                }
            }
        }
    }
}
