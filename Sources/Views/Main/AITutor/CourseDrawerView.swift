import SwiftUI

struct CourseDrawerView: View {
    @ObservedObject var viewModel: LyoAIViewModel
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Your Courses")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Pin button
                Button {
                    viewModel.toggleDrawerPin()
                } label: {
                    Image(systemName: viewModel.isDrawerPinned ? "pin.fill" : "pin")
                        .font(.system(size: 18))
                        .foregroundColor(Color("LyoAccent"))
                        .frame(width: 40, height: 40)
                }
                
                // Close button
                Button {
                    viewModel.closeDrawer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(Color("LyoTextSecondary"))
                        .frame(width: 40, height: 40)
                }
            }
            .padding()
            .background(Color("LyoBackground"))
            
            // Segmented control tabs
            HStack(spacing: 0) {
                TabButton(
                    title: "Continue",
                    isSelected: viewModel.selectedDrawerTab == .continue,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedDrawerTab = .continue
                    }
                }
                
                TabButton(
                    title: "Started",
                    isSelected: viewModel.selectedDrawerTab == .started,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedDrawerTab = .started
                    }
                }
                
                TabButton(
                    title: "Suggested",
                    isSelected: viewModel.selectedDrawerTab == .suggested,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedDrawerTab = .suggested
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color("LyoSurface"))
            
            // Continue Learning strip (for Continue tab)
            if viewModel.selectedDrawerTab == .continue, let firstCard = viewModel.continueCards.first {
                ContinueLearningStrip(card: firstCard) {
                    viewModel.continueCourse(firstCard)
                }
                .padding()
            }
            
            // Course cards
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(currentCards) { card in
                        CourseCardView(
                            card: card,
                            onContinue: {
                                viewModel.continueCourse(card)
                            },
                            onSave: {
                                viewModel.executeAction(MessageAction(
                                    id: UUID().uuidString,
                                    label: "Save",
                                    actionType: .addToLibrary,
                                    data: ["courseId": card.id]
                                ))
                            }
                        )
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("LyoBackground"))
    }
    
    private var currentCards: [CourseCard] {
        switch viewModel.selectedDrawerTab {
        case .continue: return viewModel.continueCards
        case .started: return viewModel.startedCards
        case .suggested: return viewModel.suggestedCards
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color("LyoTextSecondary"))
                
                if isSelected {
                    Rectangle()
                        .fill(Color("LyoAccent"))
                        .frame(height: 2)
                        .matchedGeometryEffect(id: "tab", in: namespace)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ContinueLearningStrip: View {
    let card: CourseCard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Mini cover
                AsyncImage(url: URL(string: card.coverURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color("LyoSurface"))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue Learning")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color("LyoTextSecondary"))
                    
                    Text(card.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let progress = card.progress {
                        HStack(spacing: 8) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color("LyoSurface"))
                                        .frame(height: 2)
                                    
                                    Rectangle()
                                        .fill(Color("LyoAccent"))
                                        .frame(width: geometry.size.width * CGFloat(progress), height: 2)
                                }
                            }
                            .frame(height: 2)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color("LyoAccent"))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color("LyoTextSecondary"))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("LyoSurface"))
            )
        }
    }
}
