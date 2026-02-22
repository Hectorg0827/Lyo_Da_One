import SwiftUI

struct SharedCourseCard: View {
    let course: APISharedCourse
    var onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail & Badges
                ZStack(alignment: .topTrailing) {
                    if let urlString = course.thumbnailURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray5))
                        }
                        .frame(height: 140)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 140)
                            .overlay(
                                Image(systemName: "graduationcap.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                    
                    // Difficulty Badge
                    Text(course.difficulty.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(10)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        if let avatar = course.creator.avatar, let url = URL(string: avatar) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(Color.gray)
                            }
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.gray)
                        }
                        
                        Text(course.creator.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("\(course.rating, specifier: "%.1f")", systemImage: "star.fill")
                            .foregroundColor(.yellow)
                        
                        Spacer()
                        
                        Text("\(course.enrollments) students")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption.bold())
                }
                .padding(12)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
