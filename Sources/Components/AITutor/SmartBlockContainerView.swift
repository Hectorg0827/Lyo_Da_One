import SwiftUI

/// A container that parses an AI message and renders it as a sequence of Smart Blocks.
public struct SmartBlockContainerView: View {
    let rawResponse: String
    let isFromUser: Bool
    let showCursor: Bool
    var onQuizAnswerSubmitted: ((Int, Bool) -> Void)? = nil
    var onTestPrepScheduled: ((Date, String, String, [String]) -> Void)? = nil
    
    public init(rawResponse: String, 
         isFromUser: Bool = false, 
         showCursor: Bool = false, 
         onQuizAnswerSubmitted: ((Int, Bool) -> Void)? = nil,
         onTestPrepScheduled: ((Date, String, String, [String]) -> Void)? = nil) {
        self.rawResponse = rawResponse
        self.isFromUser = isFromUser
        self.showCursor = showCursor
        self.onQuizAnswerSubmitted = onQuizAnswerSubmitted
        self.onTestPrepScheduled = onTestPrepScheduled
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ForEach(SmartBlockParser.parseResponse(rawResponse)) { item in
                renderBlock(item.block)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.95))),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rawResponse)
    }
    
    @ViewBuilder
    private func renderBlock(_ block: LegacyLessonBlock) -> some View {
        switch block {
        case .text(let content):
            RichTextBubble(content: content, isFromUser: isFromUser)
            
        case .quiz(let data):
            SmartBlockQuizCard(data: data, onAnswerSubmitted: onQuizAnswerSubmitted)
            
        case .flashcard(let data):
            FlashcardView(data: data)
            
        case .flashcardSet(let data):
            FlashcardSetView(data: data)
            
        case .progress(let data):
            ProgressBarView(data: data)
            
        case .summary(let data):
            SmartBlockSummaryCard(data: data)
            
        case .image(let data):
            LessonImageView(data: data)
            
        case .testPrep(let testPrep):
            TestPrepCardView(data: testPrep) { date, course, desc, ids in
                onTestPrepScheduled?(date, course, desc, ids)
            }
            
        case .studyPlan(let studyPlan):
            SmartBlockStudyPlanView(data: studyPlan)
            
        case .agentCard(let agentCard):
            AgentCardView(data: agentCard)
            
        case .cinematicHook(let hook):
            CinematicHookView(data: hook)
            
        case .masteryMap(let data):
            MasteryMapView(data: data)
            
        default:
            // Placeholder for unknown blocks
            Text("Unsupported Block Type")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding()
                .background(DesignTokens.Colors.surfaceHighlight)
                .cornerRadius(DesignTokens.Radius.md)
        }
    }
}
