import SwiftUI

// MARK: - Floating Mode Button (FAB)

struct CampusFloatingModeButton: View {
    @Binding var showModeSheet: Bool
    let currentMode: CampusViewMode
    
    var body: some View {
        Button {
            HapticManager.shared.light()
            showModeSheet = true
        } label: {
            ZStack {
                // Gradient background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: .purple.opacity(0.4), radius: 12, x: 0, y: 6)
                
                // Current mode icon
                Image(systemName: currentMode.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100) // Above tab bar
    }
}

// MARK: - Mode Selection Sheet

struct ModeSelectionSheet: View {
    @Binding var selectedMode: CampusViewMode
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Title
            Text("View Mode")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 16)
            
            // Mode options
            ForEach(CampusViewMode.allCases, id: \.self) { mode in
                ModeOptionRow(
                    mode: mode,
                    isSelected: selectedMode == mode
                ) {
                    HapticManager.shared.medium()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isPresented = false
                    }
                }
                
                if mode != CampusViewMode.allCases.last {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 16)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(hexString: "1E293B"), Color(hexString: "0F172A")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
        )
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Mode Option Row

struct ModeOptionRow: View {
    let mode: CampusViewMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? 
                              LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: mode.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                    
                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(isSelected ? Color.white.opacity(0.05) : Color.clear)
        }
    }
}

// MARK: - CampusViewMode Extension

extension CampusViewMode {
    var subtitle: String {
        switch self {
        case .library: return "Browse courses & content"
        case .map: return "Explore nearby events"
        case .list: return "See all activities"
        case .feed: return "Discover what's trending"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hexString: "0F172A").ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                CampusFloatingModeButton(
                    showModeSheet: .constant(false),
                    currentMode: .map
                )
            }
        }
    }
}
