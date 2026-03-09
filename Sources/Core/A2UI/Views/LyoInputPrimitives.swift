//
//  LyoInputPrimitives.swift
//  Lyo
//
//  v2 renderers for input primitives: input (text, slider, toggle, etc.), button
//

import SwiftUI

// MARK: - Input Primitive

/// Renders input variants: text, textarea, slider, toggle, checkbox, dropdown, rating
struct LyoInputPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "text" }

    @State private var textValue: String = ""
    @State private var sliderValue: Double = 0.5
    @State private var toggleValue: Bool = false
    @State private var ratingValue: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            if let label = component.content?.label {
                Text(label)
                    .font(.subheadline.weight(.medium))
            }

            // Input control
            inputControl

            // Hint
            if let hint = component.content?.hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var inputControl: some View {
        switch variant {
        case "textarea":
            TextEditor(text: $textValue)
                .frame(minHeight: 80)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

        case "slider":
            Slider(value: $sliderValue)
                .tint(.blue)

        case "toggle":
            Toggle(
                component.content?.label ?? "",
                isOn: $toggleValue
            )
            .toggleStyle(.switch)

        case "checkbox":
            Button {
                toggleValue.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: toggleValue ? "checkmark.square.fill" : "square")
                        .foregroundStyle(toggleValue ? .blue : .secondary)
                    Text(component.content?.text ?? "")
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

        case "rating":
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= ratingValue ? "star.fill" : "star")
                        .foregroundStyle(star <= ratingValue ? .yellow : .secondary)
                        .onTapGesture {
                            ratingValue = star
                        }
                }
            }

        default: // "text"
            TextField(
                component.content?.placeholder ?? "Enter text...",
                text: $textValue
            )
            .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Button Primitive

/// Renders button variants: primary, secondary, outline, destructive, icon, link
struct LyoButtonPrimitiveView: View {
    let component: LyoUIComponent
    let context: A2UIRenderContext
    var onAction: ((LyoCommand) -> Void)?

    private var variant: String { component.variant ?? "primary" }

    var body: some View {
        Button {
            if let actionId = actionId {
                onAction?(LyoCommand(action: actionId, payload: nil))
            }
        } label: {
            buttonContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(component.meta?.accessibilityLabel ?? displayLabel)
    }

    @ViewBuilder
    private var buttonContent: some View {
        switch variant {
        case "secondary":
            HStack(spacing: 6) {
                iconView
                Text(displayLabel)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)

        case "outline":
            HStack(spacing: 6) {
                iconView
                Text(displayLabel)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 1.5)
            )

        case "destructive":
            HStack(spacing: 6) {
                iconView
                Text(displayLabel)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red)
            .cornerRadius(10)

        case "icon":
            if let icon = component.content?.icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }

        case "link":
            HStack(spacing: 4) {
                Text(displayLabel)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
            }
            .font(.subheadline)
            .foregroundStyle(.blue)

        default: // "primary"
            HStack(spacing: 6) {
                iconView
                Text(displayLabel)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = component.content?.icon {
            Image(systemName: icon)
        }
    }

    private var displayLabel: String {
        component.content?.label
            ?? component.content?.text
            ?? component.content?.title
            ?? "Button"
    }

    private var actionId: String? {
        // Check data bag for action identifier
        if let actionValue = component.data?["actionId"],
           case .string(let id) = actionValue {
            return id
        }
        return component.content?.label
    }
}
