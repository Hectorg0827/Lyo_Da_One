import SwiftUI

struct LyoHomeView: View {
    @StateObject private var viewModel = LyoAIViewModel()
    @EnvironmentObject var rootViewModel: RootViewModel
    @FocusState private var isInputFocused: Bool
    
    private var userFirstName: String {
        if let name = rootViewModel.currentUser?.name {
            return name.components(separatedBy: " ").first ?? name
        }
        return "User"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat Area
                ScrollViewReader { proxy in
                    ScrollView {
                        if viewModel.messages.isEmpty {
                            emptyStateView
                                .frame(minHeight: UIScreen.main.bounds.height * 0.6)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.messages) { message in
                                    LyoMessageBubbleView(message: message)
                                        .id(message.id)
                                }
                                
                                if viewModel.isLoading {
                                    HStack {
                                        LyoTypingIndicator()
                                        Spacer()
                                    }
                                    .padding(.leading)
                                    .id("typingIndicator")
                                }
                            }
                            .padding()
                        }
                    }
                    .onChange(of: viewModel.messages.count) {
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isLoading) { _, isLoading in
                        if isLoading {
                            withAnimation {
                                proxy.scrollTo("typingIndicator", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Area
                ComposerBar(
                    text: $viewModel.inputText,
                    attachments: $viewModel.attachments,
                    isLoading: viewModel.isLoading,
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    },
                    onAddAttachment: {
                        // Handle attachment
                    },
                    onRemoveAttachment: { attachment in
                        if let index = viewModel.attachments.firstIndex(where: { $0.id == attachment.id }) {
                            viewModel.attachments.remove(at: index)
                        }
                    }
                )
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("Lyo")
                            .font(.headline)
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .sheet(isPresented: $viewModel.isQuizActive) {
                if let quiz = viewModel.activeQuiz {
                    QuizView(quiz: quiz)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
                .padding()
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                )
            
            VStack(spacing: 8) {
                Text("Welcome, \(userFirstName)")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("What would you like to learn?")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct LyoTypingIndicator: View {
    @State private var numberOfDots = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .scaleEffect(numberOfDots == index ? 1.2 : 0.8)
            }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.6).repeatForever()) {
                numberOfDots = 2
            }
        }
    }
}
