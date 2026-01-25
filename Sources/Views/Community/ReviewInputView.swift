//
//  ReviewInputView.swift
//  Lyo
//
//  Sheet for submitting a new review
//

import SwiftUI

struct ReviewInputView: View {
    let targetId: String
    let targetType: String
    let targetName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var rating = 0
    @State private var text = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("How was your experience with\n\(targetName)?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                
                // Star Rating
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                withAnimation {
                                    rating = star
                                }
                                HapticManager.shared.playLightImpact()
                            }
                    }
                }
                
                // Text Input
                VStack(alignment: .leading) {
                    Text("Write a review (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $text)
                        .frame(height: 120)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReview()
                    }
                    .fontWeight(.bold)
                    .disabled(rating == 0 || isSubmitting)
                }
            }
        }
    }
    
    private func submitReview() {
        isSubmitting = true
        HapticManager.shared.playMediumImpact()
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            HapticManager.shared.playSuccess()
            dismiss()
        }
    }
}

#Preview {
    ReviewInputView(targetId: "1", targetType: "lesson", targetName: "Advanced Piano")
}
