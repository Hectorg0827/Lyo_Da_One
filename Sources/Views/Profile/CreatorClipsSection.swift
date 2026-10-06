import SwiftUI

/// A creator's own clips, and what they have added up to.
///
/// The economy comes later; this is the part that has to exist first. Nobody
/// keeps making videos for a feed that never tells them whether anyone
/// watched, and until now nothing in the app showed a creator a single number
/// about their own work.
///
/// What it will not do is make a figure up. Every count on a clip is optional,
/// so a total says how much of the library it actually covers, and a metric no
/// clip reported reads "Not reported" rather than 0 — a creator whose views
/// are not being counted needs to know that, not be told nobody watched. The
/// branching lives in `CreatorStats`, which is unit-tested.
struct CreatorClipsSection: View {
    @State private var clips: [Clip] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    private var totals: [CreatorMetric: CreatorTotal] { CreatorStats.totals(for: clips) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your clips")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if loadFailed {
                notice("Your clips could not be loaded.")
            } else if clips.isEmpty {
                notice("Teach something in 60 seconds and it shows up here — with how many people watched it.")
            } else {
                statGrid
                Text(clips.count == 1 ? "1 clip" : "\(clips.count) clips")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.45))
                clipList
            }
        }
        .task { await load() }
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(CreatorMetric.allCases) { metric in
                let total = totals[metric]
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.45))

                    if let total, total.isReported {
                        Text("\(total.value)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    } else {
                        // Not a zero. No clip reported this figure, and telling
                        // a creator nobody watched would be a different claim.
                        Text("Not reported")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    if let note = total?.coverageNote {
                        Text(note)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var clipList: some View {
        VStack(spacing: 8) {
            ForEach(clips) { clip in
                HStack(spacing: 10) {
                    Text(clip.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    // Nil views is not zero views.
                    Text(clip.viewCount.map { "\($0) views" } ?? "Views not reported")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
    }

    private func load() async {
        isLoading = true
        loadFailed = false
        do {
            clips = try await ClipService.shared.getMyClips(page: 1, perPage: 50)
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}
