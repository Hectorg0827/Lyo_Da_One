import SwiftUI

// MARK: - Safe Expression Evaluator

/// Tiny recursive-descent evaluator for classroom explorables.
/// Grammar: + - * / ^ ( ), numbers, variables (x + named params), and the
/// functions sin, cos, tan, exp, log, ln, sqrt, abs. Pure math — nothing here
/// executes code, so LLM-authored expressions are safe to evaluate.
enum ExpressionEvaluator {

    /// Parses once into a closure you can evaluate repeatedly (per pixel).
    static func compile(_ expression: String) -> (([String: Double]) -> Double?)? {
        var parser = Parser(text: expression)
        guard let node = parser.parseExpression(), parser.isAtEnd else { return nil }
        return { vars in node.eval(vars) }
    }

    private indirect enum Node {
        case number(Double)
        case variable(String)
        case unary(String, Node)
        case binary(Character, Node, Node)

        func eval(_ vars: [String: Double]) -> Double? {
            switch self {
            case .number(let v): return v
            case .variable(let name): return vars[name]
            case .unary(let fn, let inner):
                guard let v = inner.eval(vars) else { return nil }
                switch fn {
                case "sin": return sin(v)
                case "cos": return cos(v)
                case "tan": return tan(v)
                case "exp": return exp(v)
                case "log", "ln": return v > 0 ? Foundation.log(v) : nil
                case "sqrt": return v >= 0 ? v.squareRoot() : nil
                case "abs": return Swift.abs(v)
                case "neg": return -v
                default: return nil
                }
            case .binary(let op, let l, let r):
                guard let a = l.eval(vars), let b = r.eval(vars) else { return nil }
                switch op {
                case "+": return a + b
                case "-": return a - b
                case "*": return a * b
                case "/": return b == 0 ? nil : a / b
                case "^": return pow(a, b)
                default: return nil
                }
            }
        }
    }

    private struct Parser {
        let chars: [Character]
        var pos = 0

        init(text: String) {
            // Normalize common LLM syntax: implicit "**" power → "^"
            chars = Array(text.replacingOccurrences(of: "**", with: "^").filter { $0 != " " })
        }

        var isAtEnd: Bool { pos >= chars.count }
        private func peek() -> Character? { pos < chars.count ? chars[pos] : nil }
        private mutating func advance() -> Character? {
            guard pos < chars.count else { return nil }
            defer { pos += 1 }
            return chars[pos]
        }

        mutating func parseExpression() -> Node? {
            guard var lhs = parseTerm() else { return nil }
            while let c = peek(), c == "+" || c == "-" {
                pos += 1
                guard let rhs = parseTerm() else { return nil }
                lhs = .binary(c, lhs, rhs)
            }
            return lhs
        }

        private mutating func parseTerm() -> Node? {
            guard var lhs = parseUnary() else { return nil }
            while let c = peek(), c == "*" || c == "/" {
                pos += 1
                guard let rhs = parseUnary() else { return nil }
                lhs = .binary(c, lhs, rhs)
            }
            return lhs
        }

        // Unary minus binds LOOSER than ^ (math convention: -x^2 == -(x^2)),
        // while exponents may themselves be signed (x^-2).
        private mutating func parseUnary() -> Node? {
            if peek() == "-" {
                pos += 1
                guard let inner = parseUnary() else { return nil }
                return .unary("neg", inner)
            }
            if peek() == "+" { pos += 1 }
            return parsePower()
        }

        private mutating func parsePower() -> Node? {
            guard let base = parseAtom() else { return nil }
            if peek() == "^" {
                pos += 1
                guard let exponent = parseUnary() else { return nil }  // right-assoc
                return .binary("^", base, exponent)
            }
            return base
        }

        private mutating func parseAtom() -> Node? {
            guard let c = peek() else { return nil }

            if c == "(" {
                pos += 1
                guard let inner = parseExpression(), peek() == ")" else { return nil }
                pos += 1
                return inner
            }

            if c.isNumber || c == "." {
                var s = ""
                while let ch = peek(), ch.isNumber || ch == "." { s.append(ch); pos += 1 }
                return Double(s).map(Node.number)
            }

            if c.isLetter {
                var name = ""
                while let ch = peek(), ch.isLetter || ch.isNumber || ch == "_" {
                    name.append(ch); pos += 1
                }
                let functions = ["sin", "cos", "tan", "exp", "log", "ln", "sqrt", "abs"]
                if functions.contains(name), peek() == "(" {
                    pos += 1
                    guard let arg = parseExpression(), peek() == ")" else { return nil }
                    pos += 1
                    return .unary(name, arg)
                }
                if name == "pi" { return .number(.pi) }
                if name == "e" { return .number(M_E) }
                return .variable(name)
            }

            return nil
        }
    }
}

// MARK: - Curve Explorer

/// An interactive manipulable: sliders bound to named parameters of a curve
/// that redraws live. The learner *feels* the concept instead of reading it.
struct CurveExplorerView: View {
    let config: ExplorableConfig
    /// Fired once after the learner's first manipulation — an engagement signal.
    var onExplored: (() -> Void)?

    @State private var values: [String: Double] = [:]
    @State private var hasExplored = false

    private var evaluator: (([String: Double]) -> Double?)? {
        ExpressionEvaluator.compile(config.expression)
    }

    private var xMin: Double { config.xMin ?? -5 }
    private var xMax: Double { max((config.xMax ?? 5), xMin + 0.1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.below.sunglasses")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purple)
                Text("Try it yourself")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                Spacer()
                Text(config.expression)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            plot
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            ForEach(config.params, id: \.name) { param in
                slider(for: param)
            }

            if let prompt = config.prompt, !prompt.isEmpty {
                Label(prompt, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hexString: "FFFFFF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                )
        )
        .onAppear {
            if values.isEmpty {
                for p in config.params { values[p.name] = p.initial }
            }
        }
    }

    // MARK: Plot

    private var plot: some View {
        Canvas { context, size in
            let bg = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 0)
            context.fill(bg, with: .color(Color(hexString: "F8FAFC")))

            guard let eval = evaluator else {
                let text = Text("Could not read expression").font(.caption).foregroundColor(.secondary)
                context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }

            // Sample the curve.
            let sampleCount = max(Int(size.width / 2), 60)
            var samples: [(x: Double, y: Double)] = []
            for i in 0...sampleCount {
                let x = xMin + (xMax - xMin) * Double(i) / Double(sampleCount)
                var vars = values
                vars["x"] = x
                if let y = eval(vars), y.isFinite { samples.append((x, y)) }
            }
            guard samples.count > 1 else { return }

            // Y-window: robust bounds with a little padding.
            let ys = samples.map(\.y).sorted()
            let loIdx = ys.count / 20, hiIdx = ys.count - 1 - ys.count / 20
            var yLo = ys[loIdx], yHi = ys[hiIdx]
            if yHi - yLo < 1e-6 { yLo -= 1; yHi += 1 }
            let yPad = (yHi - yLo) * 0.15
            yLo -= yPad; yHi += yPad

            func point(_ s: (x: Double, y: Double)) -> CGPoint {
                CGPoint(
                    x: (s.x - xMin) / (xMax - xMin) * size.width,
                    y: size.height - (s.y - yLo) / (yHi - yLo) * size.height
                )
            }

            // Axes (only when inside the window).
            var axes = Path()
            if yLo < 0, yHi > 0 {
                let y0 = size.height - (0 - yLo) / (yHi - yLo) * size.height
                axes.move(to: CGPoint(x: 0, y: y0))
                axes.addLine(to: CGPoint(x: size.width, y: y0))
            }
            if xMin < 0, xMax > 0 {
                let x0 = (0 - xMin) / (xMax - xMin) * size.width
                axes.move(to: CGPoint(x: x0, y: 0))
                axes.addLine(to: CGPoint(x: x0, y: size.height))
            }
            context.stroke(axes, with: .color(Color(hexString: "CBD5E1")), lineWidth: 1)

            // The curve — split at discontinuities (large sample gaps).
            var curve = Path()
            var previous: (x: Double, y: Double)?
            for s in samples {
                let p = point(s)
                if let prev = previous,
                    Swift.abs(s.y - prev.y) < (yHi - yLo) * 2 {
                    curve.addLine(to: p)
                } else {
                    curve.move(to: p)
                }
                previous = s
            }
            context.stroke(
                curve,
                with: .color(Color(hexString: "6366F1")),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: Sliders

    private func slider(for param: ExplorableConfig.ExplorableParam) -> some View {
        let binding = Binding<Double>(
            get: { values[param.name] ?? param.initial },
            set: { newValue in
                values[param.name] = newValue
                if !hasExplored {
                    hasExplored = true
                    onExplored?()
                }
            }
        )
        return HStack(spacing: 10) {
            Text(param.name)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundColor(Color(hexString: "4B5563"))
                .frame(width: 28, alignment: .leading)
            Slider(value: binding, in: param.min...max(param.max, param.min + 0.001), step: param.step ?? 0.1)
                .tint(Color(hexString: "8B5CF6"))
            Text(String(format: "%.2f", binding.wrappedValue))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

#Preview {
    CurveExplorerView(
        config: ExplorableConfig(
            kind: "curve_explorer",
            expression: "a * x^2 + b * x",
            xMin: -5, xMax: 5,
            prompt: "Increase a — what happens to how steep the curve is?",
            params: [
                .init(name: "a", min: -3, max: 3, initial: 1, step: 0.1),
                .init(name: "b", min: -5, max: 5, initial: 0, step: 0.1),
            ]
        )
    )
    .padding()
}
