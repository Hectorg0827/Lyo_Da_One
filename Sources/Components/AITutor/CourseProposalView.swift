import SwiftUI

struct CourseProposalView: View {
    let data: CourseProposalData
    let onStartTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(data.summary)
                .padding().background(Color.gray.opacity(0.1))
                .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])
                .padding(.bottom, 16)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(data.title).font(.title3).fontWeight(.bold).foregroundColor(.white)
                        Text(data.subtext).font(.caption).foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "graduationcap.fill").foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(data.modules.prefix(3), id: \.self) { module in
                        HStack { Image(systemName: "circle.fill").font(.system(size: 4)); Text(module).font(.caption) }
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                Button(action: onStartTapped) {
                    HStack { Text(data.buttonText).fontWeight(.semibold); Spacer(); Image(systemName: "arrow.right") }
                        .padding().background(Color.white).foregroundColor(.blue).cornerRadius(12)
                }
            }
            .padding()
            .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(16).shadow(radius: 8)
        }
        .padding(.horizontal)
    }
}
