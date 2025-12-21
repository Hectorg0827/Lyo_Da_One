import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @ObservedObject var authService: AuthService
    @Binding var isPresented: Bool
    
    // Onboarding State
    enum Step {
        case intro
        case name
        case goal
        case credentials
        case creating
    }
    
    @State private var currentStep: Step = .intro
    @State private var lyoMessage: String = ""
    @State private var showInput = false
    
    // User Data
    @State private var name = ""
    @State private var selectedGoals: Set<String> = []
    @State private var email = ""
    @State private var password = ""
    
    // Animation
    @State private var isThinking = false
    @Namespace private var animation
    
    let goals = [
        "Mathematics", "Computer Science", "Physics", "Literature", "History", "Art",
        "Photography", "Cooking", "Music", "Fitness", "Gaming", "Travel", "Other"
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Ambient Background Effects
            AnimatedGradient(
                colors: [
                    Color(hex: "4F46E5").opacity(0.3),
                    Color(hex: "9333EA").opacity(0.2),
                    Color.black
                ]
            )
            .ignoresSafeArea()
            
            VStack {
                // 1. Lyo Avatar Section
                Spacer()
                
                LyoAvatarView(
                    size: 180,
                    isListening: false,
                    isThinking: isThinking
                )
                .shadow(color: Color(hex: "FF8C00").opacity(0.5), radius: 30)
                .padding(.bottom, 40)
                
                // 2. Speech Bubble
                if !lyoMessage.isEmpty {
                    Text(lyoMessage)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 32)
                        .transition(.scale.combined(with: .opacity))
                        .id("Message-\(lyoMessage)") // Force redraw for animation
                }
                
                Spacer()
                
                // 3. Dynamic Input Area
                VStack {
                    if showInput {
                        switch currentStep {
                        case .intro:
                            Button(action: nextStep) {
                                Text("Hi Lyo! 👋")
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal, 40)
                            
                        case .name:
                            VStack(spacing: 16) {
                                CustomTextField(icon: "person.fill", placeholder: "Your Name", text: $name)
                                
                                Button(action: nextStep) {
                                    Image(systemName: "arrow.right")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color(hex: "FF8C00"))
                                        .clipShape(Circle())
                                }
                                .disabled(name.isEmpty)
                                .opacity(name.isEmpty ? 0.5 : 1.0)
                            }
                            .padding(.horizontal, 40)
                            
                        case .goal:
                            VStack(spacing: 20) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(goals, id: \.self) { goal in
                                            Button(action: {
                                                if selectedGoals.contains(goal) {
                                                    selectedGoals.remove(goal)
                                                } else {
                                                    selectedGoals.insert(goal)
                                                }
                                            }) {
                                                Text(goal)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(selectedGoals.contains(goal) ? .black : .white)
                                                    .padding(.horizontal, 20)
                                                    .padding(.vertical, 12)
                                                    .background(
                                                        Capsule()
                                                            .fill(selectedGoals.contains(goal) ? Color.white : Color.white.opacity(0.1))
                                                    )
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 40)
                                }
                                
                                Button(action: nextStep) {
                                    Image(systemName: "arrow.right")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color(hex: "FF8C00"))
                                        .clipShape(Circle())
                                }
                                .disabled(selectedGoals.isEmpty)
                                .opacity(selectedGoals.isEmpty ? 0.5 : 1.0)
                            }
                            
                        case .credentials:
                            VStack(spacing: 16) {
                                // Social Login
                                HStack(spacing: 16) {
                                    SignInWithAppleButton(
                                        onRequest: { request in
                                            request.requestedScopes = [.fullName, .email]
                                        },
                                        onCompletion: { result in
                                            handleSocialLogin {
                                                authService.handleAppleSignIn(result: result)
                                            }
                                        }
                                    )
                                    .signInWithAppleButtonStyle(.white)
                                    .frame(height: 50)
                                    .cornerRadius(16)
                                    
                                    Button(action: {
                                        handleSocialLogin {
                                            authService.signInWithGoogle()
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "globe")
                                            Text("Google")
                                        }
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.white)
                                        .cornerRadius(16)
                                    }
                                }
                                
                                HStack {
                                    Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.2))
                                    Text("OR").font(.caption).fontWeight(.bold).foregroundColor(.white.opacity(0.6))
                                    Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.2))
                                }
                                
                                CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                                CustomSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
                                
                                Button(action: nextStep) {
                                    Text("Create Profile")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(hex: "FF8C00"))
                                        .cornerRadius(16)
                                }
                                .disabled(email.isEmpty || password.isEmpty)
                                .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1.0)
                            }
                            .padding(.horizontal, 40)
                            
                        case .creating:
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
                    }
                }
                .frame(height: 150) // Fixed height for input area
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                Spacer()
                    .frame(height: 20)
            }
        }
        .onAppear {
            startOnboarding()
        }
    }
    
    // MARK: - Logic
    
    private func startOnboarding() {
        typeWriterEffect("Hello! I'm Lyo. I'm here to help you learn anything you want.") {
            withAnimation { showInput = true }
        }
    }
    
    private func nextStep() {
        withAnimation { showInput = false }
        
        switch currentStep {
        case .intro:
            currentStep = .name
            typeWriterEffect("First things first, what should I call you?") {
                withAnimation { showInput = true }
            }
            
        case .name:
            currentStep = .goal
            typeWriterEffect("Nice to meet you, \(name)! What are you most interested in learning right now?") {
                withAnimation { showInput = true }
            }
            
        case .goal:
            currentStep = .credentials
            let goalText = selectedGoals.count > 1 ? "Those are great choices!" : "\(selectedGoals.first ?? "That")? That's awesome!"
            typeWriterEffect("\(goalText) Let's create your secure profile so we can save your progress.") {
                withAnimation { showInput = true }
            }
            
        case .credentials:
            currentStep = .creating
            isThinking = true
            typeWriterEffect("Setting up your personal campus...") {
                createAccount()
            }
            
        case .creating:
            break
        }
    }
    
    private func handleSocialLogin(action: @escaping () -> Void) {
        currentStep = .creating
        isThinking = true
        withAnimation { showInput = false }
        
        typeWriterEffect("Connecting to your account...") {
            action()
            
            // Wait for auth state change
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if authService.isAuthenticated {
                    rootViewModel.isAuthenticated = true
                    isPresented = false
                } else {
                    isThinking = false
                    currentStep = .credentials
                    lyoMessage = authService.error ?? "Login failed. Please try again."
                    withAnimation { showInput = true }
                }
            }
        }
    }

    private func createAccount() {
        Task {
            // Simulate a little delay for the "Building Campus" effect
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await authService.register(name: name, email: email, password: password)
            
            await MainActor.run {
                isThinking = false
                if authService.isAuthenticated {
                    rootViewModel.isAuthenticated = true
                    isPresented = false
                } else {
                    // Handle Error
                    currentStep = .credentials
                    lyoMessage = authService.error ?? "Oops! Something went wrong. Try again?"
                    withAnimation { showInput = true }
                }
            }
        }
    }
    
    private func typeWriterEffect(_ text: String, completion: @escaping () -> Void) {
        lyoMessage = ""
        let chars = Array(text)
        var index = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if index < chars.count {
                lyoMessage.append(chars[index])
                index += 1
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion()
                }
            }
        }
    }
}
