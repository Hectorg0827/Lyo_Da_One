//
//  PrivateLessonDetailView.swift
//  Lyo
//
//  Detail view for private lessons with booking and messaging capabilities
//

import SwiftUI
import MapKit

struct PrivateLessonDetailView: View {
    let lesson: APIPrivateLesson
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingBooking = false
    @State private var showingChat = false
    @State private var showingReviewInput = false
    @State private var region: MKCoordinateRegion
    
    init(lesson: APIPrivateLesson) {
        self.lesson = lesson
        let coordinate = CLLocationCoordinate2D(
            latitude: lesson.lat ?? 40.7128,
            longitude: lesson.lng ?? -74.0060
        )
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Section
                heroSection
                
                // Content
                VStack(spacing: 24) {
                    // Quick Info
                    quickInfoSection
                    
                    Divider()
                    
                    // Instructor Section
                    instructorSection
                    
                    Divider()
                    
                    // Description
                    if let description = lesson.description {
                        descriptionSection(description)
                        Divider()
                    }
                    
                    // Location Map
                    if lesson.lat != nil && lesson.lng != nil {
                        locationSection
                    }
                    
                    Divider()
                    
                    // Reviews
                    reviewsSection
                    
                    // Action Buttons
                    actionButtons
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingBooking) {
            BookingCalendarView(lesson: lesson)
        }
        .sheet(isPresented: $showingChat) {
            NavigationStack {
                ChatView(recipient: lesson.instructor)
                    .navigationTitle("Message \(lesson.instructor.name)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showingChat = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingReviewInput) {
            ReviewInputView(
                targetId: String(lesson.id),
                targetType: "lesson",
                targetName: lesson.title
            )
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image
            Group {
                if let imageURL = lesson.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            defaultHeroBackground
                        }
                    }
                } else {
                    defaultHeroBackground
                }
            }
            .frame(height: 220)
            .clipped()
            
            // Gradient Overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.subject.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
                
                Text(lesson.title)
                    .font(.title.bold())
                    .foregroundColor(.white)
            }
            .padding(20)
        }
    }
    
    private var defaultHeroBackground: some View {
        LinearGradient(
            colors: [Color.purple, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "book.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
        )
    }
    
    // MARK: - Quick Info Section
    
    private var quickInfoSection: some View {
        HStack(spacing: 20) {
            // Cost
            VStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("$\(Int(lesson.cost))")
                    .font(.headline)
                Text("per session")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 50)
            
            // Duration
            VStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("\(lesson.durationMinutes) min")
                    .font(.headline)
                Text("duration")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 50)
            
            // Subject
            VStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text(lesson.subject)
                    .font(.headline)
                    .lineLimit(1)
                Text("subject")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Instructor Section
    
    private var instructorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructor")
                .font(.headline)
            
            HStack(spacing: 16) {
                // Avatar
                Group {
                    if let avatarURL = lesson.instructor.avatar, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                defaultAvatar
                            }
                        }
                    } else {
                        defaultAvatar
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.instructor.name)
                        .font(.title3.bold())
                    
                    // Rating placeholder - will be enhanced in Phase 3
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < 4 ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        Text("(4.0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
            )
    }
    
    // MARK: - Description Section
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About This Lesson")
                .font(.headline)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
            
            Map(coordinateRegion: .constant(region), annotationItems: [MapLocation(coordinate: region.center)]) { location in
                MapMarker(coordinate: location.coordinate, tint: .purple)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Reviews Section
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reviews")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingReviewInput = true
                    HapticManager.shared.playLightImpact()
                } label: {
                    Text("Write a Review")
                        .font(.subheadline.bold())
                        .foregroundColor(.purple)
                }
            }
            
            ReviewListView(targetType: "lesson", targetId: String(lesson.id))
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Book Lesson Button
            Button {
                showingBooking = true
                HapticManager.shared.playMediumImpact()
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                    Text("Book Lesson")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            // Message Instructor Button
            Button {
                initiateChat()
            } label: {
                HStack {
                    Image(systemName: "message.fill")
                    Text("Message Instructor")
                }
                .font(.headline)
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func initiateChat() {
        HapticManager.shared.playLightImpact()
        // Create a new conversation with instructor context
        // This will be enhanced in Phase 4 with DirectMessageService
        showingChat = true
    }
}

// MARK: - Map Helper

private struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PrivateLessonDetailView(
            lesson: APIPrivateLesson(
                id: 1,
                title: "Advanced Piano Techniques",
                subject: "Music",
                instructor: APIUserPreview(id: 1, name: "Sarah Johnson", avatar: nil),
                cost: 75,
                durationMinutes: 60,
                description: "Master advanced piano techniques including arpeggios, scales, and complex chord progressions. Perfect for intermediate to advanced students looking to take their playing to the next level.",
                lat: 40.7128,
                lng: -74.0060,
                imageURL: nil
            )
        )
    }
}
