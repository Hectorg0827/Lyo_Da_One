import SwiftUI

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
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }

                    NavigationLink("Terms of Service") {
                        TermsOfServiceView()
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
                        Text("1.0.0")
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
                Section("Account") {
                    Button("Delete Account") {
                        // TODO: Show confirmation dialog
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
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
        // TODO: Implement cache clearing
        print("Cache cleared")
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

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Last updated: January 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("""
                At LYO, we take your privacy seriously. This policy describes how we collect, use, and protect your personal information.

                **Information We Collect**
                - Account information (name, email)
                - Learning progress and activity
                - Device information
                - Usage analytics

                **How We Use Your Information**
                - Personalize your learning experience
                - Improve our services
                - Send important updates
                - Provide customer support

                **Data Security**
                We use industry-standard encryption to protect your data.

                **Your Rights**
                - Access your data
                - Request deletion
                - Export your information
                - Opt-out of communications

                For more information, contact us at privacy@lyo.app
                """)
                .font(.body)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Last updated: January 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("""
                **1. Acceptance of Terms**
                By using LYO, you agree to these terms and conditions.

                **2. User Accounts**
                - You must be 13 years or older
                - Provide accurate information
                - Keep your password secure
                - One account per person

                **3. Content**
                - You retain rights to your content
                - We may use your content to improve services
                - No offensive or inappropriate content

                **4. Prohibited Activities**
                - Cheating or gaming the system
                - Sharing accounts
                - Automated access
                - Harassment of other users

                **5. Termination**
                We may terminate accounts for violations.

                **6. Disclaimer**
                Services provided "as is" without warranties.

                For questions, contact support@lyo.app
                """)
                .font(.body)
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
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
                Link(destination: URL(string: "https://lyo.app/faq")!) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("FAQ")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }

                Link(destination: URL(string: "https://lyo.app/contact")!) {
                    HStack {
                        Image(systemName: "envelope")
                        Text("Contact Support")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }

                Link(destination: URL(string: "https://lyo.app/community")!) {
                    HStack {
                        Image(systemName: "person.3")
                        Text("Community Forum")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }
            }

            Section("Resources") {
                Link(destination: URL(string: "https://lyo.app/tutorials")!) {
                    HStack {
                        Image(systemName: "play.rectangle")
                        Text("Video Tutorials")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }

                Link(destination: URL(string: "https://lyo.app/docs")!) {
                    HStack {
                        Image(systemName: "book")
                        Text("Documentation")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Help & Support")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(RootViewModel())
    }
}
