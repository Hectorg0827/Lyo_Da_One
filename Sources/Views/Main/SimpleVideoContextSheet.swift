import SwiftUI

struct SimpleVideoContextSheet: View {
    let item: DiscoverItem
    let onPromptSelected: (String) -> Void
    
    private var defaultPrompts: [String] {
        let title = item.title
        return [
            "Summarize “\(title)”",
            "Explain the key points",
            "Generate a quick quiz",
            "How to apply this in practice?",
            "What should I learn next?"
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ask Leo about this")
                        .font(.headline)
                    Text(item.subtitle ?? item.tag ?? "Choose a prompt to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            
            // Suggested prompts
            VStack(alignment: .leading, spacing: 10) {
                ForEach(defaultPrompts, id: \.self) { prompt in
                    Button {
                        onPromptSelected(prompt)
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.accentColor)
                            Text(prompt)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.footnote)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

#Preview {
    SimpleVideoContextSheet(
        item: DiscoverItem(
            type: .videoSnippet,
            title: "Intro to SwiftUI",
            subtitle: "Building your first view",
            tag: "SwiftUI",
            estimatedMinutes: 5
        ),
        onPromptSelected: { _ in }
    )
}
