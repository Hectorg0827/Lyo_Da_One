import SwiftUI

public struct DiagramCardView: View {
    let card: DiagramCard
    let palette: LyoLessonPalette
    
    @State private var visibleNodes: Set<String> = []
    
    // Auto-layout computation
    @State private var nodePositions: [String: CGPoint] = [:]
    
    // Interaction states
    @State private var establishedConnections: Set<String> = [] // sourceId-targetId
    @State private var dragPosition: CGPoint? = nil
    @State private var dragSourceId: String? = nil
    
    public init(card: DiagramCard, palette: LyoLessonPalette) {
        self.card = card
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            // Background Layer
            AnimatedMeshBackground(palette: palette, phase: 0)
                .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.backgroundDepth))

            GeometryReader { geo in
                diagramContent(in: geo)
            }
            .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.foregroundDepth))
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Extracted subviews

    @ViewBuilder
    private func diagramContent(in geo: GeometryProxy) -> some View {
        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
        let radius: CGFloat = min(geo.size.width, geo.size.height) * 0.35

        ZStack {
            connectionsCanvas(size: geo.size)
            nodesLayer(center: center, radius: radius)
        }
    }

    private func connectionsCanvas(size: CGSize) -> some View {
        Canvas { context, _ in
            drawEstablishedConnections(context: context)
            drawActiveDragLine(context: context)
        }
        .frame(width: size.width, height: size.height)
    }

    private func drawEstablishedConnections(context: GraphicsContext) {
        for connection in card.connections {
            let key = "\(connection.sourceId)-\(connection.targetId)"
            guard establishedConnections.contains(key),
                  let sourcePos = nodePositions[connection.sourceId],
                  let targetPos = nodePositions[connection.targetId] else { continue }

            var path = Path()
            path.move(to: sourcePos)
            path.addLine(to: targetPos)

            context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 4)
        }
    }

    private func drawActiveDragLine(context: GraphicsContext) {
        guard let activeDragSourceId = dragSourceId,
              let sourcePos = nodePositions[activeDragSourceId],
              let dragPos = dragPosition else { return }

        var path = Path()
        path.move(to: sourcePos)
        path.addLine(to: dragPos)

        context.stroke(
            path,
            with: .color(.white.opacity(0.5)),
            style: StrokeStyle(lineWidth: 3, dash: [6, 6])
        )
    }

    @ViewBuilder
    private func nodesLayer(center: CGPoint, radius: CGFloat) -> some View {
        let nodeCount = CGFloat(card.nodes.count)
        let accentColor = Color(hex: palette.color2Hex)

        ForEach(Array(card.nodes.enumerated()), id: \.element.id) { index, node in
            let angle = (2 * .pi / nodeCount) * CGFloat(index) - .pi / 2
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            diagramNodeItem(node: node, x: x, y: y, accentColor: accentColor)
        }
    }

    @ViewBuilder
    private func diagramNodeItem(node: DiagramNode, x: CGFloat, y: CGFloat, accentColor: Color) -> some View {
        DiagramNodeView(
            node: node,
            isVisible: visibleNodes.contains(node.id),
            accentColor: accentColor
        )
        .position(x: x, y: y)
        .gesture(nodeDragGesture(for: node))
        .onAppear {
            DispatchQueue.main.async {
                nodePositions[node.id] = CGPoint(x: x, y: y)
            }
        }
    }

    private func nodeDragGesture(for node: DiagramNode) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragSourceId == nil {
                    dragSourceId = node.id
                }
                dragPosition = value.location
                if Int(value.translation.width) % 20 == 0 || Int(value.translation.height) % 20 == 0 {
                    LyoHapticManager.shared.playTypingCharacter()
                }
            }
            .onEnded { value in
                handleDragEnd(dropLocation: value.location, sourceId: node.id)
            }
    }
    
    private func startAnimations() {
        guard !card.nodes.isEmpty else { return }
        
        // 1. Nodes appear one by one with spring
        for (index, node) in card.nodes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.4) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    visibleNodes.insert(node.id)
                }
                LyoHapticManager.shared.playCardArrival()
            }
        }
        
        // Let the user drag to connect. 
        // We will no longer draw the lines automatically on appear!
    }
    
    private func handleDragEnd(dropLocation: CGPoint, sourceId: String) {
        defer {
            dragPosition = nil
            dragSourceId = nil
        }
        
        let dropRadius: CGFloat = 40.0 // Generous hit area around the node center
        
        // Find which node we dropped on
        var snappedTargetId: String? = nil
        
        for (nodeId, position) in nodePositions {
            if nodeId == sourceId { continue }
            
            let distance = hypot(position.x - dropLocation.x, position.y - dropLocation.y)
            if distance < dropRadius {
                snappedTargetId = nodeId
                break
            }
        }
        
        if let targetId = snappedTargetId {
            // Check if this connection is valid based on card data
            let isValid = card.connections.contains(where: {
                ($0.sourceId == sourceId && $0.targetId == targetId) ||
                ($0.sourceId == targetId && $0.targetId == sourceId) 
            })
            
            if isValid {
                // Success! Connect them.
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    establishedConnections.insert("\(sourceId)-\(targetId)")
                    establishedConnections.insert("\(targetId)-\(sourceId)") // Register both directions
                }
                LyoHapticManager.shared.playQuizSuccess()
            } else {
                // Invalid hit
                LyoHapticManager.shared.playCardArrival()
            }
        } else {
            // Dropped in empty space
            LyoHapticManager.shared.playTypingCharacter()
        }
    }
}

// Subview for a single node inside the diagram
struct DiagramNodeView: View {
    let node: DiagramNode
    let isVisible: Bool
    let accentColor: Color
    
    // Scale for the pulse effect on appear
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(hex: node.colorHex ?? ""))
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                
                Image(systemName: node.symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(node.label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(width: 100)
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? scale : 0.01)
        .onChange(of: isVisible) { oldValue, newValue in
            if newValue {
                // Pulse once on appear
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        scale = 1.0
                    }
                }
            }
        }
    }
}
