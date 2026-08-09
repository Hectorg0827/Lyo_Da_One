import SwiftUI

/// A monospaced, horizontally-scrollable code block used by chat's
/// `.codeSnippet` message kind (see MessageBubbleView.swift).
///
/// Restored here as its own file after being lost in an earlier dead-code
/// removal pass: it previously lived in Components/Classroom/
/// ModuleCardComponents.swift, which was deleted as confirmed-dead — that
/// verification checked the file's own view structs for live callers but
/// missed that this one nested type was still depended on by this
/// unrelated, genuinely-live chat file. No Swift compiler was available
/// in-session to catch the resulting break; real CI did.
struct CodeSnippetView: View {
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 12))
                Text("Code")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .foregroundColor(Color("LyoAccent"))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.5))
            )
        }
    }
}
