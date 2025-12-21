import SwiftUI

struct AdaptiveHomeView: View {
    @StateObject private var contextService = UserContextService.shared
    @State private var showPersonaBadge = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Dynamic greeting based on context
            HStack {
                VStack(alignment: .leading) {
                    Text(contextService.adaptiveGreeting)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let persona = contextService.currentContext?.persona {
                        HStack(spacing: 4) {
                            Image(systemName: personaIcon(for: persona))
                            Text(persona.capitalized + " Mode")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .onAppear { showPersonaBadge = true }
                        .opacity(showPersonaBadge ? 1 : 0)
                        .animation(.easeIn(duration: 0.5), value: showPersonaBadge)
                    }
                }
                Spacer()
            }
            .padding()
            
            // Context-aware content suggestions
            contextAwareContent
        }
        .task {
            await contextService.fetchContext()
        }
    }
    
    @ViewBuilder
    private var contextAwareContent: some View {
        switch contextService.contentStyle {
        case .examFocused:
            ExamPrepSuggestionsView()
        case .professional:
            ProfessionalSkillsView()
        case .exploratory:
            ExploratorySuggestionsView()
        case .balanced:
            DefaultSuggestionsView()
        }
    }
    
    private func personaIcon(for persona: String) -> String {
        switch persona {
        case "student": return "graduationcap.fill"
        case "professional": return "briefcase.fill"
        case "hobbyist": return "star.fill"
        default: return "person.fill"
        }
    }
}

// Placeholder views - implement based on your design
struct ExamPrepSuggestionsView: View {
    var body: some View {
        VStack {
            Text("📝 Quick Review")
            Text("Practice questions ready for you")
        }
    }
}

struct ProfessionalSkillsView: View {
    var body: some View {
        VStack {
            Text("💼 High-Impact Skills")
            Text("15-minute lessons for busy schedules")
        }
    }
}

struct ExploratorySuggestionsView: View {
    var body: some View {
        VStack {
            Text("🔍 Deep Dives")
            Text("Explore topics at your own pace")
        }
    }
}

struct DefaultSuggestionsView: View {
    var body: some View {
        Text("Recommended for you")
    }
}
