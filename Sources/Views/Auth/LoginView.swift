import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @StateObject private var authService = AuthService()
    
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Premium Animated Background
                AnimatedGradient(
                    colors: [
                        DesignSystem.Colors.fallbackPrimary.opacity(0.8),
                        DesignSystem.Colors.fallbackSecondary.opacity(0.8),
                        Color(hex: "4F46E5").opacity(0.8) // Indigo
                    ]
                )
                .ignoresSafeArea()
                
                // Content
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer()
                            .frame(height: 60)
                        
                        // Logo Section
                        VStack(spacing: 24) {
                            // App Logo with Glow
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.fallbackPrimary.opacity(0.3))
                                    .frame(width: 140, height: 140)
                                    .blur(radius: 20)
                                
                                Image("AppLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(28)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            }
                            
                            VStack(spacing: 8) {
                                DesignSystem.Typography.largeTitle("Lyo")
                                    .foregroundColor(.white)
                                
                                Text("Learn Your Own Way")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                    .tracking(2)
                            }
                        }
                        
                        // Login Form Card
                        GlassCard {
                            VStack(spacing: 24) {
                                // Form Fields
                                VStack(spacing: 16) {
                                    CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                                    CustomSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
                                }
                                
                                if let error = authService.error {
                                    Text(error)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                
                                // Login Button
                                PremiumButton(
                                    "Log In",
                                    icon: "arrow.right",
                                    isLoading: authService.isLoading,
                                    action: {
                                        Task {
                                            await authService.login(email: email, password: password)
                                            if authService.isAuthenticated {
                                                rootViewModel.isAuthenticated = true
                                            }
                                        }
                                    }
                                )
                                .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
                                .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)
                            }
                            .padding(24)
                        }
                        .padding(.horizontal, 24)
                        
                        // Social & Demo
                        VStack(spacing: 20) {
                            HStack {
                                Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.2))
                                Text("OR").font(.caption).fontWeight(.bold).foregroundColor(.white.opacity(0.6))
                                Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.2))
                            }
                            .padding(.horizontal, 40)
                            
                            VStack(spacing: 12) {
                                SignInWithAppleButton(
                                    onRequest: { request in
                                        authService.prepareAppleSignInRequest(request)
                                    },
                                    onCompletion: { result in
                                        authService.handleAppleSignIn(result: result)
                                        if authService.isAuthenticated {
                                            rootViewModel.isAuthenticated = true
                                        }
                                    }
                                )
                                .signInWithAppleButtonStyle(.white)
                                .frame(maxWidth: 340) // Fixed max width to prevent layout issues
                                .frame(height: 52, alignment: .center)
                                .cornerRadius(16)
                                
                                Button(action: {
                                    authService.signInWithGoogle()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                         if authService.isAuthenticated {
                                             rootViewModel.isAuthenticated = true
                                         }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "globe")
                                        Text("Sign in with Google")
                                    }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: 340)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                }
                                
                                // Demo Mode Button
                                Button(action: {
                                    AuthService.shared.enterDemoMode()
                                    rootViewModel.isAuthenticated = true
                                }) {
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                        Text("Try Demo Mode")
                                    }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: 340)
                                    .frame(height: 50)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                        
                        Button(action: { showRegister = true }) {
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Sign Up")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .font(.subheadline)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .sheet(isPresented: $showRegister) {
                RegisterView(authService: authService, isPresented: $showRegister)
            }
        }
    }
}

// MARK: - Custom Components

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                .foregroundColor(.white)
                .autocapitalization(.none)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
