
import SwiftUI

struct StudyPlanCard: View {
    let plan: TestPrepData
    @State private var isAddedToCalendar = false
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Study Plan Created")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                    
                    Text(plan.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Sessions Preview
            VStack(alignment: .leading, spacing: 12) {
                ForEach(plan.sessions.prefix(3)) { session in
                    HStack(spacing: 12) {
                        Image(systemName: activityIcon(for: session.activityType))
                            .font(.system(size: 14))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(session.durationMinutes) min • \(session.topic)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
                
                if plan.sessions.count > 3 {
                    Text("+ \(plan.sessions.count - 3) more sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            
            // Action Button
            Button(action: addToCalendar) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else if isAddedToCalendar {
                        Image(systemName: "checkmark")
                        Text("Added to Calendar")
                    } else {
                        Image(systemName: "calendar.badge.plus")
                        Text("Add to Calendar")
                    }
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isAddedToCalendar ? Color.green : Color.accentColor)
                .cornerRadius(12)
            }
            .disabled(isAddedToCalendar || isProcessing)
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func activityIcon(for type: String) -> String {
        switch type.lowercased() {
        case "quiz": return "checkmark.circle.fill"
        case "review": return "book.fill"
        case "practice": return "pencil.circle.fill"
        default: return "clock.fill"
        }
    }
    
    private func addToCalendar() {
        isProcessing = true
        Task {
            // Format for CalendarService
            let studyPlan = CalendarStudyPlan(
                id: plan.planId,
                title: plan.title,
                testDate: plan.testDate,
                sessions: plan.sessions.map { s in
                    CalendarStudySession(
                        id: s.id,
                        title: s.title,
                        description: s.description,
                        topic: s.topic,
                        durationMinutes: s.durationMinutes,
                        activityType: s.activityType
                    )
                }
            )
            
            let count = await CalendarService.shared.addStudyPlan(studyPlan)
            await MainActor.run {
                isProcessing = false
                if count > 0 {
                    withAnimation {
                        isAddedToCalendar = true
                    }
                }
            }
        }
    }
}
