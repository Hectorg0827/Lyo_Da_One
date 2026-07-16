import SwiftUI

// MARK: - Campus Item Detail Sheet

struct CampusItemDetailSheet: View {
    let item: CampusItem
    @Binding var isPresented: Bool
    
    let onJoin: () -> Void
    let onSave: () -> Void
    let onAskLio: () -> Void
    let onRSVP: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    Divider()
                    
                    // Details
                    detailsSection
                    
                    Divider()
                    
                    // Tags
                    if !item.tags.isEmpty {
                        tagsSection
                    }
                    
                    // Action buttons
                    actionButtons
                    
                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Type badge and live indicator
            HStack {
                Label(item.type.displayName, systemImage: item.type.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accentColor)
                    .clipShape(Capsule())
                
                if item.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("LIVE NOW")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                Spacer()
            }
            
            // Title
            Text(item.title)
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            // Subtitle
            Text(item.subtitle)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Host info
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hosted by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.hostName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(spacing: 16) {
            // Date and Time
            DetailRow(
                icon: "calendar",
                title: "Date & Time",
                value: "\(item.formattedDate)\n\(item.formattedTime)"
            )
            
            // Location
            DetailRow(
                icon: "mappin.circle.fill",
                title: "Location",
                value: item.locationName
            )
            
            // Attendees
            HStack(alignment: .top) {
                Image(systemName: "person.2.fill")
                    .font(.body)
                    .foregroundColor(accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Attendees")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("\(item.attendeeCount)")
                            .font(.subheadline.weight(.semibold))
                        
                        if let max = item.maxAttendees {
                            Text("/ \(max)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let spots = item.spotsRemaining {
                                Text("(\(spots) spots left)")
                                    .font(.caption)
                                    .foregroundColor(spots <= 5 ? .orange : .secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Topics")
                .font(.caption)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(item.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // RSVP button
            let isAttending = item.userAttendanceStatus?.uppercased() == "GOING"
            Button(action: onRSVP) {
                HStack {
                    Image(systemName: isAttending ? "checkmark.circle.fill" : "calendar.badge.plus")
                    Text(isAttending ? "Attending" : "RSVP")
                }
                .font(.headline)
                .foregroundColor(isAttending ? accentColor : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(item.isFull && !isAttending ? Color.gray : (isAttending ? accentColor.opacity(0.15) : accentColor))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isAttending ? accentColor : Color.clear, lineWidth: 2)
                )
            }
            .disabled(item.isFull && !isAttending)
            
            // Join button (primary action)
            if item.roomId != nil {
                Button(action: onJoin) {
                    HStack {
                        Image(systemName: "person.3.fill")
                        Text(item.isLive ? "Join Now" : "Join Room")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(item.isFull ? Color.gray : accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(item.isFull)
            }
            
            // Secondary actions
            HStack(spacing: 12) {
                // Save to Stack
                Button(action: onSave) {
                    HStack {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("Save")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.fallbackPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DesignSystem.Colors.fallbackPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Ask Lio
                Button(action: onAskLio) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Ask Lio")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    
    private var accentColor: Color {
        switch item.type.accentColor {
        case "purple": return .purple
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "indigo": return .indigo
        default: return DesignSystem.Colors.fallbackPrimary
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.fallbackPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}


// MARK: - Preview

#Preview {
    CampusItemDetailSheet(
        item: CampusItem.mockItems()[0],
        isPresented: .constant(true),
        onJoin: {},
        onSave: {},
        onAskLio: {},
        onRSVP: {}
    )
}
