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
            AnimatedMeshBackground(palette: palette, phase: 0) // Reuse from ConceptCard
                .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.backgroundDepth))
            
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius: CGFloat = min(geo.size.width, geo.size.height) * 0.35
                
                ZStack {
                    // Lines layer - Canvas
                    Canvas { context, size in
                        // Draw established connections securely
                        for connection in card.connections {
                            let connectionKey = "\(connection.sourceId)-\(connection.targetId)"
                            if establishedConnections.contains(connectionKey) {
                                guard let sourcePos = nodePositions[connection.sourceId],
                                      let targetPos = nodePositions[connection.targetId] else { continue }
                                
                                var path = Path()
                                path.move(to: sourcePos)
                                path.addLine(to: targetPos)
                                
                                context.stroke(
                                    path,
                                    with: .color(.white.opacity(0.8)),
                                    lineWidth: 4
                                )
                            }
                        }
                        
                        // Draw active drag line
                        if let dragSourceId = dragSourceId,
                           let sourcePos = nodePositions[dragSourceId],
                           let dragPos = dragPosition {
                            var path = Path()
                            path.move(to: sourcePos)
                            path.addLine(to: dragPos)
                            
                            context.stroke(
                                path,
                                with: .color(.white.opacity(0.5)),
                                style: StrokeStyle(lineWidth: 3, dash: [6, 6])
                            )
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    
                    // Nodes layer
                    ForEach(Array(card.nodes.enumerated()), id: \.element.id) { index, node in
                        let angle = (2 * .pi / CGFloat(card.nodes.count)) * CGFloat(index) - .pi / 2
                        let x = center.x + radius * cos(angle)
                        let y = center.y + radius * sin(angle)
                        
                        DiagramNodeView(
                            node: node,
                            isVisible: visibleNodes.contains(node.id),
                            accentColor: Color(hex: palette.color2Hex) ?? .blue
                        )
                        .position(x: x, y: y)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if dragSourceId == nil {
                                        dragSourceId = node.id
                                    }
                                    dragPosition = value.location
                                    // Trigger light continuous haptics during drag mapping
                                    if Int(value.translation.width) % 20 == 0 || Int(value.translation.height) % 20 == 0 {
                                        LyoHapticManager.shared.playImpact(.light)
                                    }
                                }
                                .onEnded { value in
                                    handleDragEnd(dropLocation: value.location, sourceId: node.id)
                                }
                        )
                        .onAppear {
                            // Store position for Canvas and Drag calculations
                            DispatchQueue.main.async {
                                nodePositions[node.id] = CGPoint(x: x, y: y)
                            }
                        }
                    }
                }
            }
            .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.foregroundDepth))
        }
        .onAppear {
            startAnimations()
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
                LyoHapticManager.shared.playSuccess()
            } else {
                // Invalid hit
                LyoHapticManager.shared.playImpact(.heavy)
            }
        } else {
            // Dropped in empty space
            LyoHapticManager.shared.playImpact(.medium)
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
                    .fill(Color(hex: node.colorHex ?? "") ?? accentColor)
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
        .onChange(of: isVisible) { visible in
            if visible {
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
