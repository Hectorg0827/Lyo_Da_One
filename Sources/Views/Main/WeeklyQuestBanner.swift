import SwiftUI

/// Compact quest card on the home screen: a weekly goal generated from the
/// learner's own weaknesses, with progress driven by mastery-honest XP events.
/// Renders nothing when no quest exists (brand-new learners).
struct WeeklyQuestBanner: View {
    @ObservedObject private var gamification = GamificationService.shared

    var body: some View {
        if let quest = gamification.weeklyQuest {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hexString: "D9B24C").opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: quest.completed ? "checkmark.seal.fill" : "target")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hexString: "D9B24C"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(quest.completed ? "Quest complete! +150 XP" : quest.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(quest.completed ? "New quest arrives next week." : quest.subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer()

                if !quest.completed {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: CGFloat(quest.progress) / CGFloat(max(quest.goal, 1)))
                            .stroke(
                                Color(hexString: "D9B24C"),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        Text("\(quest.progress)/\(quest.goal)")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundColor(.white)
                    }
                    .frame(width: 40, height: 40)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hexString: "D9B24C").opacity(quest.completed ? 0.5 : 0.2), lineWidth: 1)
                    )
            )
        }
    }
}
