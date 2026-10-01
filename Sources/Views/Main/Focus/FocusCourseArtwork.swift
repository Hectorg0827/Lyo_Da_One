import SwiftUI

// MARK: - Generated course artwork
//
// Cover art for a saved course, drawn from the course's own subject.
//
// A course can exist seconds after a learner asks Lio for it, so there is no
// moment at which an uploaded cover image could have arrived. The alternatives
// were an empty grey thumbnail or a stock picture that has nothing to do with
// the subject; this draws bonds for chemistry, speech arcs for a language, a
// distribution for statistics, and so on, and it is the same art every launch
// because `FocusPresentation.stableHash` does not move.
//
// Everything here is a `Canvas`: no assets, no network, nothing to moderate.

struct FocusCourseArtwork: View {
    let title: String

    private var motif: FocusArtMotif { FocusPresentation.motif(forTitle: title) }

    var body: some View {
        Canvas { context, size in
            draw(motif: motif, in: &context, size: size)
        }
        .background(palette.base)
        .drawingGroup()
        .accessibilityHidden(true)
    }

    // MARK: - Palette

    private struct Palette {
        let base: LinearGradient
        let ink: Color
        let glow: Color
    }

    private var palette: Palette {
        switch motif {
        case .lattice:
            return Palette(
                base: gradient("3B2A7A", "241A52", "140F2E"),
                ink: Color(hex: "C4AEFF"),
                glow: Color(hex: "A97BFF")
            )
        case .speech:
            return Palette(
                base: gradient("6B1F62", "3C1550", "1A0F2E"),
                ink: Color(hex: "FFC9EC"),
                glow: Color(hex: "FF8FD4")
            )
        case .curve:
            return Palette(
                base: gradient("123C66", "12274F", "0D1430"),
                ink: Color(hex: "9BD8FF"),
                glow: Color(hex: "5BB8F5")
            )
        case .staff:
            return Palette(
                base: gradient("5A3410", "35210F", "1C1226"),
                ink: Color(hex: "FFE6B8"),
                glow: Color(hex: "FFC266")
            )
        case .grid:
            return Palette(
                base: gradient("1E2A6E", "16205A", "0E1230"),
                ink: Color(hex: "A9BEFF"),
                glow: Color(hex: "7B93FF")
            )
        case .orbit:
            return Palette(
                base: gradient("13405A", "14304A", "0C1326"),
                ink: Color(hex: "A8F2D4"),
                glow: Color(hex: "4FD6A8")
            )
        }
    }

    private func gradient(_ a: String, _ b: String, _ c: String) -> LinearGradient {
        LinearGradient(
            colors: [Color(hex: a), Color(hex: b), Color(hex: c)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Drawing

    private func draw(motif: FocusArtMotif, in context: inout GraphicsContext, size: CGSize) {
        let ink = palette.ink
        let glow = palette.glow

        // A soft light source in the top-right corner, so every motif sits on
        // the same lighting rather than looking like five unrelated pictures.
        let bloom = Path(ellipseIn: CGRect(
            x: size.width * 0.42, y: -size.height * 0.62,
            width: size.width * 1.1, height: size.height * 1.5
        ))
        context.fill(bloom, with: .radialGradient(
            Gradient(colors: [glow.opacity(0.38), glow.opacity(0)]),
            center: CGPoint(x: size.width * 0.97, y: size.height * 0.1),
            startRadius: 0,
            endRadius: max(size.width, size.height) * 0.9
        ))

        switch motif {
        case .lattice: drawLattice(&context, size, ink)
        case .speech: drawSpeech(&context, size, ink)
        case .curve: drawCurve(&context, size, ink, glow)
        case .staff: drawStaff(&context, size, ink)
        case .grid: drawGrid(&context, size, ink)
        case .orbit: drawOrbit(&context, size, ink)
        }
    }

    /// Fused six-rings, the way a mechanism is actually drawn on a board.
    private func drawLattice(_ context: inout GraphicsContext, _ size: CGSize, _ ink: Color) {
        let radius = size.height * 0.17
        let stepX = radius * 1.5
        let stepY = radius * 0.866
        var centres: [CGPoint] = []

        var row = 0
        var y = size.height * 0.26
        while y < size.height * 1.05 {
            var x = row.isMultiple(of: 2) ? size.width * 0.14 : size.width * 0.14 + stepX
            while x < size.width * 1.05 {
                centres.append(CGPoint(x: x, y: y))
                x += stepX * 2
            }
            y += stepY * 2
            row += 1
        }

        for centre in centres {
            var path = Path()
            for corner in 0..<6 {
                let angle = Double(corner) * .pi / 3 - .pi / 6
                let point = CGPoint(
                    x: centre.x + radius * cos(angle),
                    y: centre.y + radius * sin(angle)
                )
                corner == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
            context.stroke(path, with: .color(ink.opacity(0.34)), lineWidth: 1.4)
            context.fill(
                Path(ellipseIn: CGRect(x: centre.x - 2.6, y: centre.y - 2.6, width: 5.2, height: 5.2)),
                with: .color(ink.opacity(0.5))
            )
        }
    }

    /// Speech radiating from the bottom-left, with a short waveform beside it.
    private func drawSpeech(_ context: inout GraphicsContext, _ size: CGSize, _ ink: Color) {
        let origin = CGPoint(x: size.width * 0.1, y: size.height * 0.94)
        var radius = size.height * 0.16
        while radius < size.height * 1.5 {
            let rect = CGRect(
                x: origin.x - radius, y: origin.y - radius,
                width: radius * 2, height: radius * 2
            )
            let fade = 0.3 - (radius / (size.height * 6))
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(ink.opacity(max(fade, 0.05))),
                lineWidth: 1.3
            )
            radius += size.height * 0.145
        }

        let heights: [CGFloat] = [0.08, 0.2, 0.12, 0.3, 0.17, 0.38, 0.22, 0.14, 0.32, 0.18]
        let barWidth: CGFloat = 3.4
        let gap = size.width * 0.042
        var x = size.width * 0.54
        let midY = size.height * 0.68
        for factor in heights {
            let height = size.height * factor
            let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
            context.fill(
                Path(roundedRect: rect, cornerRadius: barWidth / 2),
                with: .color(ink.opacity(0.46))
            )
            x += gap
        }
    }

    /// A distribution with its scatter sitting on the curve.
    private func drawCurve(_ context: inout GraphicsContext, _ size: CGSize, _ ink: Color, _ glow: Color) {
        let baseline = size.height * 0.8
        let peak = size.height * 0.2
        let left = size.width * 0.02
        let right = size.width * 0.98
        let mid = (left + right) / 2

        var curve = Path()
        curve.move(to: CGPoint(x: left, y: baseline))
        curve.addCurve(
            to: CGPoint(x: mid, y: peak),
            control1: CGPoint(x: left + (mid - left) * 0.52, y: baseline),
            control2: CGPoint(x: mid - (mid - left) * 0.42, y: peak)
        )
        curve.addCurve(
            to: CGPoint(x: right, y: baseline),
            control1: CGPoint(x: mid + (right - mid) * 0.42, y: peak),
            control2: CGPoint(x: right - (right - mid) * 0.52, y: baseline)
        )

        var fill = curve
        fill.addLine(to: CGPoint(x: left, y: baseline))
        fill.closeSubpath()
        context.fill(fill, with: .linearGradient(
            Gradient(colors: [glow.opacity(0.4), glow.opacity(0.02)]),
            startPoint: CGPoint(x: mid, y: peak),
            endPoint: CGPoint(x: mid, y: baseline)
        ))
        context.stroke(curve, with: .color(ink.opacity(0.72)), lineWidth: 2)

        var axis = Path()
        axis.move(to: CGPoint(x: left, y: baseline))
        axis.addLine(to: CGPoint(x: right, y: baseline))
        context.stroke(axis, with: .color(ink.opacity(0.3)), lineWidth: 1.3)

        var ticks = Path()
        var x = left + size.width * 0.08
        while x < right {
            ticks.move(to: CGPoint(x: x, y: baseline))
            ticks.addLine(to: CGPoint(x: x, y: baseline + size.height * 0.035))
            x += size.width * 0.09
        }
        context.stroke(ticks, with: .color(ink.opacity(0.28)), lineWidth: 1.2)

        // Points placed on the curve itself, so the chart is not a decoration
        // that contradicts its own data.
        for step in 1..<10 {
            let t = CGFloat(step) / 10
            let px = left + (right - left) * t
            let normalised = (px - mid) / ((right - left) * 0.3)
            let py = baseline - (baseline - peak) * exp(-0.5 * normalised * normalised)
            context.fill(
                Path(ellipseIn: CGRect(x: px - 2.6, y: py - 2.6, width: 5.2, height: 5.2)),
                with: .color(ink.opacity(0.75))
            )
        }
    }

    /// Five staves with noteheads sitting on them.
    private func drawStaff(_ context: inout GraphicsContext, _ size: CGSize, _ ink: Color) {
        let top = size.height * 0.3
        let spacing = size.height * 0.1
        var lines = Path()
        for line in 0..<5 {
            let y = top + CGFloat(line) * spacing
            lines.move(to: CGPoint(x: size.width * 0.04, y: y))
            lines.addLine(to: CGPoint(x: size.width * 0.96, y: y))
        }
        context.stroke(lines, with: .color(ink.opacity(0.3)), lineWidth: 1.3)

        // Half-steps included, so noteheads land on lines and in spaces.
        let steps: [CGFloat] = [2, 0.5, 3, 1.5, 4, 2.5, 1, 3.5]
        var x = size.width * 0.12
        for step in steps {
            let y = top + step * spacing
            let rect = CGRect(x: x - 7.5, y: y - 5.2, width: 15, height: 10.4)
            context.rotate(by: .degrees(-18))
            context.fill(Path(ellipseIn: rect), with: .color(ink.opacity(0.55)))
            context.rotate(by: .degrees(18))
            x += size.width * 0.112
        }
    }

    /// Axes with a vector triangle over them.
    private func drawGrid(_ context: inout GraphicsContext, _ size: CGSize, _ ink: Color) {
        var grid = Path()
        var x = size.width * 0.06
        while x < size.width {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            x += size.width * 0.1
        }
        var y = size.height * 0.08
        while y < size.height {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
            y += size.height * 0.16
        }
        context.stroke(grid, with: .color(ink.opacity(0.16)), lineWidth: 1)

        var vectors = Path()
        let a = CGPoint(x: size.width * 0.15, y: size.height * 0.82)
        let b = CGPoint(x: size.width * 0.54, y: size.height * 0.26)
        let c = CGPoint(x: size.width * 0.62, y: size.height * 0.9)
        vectors.move(to: a)
        vectors.addLine(to: b)
        vectors.addLine(to: c)
        vectors.closeSubpath()
        context.fill(vectors, with: .color(ink.opacity(0.12)))
        context.stroke(vectors, with: .color(ink.opacity(0.58)), lineWidth: 2)

        for point in [a, b, c] {
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                with: .color(ink.opacity(0.8))
            )
        }
    }

    /// Concentric paths with a body on each — the general-purpose motif.
    private func drawOrbit(_ context: inout GraphicsContext, _ size: CGSize, _ ink: Color) {
        let centre = CGPoint(x: size.width * 0.72, y: size.height * 0.52)
        var radius = size.height * 0.16
        var index = 0
        while radius < size.height * 0.9 {
            let rect = CGRect(
                x: centre.x - radius * 1.35, y: centre.y - radius,
                width: radius * 2.7, height: radius * 2
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(ink.opacity(0.26)),
                lineWidth: 1.3
            )
            let angle = Double(index) * 1.9
            let body = CGPoint(
                x: centre.x + radius * 1.35 * cos(angle),
                y: centre.y + radius * sin(angle)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: body.x - 3.4, y: body.y - 3.4, width: 6.8, height: 6.8)),
                with: .color(ink.opacity(0.7))
            )
            radius += size.height * 0.19
            index += 1
        }
    }
}
