
import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Configure any additional Firebase settings here if needed
        
        return true
    }
    
    // Handle other app delegate methods as needed
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Called when the app becomes active
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Called when the app will move from active to inactive state
    }
}

@main
struct SpellingBeeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
