import SwiftUI

struct QuickExplainerView: View {
    let data: QuickExplainerData
    let onChipTapped: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(data.concept).font(.headline)
                Spacer()
                Text("Quick Explainer")
                    .font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(8)
            }
            Text(data.explanation).font(.body).foregroundColor(.secondary)
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(data.chips, id: \.self) { chip in
                        Button(action: { onChipTapped(chip) }) {
                            Text(chip)
                                .font(.subheadline).fontWeight(.medium)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1)).foregroundColor(.primary).cornerRadius(16)
                        }
                    }
                }
            }
        }
        .padding().background(Color(UIColor.systemBackground)).cornerRadius(16).shadow(radius: 2)
    }
}
