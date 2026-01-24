import SwiftUI

struct MainView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var userManager: UserManager
    @State private var showCreateGameView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Spelling Bee")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        
                        Button(action: {
                            // TODO: Add profile/settings action
                        }) {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(gameManager.currentUser?.initialLetter ?? "U")
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                )
                        }
                        
                        Button(action: {
                            userManager.signOut()
                        }) {
                            Image(systemName: "arrow.right.square")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let user = gameManager.currentUser {
                        Text("Welcome back, \(user.displayName)!")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .animation(.easeInOut, value: user.username)
                    }
                    
                    if !gameManager.isDataLoaded {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading your games...")
                                .foregroundColor(.secondary)
                        }
                        .frame(minHeight: 200)
                    } else {
                        Button(action: { showCreateGameView = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Start New Game")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(gradient: Gradient(colors: [.green, .blue]),
                                               startPoint: .leading,
                                               endPoint: .trailing)
                            )
                            .cornerRadius(15)
                            .shadow(radius: 5)
                        }
                        .sheet(isPresented: $showCreateGameView) {
                            CreateGameView(showCreateGameView: $showCreateGameView)
                                .environmentObject(gameManager)
                        }
                        .padding(.horizontal)
                        
                        NavigationLink(destination: SoloModeMenuView()
                            .environmentObject(SoloModeManager())
                            .environmentObject(gameManager)
                        ) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Solo Practice")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Practice at your own pace")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.purple, .blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(radius: 5)
                        }
                        .padding(.horizontal)
                        
                        let userGames = gameManager.games.filter {
                            $0.creatorID == gameManager.currentUser?.id ||
                            $0.participantsIDs.contains(gameManager.currentUser?.id ?? "")
                        }.sorted { game1, game2 in
                            let game1Started = gameManager.hasUserStartedGame(game1)
                            let game2Started = gameManager.hasUserStartedGame(game2)
                            
                            if game1Started && !game2Started {
                                return true
                            } else if !game1Started && game2Started {
                                return false
                            } else {
                                return game1.creationDate > game2.creationDate
                            }
                        }
                        
                        if userGames.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "gamecontroller")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("No games yet")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("Create your first spelling bee game to get started!")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(minHeight: 200)
                            .padding()
                        } else {
                            VStack(spacing: 15) {
                                ForEach(userGames) { game in
                                    GameCardView(gameID: game.id)
                                        .environmentObject(gameManager)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(
                Color(.systemBackground)
                    .overlay(
                        Image("SpellingBee")
                            .resizable()
                            .scaledToFit()
                            .opacity(0.05)
                    )
            )
            .navigationBarHidden(true)
            .refreshable {
                await gameManager.loadData()
            }
        }
    }
}
