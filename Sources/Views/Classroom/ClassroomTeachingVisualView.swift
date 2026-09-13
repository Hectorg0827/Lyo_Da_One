import SwiftUI

/// The same bounded fraction, comparison, sequence and graph activities as web/Android.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(visual.title).font(.headline).foregroundStyle(.white)
            Text(visual.caption).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            if visual.isValid {
                switch visual.kind {
                case "fraction_bar":
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(value)/\(visual.parts)").font(.system(.title, design: .rounded).bold()).foregroundStyle(.cyan)
                        Spacer()
                        Text((visual.whole * Double(value) / Double(visual.parts)).formatted(.number.precision(.fractionLength(0...3))) + " " + visual.unit)
                            .font(.title3.monospacedDigit()).foregroundStyle(.white)
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
                    .accessibilityValue("\(value)/\(visual.parts)")
                    Slider(value: Binding(get: { Double(value) }, set: { change(Int($0)) }), in: 0...Double(visual.parts), step: 1)
                        .tint(.cyan)
                        .frame(minHeight: 44)
                        .accessibilityLabel(visual.title)
                        .accessibilityValue("\(value)/\(visual.parts)")
                case "comparison", "sequence":
                    ForEach(visual.entries.indices, id: \.self) { index in
                        Button { change(index) } label: {
                            HStack(spacing: 12) {
                                if visual.kind == "sequence" { Text("\(index + 1)").monospacedDigit().foregroundStyle(.cyan) }
                                Text(visual.entries[index].label).multilineTextAlignment(.leading)
                                Spacer()
                                if index == value { Image(systemName: "arrow.right").foregroundStyle(.cyan) }
                            }
                            .padding(12).frame(minHeight: 48)
                            .background(index == value ? Color.cyan.opacity(0.12) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(index == value ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(index == value ? [.isSelected] : [])
                    }
                    Text(visual.entries[value].detail).font(.body).foregroundStyle(.white).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                case "graph":
                    CurveExplorerView(config: ExplorableConfig(kind: "curve_explorer", expression: visual.expression,
                        xMin: visual.xMin, xMax: visual.xMax, prompt: nil, params: visual.params),
                        onValuesChange: { params in _ = onUpdate(["params": params]) },
                        yBounds: visual.yMin...visual.yMax)
                default: EmptyView()
                }
            } else {
                Text(visual.description).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.cyan.opacity(0.08), .purple.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.cyan.opacity(0.2)))
    }
}
