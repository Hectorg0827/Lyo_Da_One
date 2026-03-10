//
//  A2UICollectionRenderers.swift
//  Lyo
//
//  Renderers for collection-based A2UI components like Chips, Suggestions, grid layouts, etc.
//

import SwiftUI

struct A2UIChipsRenderer: View {
    let component: A2UIComponent
    let context: A2UIRenderContext
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = component.props.title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: component.props.foregroundColor ?? "#FFFFFF"))
            }

            // Using wrapping layout for chips
            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                // Determine source of texts
                let texts = component.props.suggestions ?? component.props.options?.compactMap { ($0 as? [String: Any])?["text"] as? String ?? ($0 as? A2UIQuizOption)?.text } ?? []
                
                ForEach(texts, id: \.self) { chipText in
                    Button {
                        // Trigger configured action or default to text message submission
                        if let actionId = component.props.actionId {
                            onAction?(A2UIAction(
                                id: actionId,
                                trigger: .tap,
                                type: .submit,
                                payload: ["value": .string(chipText)]
                            ))
                        } else {
                            // Default back-compat fallback:
                            onAction?(A2UIAction(
                                id: "chip_tapped",
                                trigger: .tap,
                                type: .sendMessage,
                                payload: ["text": .string(chipText)]
                            ))
                        }
                    } label: {
                        Text(chipText)
                            .font(.system(size: CGFloat(component.props.fontSize ?? 14), weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: component.props.backgroundColor ?? "#3A3A3C"))
                            .foregroundColor(Color(hex: component.props.foregroundColor ?? "#FFFFFF"))
                            .cornerRadius(component.props.borderRadius ?? 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Helper Layout

/// Simple view that lays out children horizontally natively wrapping to next line if needed
struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for size in sizes {
            if rowWidth + size.width > (proposal.width ?? .infinity) {
                width = max(width, rowWidth)
                height += rowHeight + verticalSpacing
                rowWidth = size.width + horizontalSpacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + horizontalSpacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        
        width = max(width, rowWidth)
        height += rowHeight
        
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
