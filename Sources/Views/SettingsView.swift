import SwiftUI
import os

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var monetization = MonetizationService.shared
    @State private var notificationsEnabled = true
    @State private var soundEnabled = true
    @State private var selectedColorScheme: ColorSchemeOption = .system
    @State private var showingSubscriptionSheet = false
    @State private var notificationPreferences: NotificationPreferences?
    @State private var showingDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    var body: some View {
        NavigationView {
            List {
                // Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $selectedColorScheme) {
                        ForEach(ColorSchemeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .onChange(of: selectedColorScheme) { oldValue, newValue in
                        rootViewModel.setColorScheme(newValue.colorScheme)
                    }
                }
                
                // ✨ Subscription & Energy Section
                Section("Subscription") {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(monetization.isPremium ? .yellow : .gray)
                        Text("Plan")
                        Spacer()
                        Text(monetization.currentTier.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        Text("AI Energy")
                        Spacer()
                        Text("\(monetization.energyCredits) / \(monetization.currentTier.dailyEnergyLimit)")
                            .foregroundColor(.secondary)
                    }
                    
                    if !monetization.isPremium {
                        Button {
                            showingSubscriptionSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Upgrade to Premium")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Button {
                        Task {
                            await monetization.restorePurchases()
                        }
                    } label: {
                        Text("Restore Purchases")
                            .foregroundColor(.blue)
                    }
                }

                // Notifications Section
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { oldValue, newValue in
                            updateNotificationPreference(courseReminders: newValue)
                        }
                    Toggle("Sound", isOn: $soundEnabled)
                    
                    Button {
                        Task {
                            try? await PushNotificationService.shared.sendTestNotification()
                        }
                    } label: {
                        Text("Send Test Notification")
                            .foregroundColor(.blue)
                    }
                }

                // Learning Preferences
                Section("Learning") {
                    NavigationLink("Difficulty Level") {
                        DifficultySettingsView()
                    }

                    NavigationLink("Preferred Topics") {
                        TopicsPreferencesView()
                    }
                }

                // Privacy Section
                Section("Privacy & Security") {
                    // The published policy and terms on lyoai.app are the only versions.
                    Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)

                    Link("Terms of Service", destination: AppConfig.termsOfServiceURL)

                    NavigationLink("Blocked accounts") {
                        BlockedAccountsView()
                    }

                    Button("Clear Cache") {
                        clearCache()
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppConfig.version)
                            .foregroundColor(.secondary)
                    }

                    NavigationLink("What's New") {
                        WhatsNewView()
                    }

                    NavigationLink("Help & Support") {
                        HelpSupportView()
                    }
                }

                // Account Section
                Section {
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Text("Delete Account")
                            if isDeletingAccount {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .foregroundColor(.red)
                    .disabled(isDeletingAccount)
                } header: {
                    Text("Account")
                } footer: {
                    Text("Permanently deletes your LYO account and its data.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete your account permanently?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Permanently", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This permanently deletes your LYO account and everything in it: your profile, courses, progress, chats and posts. It can't be undone. If you signed in with Apple, you'll be asked to confirm with Apple.")
            }
            .alert("Couldn't delete your account", isPresented: Binding(
                get: { deleteAccountError != nil },
                set: { if !$0 { deleteAccountError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountError ?? "")
            }

            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
            .sheet(isPresented: $showingSubscriptionSheet) {
                SubscriptionView()
            }
        }
    }

    private func loadSettings() {
        // Load current color scheme
        if let scheme = rootViewModel.colorScheme {
            selectedColorScheme = scheme == .light ? .light : .dark
        } else {
            selectedColorScheme = .system
        }
        
        // Load notification preferences from backend
        Task {
            if let prefs = try? await PushNotificationService.shared.getPreferences() {
                notificationPreferences = prefs
                notificationsEnabled = prefs.courseReminders
            }
            
            // Refresh energy credits
            await monetization.refillEnergy()
        }
    }
    
    private func updateNotificationPreference(courseReminders: Bool) {
        Task {
            var prefs = notificationPreferences ?? NotificationPreferences()
            prefs.courseReminders = courseReminders
            _ = try? await PushNotificationService.shared.updatePreferences(prefs)
        }
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        // Clear custom image cache if any
        // ImageCache.shared.clear() // Example if using custom cache
        Log.ui.info("Cache cleared")
    }
    
    private func deleteAccount() {
        isDeletingAccount = true
        Task { @MainActor in
            do {
                try await AuthService.shared.deleteAccount()
                isDeletingAccount = false
                dismiss()
                // Only now, with the account gone, does the app return to sign-in.
                await rootViewModel.didDeleteAccount()
            } catch {
                // Nothing was deleted and the learner stays signed in.
                isDeletingAccount = false
                Log.ui.error("Failed to delete account: \(error.localizedDescription)")
                deleteAccountError = error.localizedDescription
            }
        }
    }
}

// MARK: - Color Scheme Option
enum ColorSchemeOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Difficulty Settings View
struct DifficultySettingsView: View {
    @State private var selectedDifficulty: QuizDifficulty = .medium

    var body: some View {
        List {
            ForEach([QuizDifficulty.easy, .medium, .hard], id: \.self) { difficulty in
                Button {
                    selectedDifficulty = difficulty
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(difficulty.rawValue.capitalized)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(difficultyDescription(for: difficulty))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if selectedDifficulty == difficulty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Difficulty Level")
    }

    private func difficultyDescription(for difficulty: QuizDifficulty) -> String {
        switch difficulty {
        case .easy: return "Gentle introduction to topics"
        case .medium: return "Balanced challenge level"
        case .hard: return "Advanced questions"
        case .adaptive: return "Adjusts to your performance"
        }
    }
}

// MARK: - Topics Preferences View
struct TopicsPreferencesView: View {
    @State private var selectedTopics: Set<String> = ["Math", "Science"]

    let availableTopics = [
        "Math", "Science", "History", "English",
        "Programming", "Geography", "Art", "Music"
    ]

    var body: some View {
        List {
            ForEach(availableTopics, id: \.self) { topic in
                Button {
                    if selectedTopics.contains(topic) {
                        selectedTopics.remove(topic)
                    } else {
                        selectedTopics.insert(topic)
                    }
                } label: {
                    HStack {
                        Text(topic)
                            .foregroundColor(.primary)

                        Spacer()

                        if selectedTopics.contains(topic) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Preferred Topics")
    }
}

// MARK: - What's New View
struct WhatsNewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WhatsNewItem(
                    version: "1.0.0",
                    date: "January 2025",
                    features: [
                        "Adaptive quiz system with AI-powered questions",
                        "Text-to-speech with word-level highlighting",
                        "Community hub with study groups and events",
                        "Real-time chat and social feed",
                        "Gamification with achievements and streaks"
                    ]
                )
            }
            .padding()
        }
        .navigationTitle("What's New")
    }
}

struct WhatsNewItem: View {
    let version: String
    let date: String
    let features: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Version \(version)")
                    .font(.headline)

                Spacer()

                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)

                        Text(feature)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Help & Support View
struct HelpSupportView: View {
    var body: some View {
        List {
            Section("Get Help") {
                Link(destination: AppConfig.supportURL) {
                    row(icon: "questionmark.circle", title: "Help Center")
                }

                if let email = URL(string: "mailto:\(AppConfig.supportEmail)") {
                    Link(destination: email) {
                        row(icon: "envelope", title: "Email Support")
                    }
                }

                if let email = URL(string: "mailto:\(AppConfig.feedbackEmail)") {
                    Link(destination: email) {
                        row(icon: "bubble.left", title: "Send Feedback")
                    }
                }
            }

            Section("Legal") {
                Link(destination: AppConfig.privacyPolicyURL) {
                    row(icon: "hand.raised", title: "Privacy Policy")
                }

                Link(destination: AppConfig.termsOfServiceURL) {
                    row(icon: "doc.text", title: "Terms of Service")
                }
            }
        }
        .navigationTitle("Help & Support")
    }

    private func row(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(RootViewModel())
    }
}
