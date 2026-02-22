import SwiftUI
import os

struct A2UITestView: View {
    @State private var selectedAction: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Recursive A2UI Test")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    // Test basic components
                    Section("Basic Components") {
                        A2UIRecursiveRenderer(
                            component: createBasicTestComponent(),
                            onAction: handleAction
                        )
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }

                    // Test nested components
                    Section("Complex Nested Layout") {
                        A2UIRecursiveRenderer(
                            component: createComplexTestComponent(),
                            onAction: handleAction
                        )
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }

                    // Test weather card
                    Section("Weather Card Example") {
                        A2UIRecursiveRenderer(
                            component: createWeatherTestComponent(),
                            onAction: handleAction
                        )
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }

                    // Action feedback
                    if !selectedAction.isEmpty {
                        Text("Last Action: \(selectedAction)")
                            .padding()
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("A2UI Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func handleAction(_ actionId: String) {
        selectedAction = actionId
        HapticManager.shared.light()
        Log.a2ui.info("Test Action: \(actionId)")

        // Auto-clear after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if selectedAction == actionId {
                selectedAction = ""
            }
        }
    }

    private func createBasicTestComponent() -> DynamicComponent {
        let jsonData = """
        {
            "id": "basic-test",
            "type": "vstack",
            "spacing": 12,
            "alignment": "center",
            "children": [
                {
                    "id": "title-text",
                    "type": "text",
                    "content": "Hello Recursive A2UI!",
                    "font_style": "title",
                    "alignment": "center"
                },
                {
                    "id": "body-text",
                    "type": "text",
                    "content": "This is a dynamically rendered UI component from JSON.",
                    "font_style": "body",
                    "alignment": "center"
                },
                {
                    "id": "test-button",
                    "type": "button",
                    "label": "Test Button",
                    "action_id": "test_basic_button",
                    "variant": "primary",
                    "is_disabled": false
                }
            ]
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(DynamicComponent.self, from: jsonData)
    }

    private func createComplexTestComponent() -> DynamicComponent {
        let jsonData = """
        {
            "id": "complex-test",
            "type": "vstack",
            "spacing": 16,
            "alignment": "leading",
            "children": [
                {
                    "id": "header-card",
                    "type": "card",
                    "title": "Complex Layout Demo",
                    "subtitle": "Nested components showcase",
                    "children": [
                        {
                            "id": "inner-hstack",
                            "type": "hstack",
                            "spacing": 12,
                            "alignment": "center",
                            "children": [
                                {
                                    "id": "left-vstack",
                                    "type": "vstack",
                                    "children": [
                                        {
                                            "id": "feature-text",
                                            "type": "text",
                                            "content": "Features:",
                                            "font_style": "headline"
                                        },
                                        {
                                            "id": "feature1",
                                            "type": "text",
                                            "content": "• Unlimited nesting",
                                            "font_style": "body"
                                        },
                                        {
                                            "id": "feature2",
                                            "type": "text",
                                            "content": "• Dynamic layouts",
                                            "font_style": "body"
                                        }
                                    ]
                                },
                                {
                                    "id": "right-vstack",
                                    "type": "vstack",
                                    "children": [
                                        {
                                            "id": "action1-btn",
                                            "type": "button",
                                            "label": "Primary",
                                            "action_id": "test_primary",
                                            "variant": "primary"
                                        },
                                        {
                                            "id": "action2-btn",
                                            "type": "button",
                                            "label": "Secondary",
                                            "action_id": "test_secondary",
                                            "variant": "secondary"
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "id": "divider1",
                            "type": "divider"
                        },
                        {
                            "id": "bottom-text",
                            "type": "text",
                            "content": "All rendered from a single JSON structure!",
                            "font_style": "caption",
                            "alignment": "center",
                            "color": "#6B7280"
                        }
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(DynamicComponent.self, from: jsonData)
    }

    private func createWeatherTestComponent() -> DynamicComponent {
        let jsonData = """
        {
            "id": "weather-card",
            "type": "card",
            "title": "Current Weather",
            "children": [
                {
                    "id": "location-text",
                    "type": "text",
                    "content": "San Francisco, CA",
                    "font_style": "headline",
                    "alignment": "center"
                },
                {
                    "id": "temp-stack",
                    "type": "hstack",
                    "spacing": 16,
                    "alignment": "center",
                    "children": [
                        {
                            "id": "temp-text",
                            "type": "text",
                            "content": "72°F",
                            "font_style": "title"
                        },
                        {
                            "id": "condition-stack",
                            "type": "vstack",
                            "children": [
                                {
                                    "id": "condition-text",
                                    "type": "text",
                                    "content": "Sunny",
                                    "font_style": "body"
                                },
                                {
                                    "id": "feels-like-text",
                                    "type": "text",
                                    "content": "Feels like 75°F",
                                    "font_style": "caption"
                                }
                            ]
                        }
                    ]
                },
                {
                    "id": "weather-divider",
                    "type": "divider"
                },
                {
                    "id": "details-stack",
                    "type": "hstack",
                    "spacing": 20,
                    "alignment": "center",
                    "children": [
                        {
                            "id": "humidity-text",
                            "type": "text",
                            "content": "Humidity: 65%",
                            "font_style": "caption"
                        },
                        {
                            "id": "wind-text",
                            "type": "text",
                            "content": "Wind: 12 mph",
                            "font_style": "caption"
                        }
                    ]
                },
                {
                    "id": "refresh-button",
                    "type": "button",
                    "label": "Refresh Weather",
                    "action_id": "refresh_weather",
                    "variant": "primary"
                },
                {
                    "id": "spacer1",
                    "type": "spacer",
                    "height": 8
                },
                {
                    "id": "updated-text",
                    "type": "text",
                    "content": "Last updated: Just now",
                    "font_style": "caption",
                    "alignment": "center",
                    "color": "#9CA3AF"
                }
            ]
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(DynamicComponent.self, from: jsonData)
    }
}

// MARK: - Section Helper
extension A2UITestView {
    @ViewBuilder
    func Section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            content()
        }
    }
}

#Preview {
    A2UITestView()
}