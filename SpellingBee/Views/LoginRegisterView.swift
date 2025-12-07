import SwiftUI

struct LoginRegisterView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var gameManager: GameManager
    @State private var isRegistering = false
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Game Logo
            Image("SpellingBee") // Replace with your actual logo asset
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .padding(.top, 20)
            
            Text(isRegistering ? "Create Account" : "Welcome Back")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
                .animation(.easeInOut, value: isRegistering)
            
            VStack(spacing: 20) {
                if isRegistering {
                    TextField("Username", text: $username)
                        .textFieldStyle(ModernTextFieldStyle())
                        .textContentType(.username)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(ModernTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(ModernTextFieldStyle())
                    .textContentType(isRegistering ? .newPassword : .password)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: isRegistering)
            
            Button(action: handleAuth) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(isRegistering ? "Sign Up" : "Log In")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 5)
            }
            .disabled(isLoading || !isFormValid)
            .opacity(isLoading || !isFormValid ? 0.6 : 1.0)
            .animation(.easeInOut, value: isLoading)
            
            // Social Login Buttons
            VStack(spacing: 15) {
                Text("Or continue with")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SocialLoginButton(icon: "facebook", text: "Continue with Facebook", color: Color.blue)
                SocialLoginButton(icon: "google", text: "Continue with Google", color: Color.red)
            }
            .opacity(0.8) // Slightly dimmed since not implemented
            
            Button(action: toggleAuthMode) {
                Text(isRegistering ? "Already have an account? Log In" : "Need an account? Sign Up")
                    .foregroundColor(.blue)
                    .font(.subheadline)
                    .underline()
            }
            .disabled(isLoading)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .onAppear {
            // Clear any previous error messages when view appears
            errorMessage = nil
        }
    }
    
    private var isFormValid: Bool {
        if isRegistering {
            return !username.isEmpty && !email.isEmpty && !password.isEmpty && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func toggleAuthMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isRegistering.toggle()
            errorMessage = nil
            // Clear password when switching modes for better UX
            if !isRegistering {
                password = ""
            }
        }
    }
    
    private func handleAuth() {
        // Clear any previous error messages
        errorMessage = nil
        
        // Basic validation
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please fill in all required fields."
            return
        }
        
        if isRegistering && username.isEmpty {
            errorMessage = "Username is required for registration."
            return
        }
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        
        // Email validation
        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address."
            return
        }
        
        isLoading = true
        
        if isRegistering {
            userManager.register(username: username, email: email, password: password) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.handleAuthResult(result)
                }
            }
        } else {
            userManager.login(email: email, password: password) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.handleAuthResult(result)
                }
            }
        }
    }
    
    private func handleAuthResult(_ result: Result<SpellGameUser, Error>) {
        switch result {
        case .success(let user):
            // Success is now handled automatically by the auth state listener
            print("Authentication successful for user: \(user.username)")
            
            // Clear form fields
            username = ""
            email = ""
            password = ""
            errorMessage = nil
            
        case .failure(let error):
            // Handle specific error types for better user experience
            if let authError = error as NSError? {
                switch authError.code {
                case 17007: // Email already in use
                    errorMessage = "An account with this email already exists."
                case 17008: // Invalid email
                    errorMessage = "Please enter a valid email address."
                case 17026: // Weak password
                    errorMessage = "Password is too weak. Please choose a stronger password."
                case 17011: // User not found
                    errorMessage = "No account found with this email."
                case 17009: // Wrong password
                    errorMessage = "Incorrect password. Please try again."
                case 17020: // Network error
                    errorMessage = "Network error. Please check your connection."
                default:
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

// Social Login Button Component
struct SocialLoginButton: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        Button(action: {
            // TODO: Implement social login
            print("Social login with \(icon) tapped")
        }) {
            HStack(spacing: 12) {
                Image(icon) // Add these assets to your project
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(text)
                    .font(.headline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [color, color.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 5)
        }
        .disabled(true) // Disabled until social login is implemented
        .opacity(0.7)
    }
}

#Preview {
    LoginRegisterView()
        .environmentObject(UserManager())
        .environmentObject(GameManager())
}
