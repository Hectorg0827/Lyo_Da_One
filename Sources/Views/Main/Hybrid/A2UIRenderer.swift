import SwiftUI

struct A2UIRenderer: View {
    let payload: OpenClassroomPayload
    var onOpen: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.indigo.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(radius: 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Course Available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Text(payload.course.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Objectives
            VStack(alignment: .leading, spacing: 4) {
                Text("Objectives")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
                
                ForEach(payload.course.objectives.prefix(3), id: \.self) { objective in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green.opacity(0.8))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 4)
            
            // Metadata Tags
            HStack {
                Label(payload.course.level ?? "Level", systemImage: "chart.bar.fill")
                Spacer()
                Label(payload.course.duration ?? "Duration", systemImage: "clock.fill")
            }
            .font(.caption)
            .foregroundColor(.indigo.opacity(0.8))
            .padding(8)
            .background(Color.white.opacity(0.9))
            .cornerRadius(8)
            
            // Action Button
            Button(action: {
                onOpen?()
            }) {
                HStack {
                    Text("Start Learning")
                    Image(systemName: "arrow.right")
                }
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .indigo.opacity(0.4), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(
            ZStack {
                Color(hex: "1E1E2E")
                
                // Subtle decorative gradient
                LinearGradient(
                    colors: [Color.indigo.opacity(0.1), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
