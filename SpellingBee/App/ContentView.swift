import SwiftUI

struct ContentView: View {
    @StateObject private var userManager = UserManager()
    @StateObject private var gameManager = GameManager()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            Group {
                if userManager.isAuthenticated && gameManager.currentUser != nil {
                    MainView()
                        .environmentObject(userManager)
                        .environmentObject(gameManager)
                        .transition(.opacity)
                } else {
                    LoginRegisterView()
                        .environmentObject(userManager)
                        .environmentObject(gameManager)
                        .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(colorScheme)
        .animation(.easeInOut(duration: 0.3), value: userManager.isAuthenticated)
        .onAppear {
            gameManager.setUserManager(userManager)
        }
    }
}

#Preview {
    ContentView()
}
