import SwiftUI

/// The same bounded fraction, comparison, sequence and graph activities as web/Android.
///
/// The body is deliberately split into small named pieces. As one expression —
/// a VStack wrapping an `if` wrapping a four-branch `switch`, every branch
/// several view-builders deep — it gave the type-checker a single constraint
/// system large enough that it gave up: "unable to type-check this expression
/// in reasonable time". Each piece below is solved independently, which is the
/// remedy the compiler itself suggests. The rendering is unchanged.
struct ClassroomTeachingVisualView: View {
    let visual: ClassroomTeachingVisual
    let onUpdate: ([String: Any]) -> Bool
    @State private var value: Int

    init(visual: ClassroomTeachingVisual, onUpdate: @escaping ([String: Any]) -> Bool) {
        self.visual = visual
        self.onUpdate = onUpdate
        _value = State(initialValue: visual.value)
    }

    private func change(_ next: Int) {
        if onUpdate(["value": next]) { value = next }
    }

    /// Arithmetic, `.formatted` and string concatenation in one expression is
    /// its own type-checking cost, so the steps are spelled out with explicit
    /// types rather than inferred through the chain.
    private var shadedAmount: String {
        let amount: Double = visual.whole * Double(value) / Double(visual.parts)
        let formatted: String = amount.formatted(.number.precision(.fractionLength(0...3)))
        return formatted + " " + visual.unit
    }

    private var progressLabel: String { "\(value)/\(visual.parts)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(visual.title).font(.headline).foregroundStyle(.white)
            Text(visual.caption).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            if visual.isValid {
                activity
            } else {
                Text(visual.description).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.cyan.opacity(0.2)))
    }

    private var cardBackground: LinearGradient {
        LinearGradient(colors: [.cyan.opacity(0.08), .purple.opacity(0.06)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder private var activity: some View {
        switch visual.kind {
        case "fraction_bar": fractionBar
        case "comparison", "sequence": entrySteps
        case "graph": graph
        default: EmptyView()
        }
    }

    // ── fraction_bar ─────────────────────────────────────────────────────────

    @ViewBuilder private var fractionBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(progressLabel).font(.system(.title, design: .rounded).bold()).foregroundStyle(.cyan)
            Spacer()
            Text(shadedAmount).font(.title3.monospacedDigit()).foregroundStyle(.white)
        }
        fractionSegments
        fractionSlider
    }

    private var fractionSegments: some View {
        HStack(spacing: 3) {
            ForEach(0..<visual.parts, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index < value ? Color.cyan.opacity(0.8) : Color.white.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.2)))
            }
        }
        .frame(height: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(visual.description)
        .accessibilityValue(progressLabel)
    }

    private var fractionSlider: some View {
        let binding = Binding<Double>(get: { Double(value) }, set: { change(Int($0)) })
        return Slider(value: binding, in: 0...Double(visual.parts), step: 1)
            .tint(.cyan)
            .frame(minHeight: 44)
            .accessibilityLabel(visual.title)
            .accessibilityValue(progressLabel)
    }

    // ── comparison / sequence ────────────────────────────────────────────────

    @ViewBuilder private var entrySteps: some View {
        ForEach(visual.entries.indices, id: \.self) { index in
            entryRow(index)
        }
        entryDetail
    }

    private func entryRow(_ index: Int) -> some View {
        let selected: Bool = index == value
        return Button { change(index) } label: {
            HStack(spacing: 12) {
                if visual.kind == "sequence" {
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.cyan)
                }
                Text(visual.entries[index].label).multilineTextAlignment(.leading)
                Spacer()
                if selected { Image(systemName: "arrow.right").foregroundStyle(.cyan) }
            }
            .padding(12)
            .frame(minHeight: 48)
            .background(selected ? Color.cyan.opacity(0.12) : Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var entryDetail: some View {
        Text(visual.entries[value].detail)
            .font(.body)
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    // ── graph ────────────────────────────────────────────────────────────────

    private var graph: some View {
        let config = ExplorableConfig(kind: "curve_explorer", expression: visual.expression,
                                      xMin: visual.xMin, xMax: visual.xMax,
                                      prompt: nil, params: visual.params)
        return CurveExplorerView(config: config,
                                 onValuesChange: { params in _ = onUpdate(["params": params]) },
                                 yBounds: visual.yMin...visual.yMax)
    }
}
