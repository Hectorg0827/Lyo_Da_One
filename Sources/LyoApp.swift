import SwiftUI
import UIKit
import UserNotifications

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
import os
#endif

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #else
        Log.app.warning("FirebaseCore not available. Skipping FirebaseApp.configure()")
        #endif
        
        // Configure Crashlytics
        configureCrashlytics()

        // Bump Nuke's image cache well above iOS defaults so feed scrolling
        // actually keeps images warm. Replaces SwiftUI's default URLCache-only path.
        LyoImagePipeline.configure()

        setupAppearance()
        configureGoogleSignIn()
        configurePushNotifications()
        return true
    }
    
    // MARK: - Crashlytics Configuration
    
    private func configureCrashlytics() {
        #if canImport(FirebaseCrashlytics)
        // Set user identifier for crash reports (if logged in)
        if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
            Crashlytics.crashlytics().setUserID(userId)
        }
        
        // Add custom keys for debugging
        Crashlytics.crashlytics().setCustomValue(AppConfig.version, forKey: "app_version")
        Crashlytics.crashlytics().setCustomValue(AppConfig.buildNumber, forKey: "build_number")
        
        Log.app.error("Firebase Crashlytics configured")
        #else
        Log.app.warning("FirebaseCrashlytics not available")
        #endif
    }
    
    // MARK: - Push Notifications
    
    private func configurePushNotifications() {
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared
        Log.app.info("Push notification delegate configured")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationService.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
    
    private func configureGoogleSignIn() {
        #if canImport(GoogleSignIn)
        // Configure Google Sign-In with client ID from Info.plist
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            Log.app.info("Google Sign-In configured with client ID")
        } else {
            Log.app.warning("GIDClientID not found in Info.plist")
        }
        #else
        Log.app.warning("GoogleSignIn not available. Skipping configuration.")
        #endif
    }

    private func setupAppearance() {
        // Configure navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance

        // Tint color
        UINavigationBar.appearance().tintColor = .systemBlue
    }

    // Handle Google Sign-In redirect
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        #if canImport(GoogleSignIn)
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        #endif
        return false
    }
}

// MARK: - Main App
@main
struct LyoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var rootViewModel = RootViewModel()
    @StateObject private var uiState = AppUIState()
    @StateObject private var uiStackStore = UIStackStore.shared
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if rootViewModel.isLoading {
                    // Splash screen while checking auth
                    LyoSplashView()
                } else if rootViewModel.isAuthenticated {
                    // Main app - Authenticated
                    MainTabView()
                        .environmentObject(rootViewModel)
                        .environmentObject(uiState)
                        .environmentObject(uiStackStore)
                        .environmentObject(deepLinkHandler)
                } else {
                    // Authentication flow
                    LoginView()
                        .environmentObject(rootViewModel)
                }
            }
            .preferredColorScheme(rootViewModel.colorScheme)
            .onAppear {
                rootViewModel.checkAuthStatus()
            }
            .onOpenURL { url in
                deepLinkHandler.handle(url: url)
            }
        }
    }
}

// MARK: - Deep Link Handler
@MainActor
class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    @Published var pendingCourseId: String?
    @Published var pendingAction: DeepLinkAction?
    
    enum DeepLinkAction: Equatable {
        case openCourse(String)
        case openLesson(courseId: String, lessonId: String)
        case openProfile(userId: String)
        case openChat
        case openDemo
    }
    
    private init() {}
    
    /// Handle incoming deep link URL
    func handle(url: URL) {
        Log.app.info("Deep link received: \(url)")
        
        guard url.scheme == "lyoapp" else {
            Log.app.warning("Unknown URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        switch host {
        case "demo":
            Log.app.debug("Opening Demo Course")
            pendingAction = .openDemo

        case "course":
            // lyoapp://course/{courseId}
            if let courseId = pathComponents.first {
                Log.app.info("📚 Opening course: \(courseId)")
                pendingCourseId = courseId
                pendingAction = .openCourse(courseId)
            }
            
        case "lesson":
            // lyoapp://lesson/{courseId}/{lessonId}
            if pathComponents.count >= 2 {
                let courseId = pathComponents[0]
                let lessonId = pathComponents[1]
                Log.app.info("📖 Opening lesson: \(lessonId) in course: \(courseId)")
                pendingAction = .openLesson(courseId: courseId, lessonId: lessonId)
            }
            
        case "profile":
            // lyoapp://profile/{userId}
            if let userId = pathComponents.first {
                Log.app.info("Opening profile: \(userId)")
                pendingAction = .openProfile(userId: userId)
            }
            
        case "chat":
            // lyoapp://chat
            Log.app.info("Opening chat")
            pendingAction = .openChat
            
        default:
            Log.app.warning("Unknown deep link host: \(host)")
        }
    }
    
    /// Clear pending action after navigation
    func clearPendingAction() {
        pendingCourseId = nil
        pendingAction = nil
    }
}

// MARK: - Splash View
struct LyoSplashView: View {
    @State private var isAnimating = false
    @State private var mascotScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0.5
    
    var body: some View {
        ZStack {
            // Premium Background
            PremiumBackground()
            
            // Particles
            SplashMascotParticles(color: Color(hex: "6366F1"))
                .opacity(0.5)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Mascot & Glow
                ZStack {
                    // Outer Glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "6366F1").opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0.6 : 0.3)
                    
                    // Core Glow
                    Circle()
                        .fill(Color(hex: "8B5CF6").opacity(0.3))
                        .frame(width: 180, height: 180)
                        .blur(radius: 20)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                    
                    // Mascot
                    Image("LyoAvatar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .scaleEffect(mascotScale)
                        .shadow(color: Color(hex: "6366F1").opacity(0.5), radius: 20, x: 0, y: 10)
                        // Float animation
                        .offset(y: isAnimating ? -10 : 10)
                }
                
                // Text Content
                VStack(spacing: 16) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60) // Adjust height as needed
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Text("Learn Your Own Way")
                        .font(.title3.weight(.medium))
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(1)
                }
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
                
                Spacer()
                
                // Loading Indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            // Start animations
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
                glowOpacity = 0.8
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                mascotScale = 1.0
            }
        }
    }
}

// MARK: - Splash Particles
struct SplashMascotParticles: View {
    let color: Color
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var speed: CGFloat
    }
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x * size.width,
                        y: particle.y * size.height,
                        width: 4 * particle.scale,
                        height: 4 * particle.scale
                    )
                    context.opacity = particle.opacity
                    context.fill(Circle().path(in: rect), with: .color(color))
                }
            }
        }
        .onReceive(timer) { _ in
            updateParticles()
        }
    }
    
    private func updateParticles() {
        // Add new particle
        if Double.random(in: 0...1) > 0.7 {
            particles.append(Particle(
                x: CGFloat.random(in: 0.2...0.8),
                y: 0.8, // Start near bottom
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0,
                speed: CGFloat.random(in: 0.01...0.03)
            ))
        }
        
        // Update existing
        for i in particles.indices {
            particles[i].y -= particles[i].speed
            particles[i].opacity -= 0.02
        }
        
        // Remove dead particles
        particles.removeAll { $0.opacity <= 0 }
    }
}
