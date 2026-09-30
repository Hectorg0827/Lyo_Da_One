import SwiftUI

/// Bounded teaching visuals shared with web/Android. Exploration changes the
/// representation only; a separate server checkpoint is the only graded action.
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
        .accessibilityElement(children: .contain)
    }

    private var cardBackground: LinearGradient {
        LinearGradient(colors: [.cyan.opacity(0.08), .purple.opacity(0.06)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder private var activity: some View {
        switch visual.kind {
        case "fraction_bar": fractionBar
        case "comparison", "sequence": entrySteps
        case "process_flow": processFlow
        case "timeline": timeline
        case "number_line": numberLine
        case "annotated_image": annotatedImage
        case "graph": graph
        default: EmptyView()
        }
    }

    // MARK: - Fraction

    @ViewBuilder private var fractionBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(progressLabel).font(.system(.title, design: .rounded).bold()).foregroundStyle(.cyan)
            Spacer()
            Text(shadedAmount).font(.title3.monospacedDigit()).foregroundStyle(.white)
        }
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

        let binding = Binding<Double>(get: { Double(value) }, set: { change(Int($0)) })
        Slider(value: binding, in: 0...Double(visual.parts), step: 1)
            .tint(.cyan)
            .frame(minHeight: 44)
            .accessibilityLabel(visual.title)
            .accessibilityValue(progressLabel)
    }

    // MARK: - Lists

    @ViewBuilder private var entrySteps: some View {
        ForEach(visual.entries.indices, id: \.self) { index in
            entryRow(index, numbered: visual.kind == "sequence")
        }
        entryDetail
    }

    private func entryRow(_ index: Int, numbered: Bool) -> some View {
        let selected: Bool = index == value
        return Button { change(index) } label: {
            HStack(spacing: 12) {
                if numbered {
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.cyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(visual.entries[index].label).fontWeight(.medium)
                    if selected {
                        Text(visual.entries[index].detail)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
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

    // MARK: - Process flow

    @ViewBuilder private var processFlow: some View {
        VStack(spacing: 6) {
            ForEach(visual.entries.indices, id: \.self) { index in
                entryRow(index, numbered: false)
                if index < visual.entries.count - 1 {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.cyan.opacity(0.7))
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: - Timeline

    @ViewBuilder private var timeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(visual.entries.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(index == value ? Color.cyan : Color.white.opacity(0.2))
                            .frame(width: 16, height: 16)
                        if index < visual.entries.count - 1 {
                            Rectangle().fill(Color.cyan.opacity(0.25)).frame(width: 2, height: 52)
                        }
                    }
                    entryRow(index, numbered: false)
                }
            }
        }
    }

    // MARK: - Number line

    private var numberLine: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(height: 2)
                        .position(x: proxy.size.width / 2, y: 38)

                    ForEach(visual.entries.indices, id: \.self) { index in
                        if let position = visual.entries[index].position {
                            let ratio = (position - visual.xMin) / (visual.xMax - visual.xMin)
                            let x = max(14, min(proxy.size.width - 14, ratio * proxy.size.width))
                            Button { change(index) } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(index == value ? Color.cyan : Color.black.opacity(0.8))
                                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
                                        .frame(width: 24, height: 24)
                                    Text(visual.entries[index].label)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.white)
                                        .fixedSize()
                                }
                            }
                            .buttonStyle(.plain)
                            .position(x: x, y: 38)
                        }
                    }
                    Text(visual.xMin.formatted()).font(.caption2.monospaced()).foregroundStyle(.white.opacity(0.6))
                        .position(x: 18, y: 84)
                    Text(visual.xMax.formatted()).font(.caption2.monospaced()).foregroundStyle(.white.opacity(0.6))
                        .position(x: max(18, proxy.size.width - 18), y: 84)
                }
            }
            .frame(height: 96)
            entryDetail
        }
        .accessibilityLabel(visual.description)
    }

    // MARK: - Real image + annotations

    @ViewBuilder private var annotatedImage: some View {
        if let raw = visual.imageUrl, let url = URL(string: raw) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else if phase.error != nil {
                            Color.white.opacity(0.05)
                                .overlay(Text(visual.description).font(.caption).foregroundStyle(.white.opacity(0.8)).padding())
                        } else {
                            ProgressView().tint(.cyan)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    ForEach(visual.entries.indices, id: \.self) { index in
                        if let x = visual.entries[index].x, let y = visual.entries[index].y {
                            Button { change(index) } label: {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(index == value ? .black : .white)
                                    .frame(width: 30, height: 30)
                                    .background(index == value ? Color.cyan : Color.black.opacity(0.75), in: Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .position(x: x * proxy.size.width, y: y * proxy.size.height)
                            .accessibilityLabel(visual.entries[index].label)
                        }
                    }
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Text(visual.description)
                .foregroundStyle(.white.opacity(0.85))
                .padding(12)
                .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        }

        if !visual.entries.isEmpty {
            ForEach(visual.entries.indices, id: \.self) { index in
                entryRow(index, numbered: true)
            }
        }

        if let attribution = visual.attribution {
            if let raw = visual.sourceUrl, let url = URL(string: raw) {
                Link(attribution, destination: url)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                Text(attribution).font(.caption2).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Graph

    private var graph: some View {
        let config = ExplorableConfig(kind: "curve_explorer", expression: visual.expression,
                                      xMin: visual.xMin, xMax: visual.xMax,
                                      prompt: nil, params: visual.params)
        return CurveExplorerView(config: config,
                                 onValuesChange: { params in _ = onUpdate(["params": params]) },
                                 yBounds: visual.yMin...visual.yMax)
    }
}
