//
//  EducationalOverlayTray.swift
//  Lyo
//
//  Bottom sheet tray with professional educational stickers, assets,
//  and background music controls with voice ducking.
//

import SwiftUI

// MARK: - Educational Overlay Tray

struct EducationalOverlayTray: View {
    @Binding var selectedType: EducationalOverlay.OverlayType
    @Binding var activeOverlays: [EducationalOverlay]
    @Binding var selectedMusic: BackgroundMusicPreset?
    @Binding var isDuckingEnabled: Bool
    @Binding var musicVolume: Double
    let onAddOverlay: () -> Void
    let onDismiss: () -> Void
    
    @State private var selectedSection: TraySection = .stickers
    
    enum TraySection: String, CaseIterable {
        case stickers = "Stickers"
        case music    = "Music"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Handle
            handleBar
            
            // MARK: - Section Picker
            sectionPicker
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // MARK: - Content
            switch selectedSection {
            case .stickers:
                stickersSection
            case .music:
                musicSection
            }
            
            // MARK: - Active Overlays
            if !activeOverlays.isEmpty {
                activeOverlaysList
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Handle Bar
    
    private var handleBar: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
            
            HStack {
                Text("Knowledge Layer")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }
    
    // MARK: - Section Picker
    
    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(TraySection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedSection == section ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedSection == section
                            ? Capsule().fill(Color.white.opacity(0.15))
                            : Capsule().fill(Color.clear)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - Stickers Section
    
    private var stickersSection: some View {
        VStack(spacing: 16) {
            // Overlay Type Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(EducationalOverlay.OverlayType.allCases) { type in
                    stickerCard(type: type)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            // Callout Badge Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Badges")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.leading, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(["Key Concept", "Pro Tip", "Remember", "Warning", "Fun Fact"], id: \.self) { badge in
                            Button {
                                selectedType = .callout
                                onAddOverlay()
                            } label: {
                                Text(badge)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "8B5CF6"), Color(hex: "06B6D4")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 16)
        }
    }
    
    private func stickerCard(type: EducationalOverlay.OverlayType) -> some View {
        Button {
            selectedType = type
            onAddOverlay()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(type.color)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(type.color.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Tap to add")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                selectedType == type
                                ? type.color.opacity(0.5)
                                : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Music Section
    
    private var musicSection: some View {
        VStack(spacing: 16) {
            // Music Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Background Music")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.leading, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(BackgroundMusicPreset.presets) { preset in
                            musicPresetCard(preset: preset)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 12)
            
            // Volume Slider
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Slider(value: $musicVolume, in: 0...1, step: 0.05)
                    .tint(Color(hex: "8B5CF6"))
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("\(Int(musicVolume * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36)
            }
            .padding(.horizontal, 20)
            
            // Ducking Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice Ducking")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Auto-lower music when you speak")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Toggle("", isOn: $isDuckingEnabled)
                    .labelsHidden()
                    .tint(Color(hex: "66BB6A"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
    }
    
    private func musicPresetCard(preset: BackgroundMusicPreset) -> some View {
        Button {
            selectedMusic = preset
        } label: {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 22))
                    .foregroundColor(selectedMusic?.id == preset.id ? .white : .white.opacity(0.6))
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                selectedMusic?.id == preset.id
                                ? Color(hex: "8B5CF6").opacity(0.4)
                                : Color.white.opacity(0.08)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                selectedMusic?.id == preset.id
                                ? Color(hex: "8B5CF6")
                                : Color.clear,
                                lineWidth: 2
                            )
                    )
                
                Text(preset.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Active Overlays List
    
    private var activeOverlaysList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .background(Color.white.opacity(0.15))
            
            HStack {
                Text("Active (\(activeOverlays.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Button {
                    activeOverlays.removeAll()
                } label: {
                    Text("Clear All")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            ForEach(activeOverlays) { overlay in
                HStack(spacing: 10) {
                    Image(systemName: overlay.type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(overlay.type.color)
                    
                    Text(overlay.content)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Button {
                        activeOverlays.removeAll { $0.id == overlay.id }
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            EducationalOverlayTray(
                selectedType: .constant(.arrow),
                activeOverlays: .constant([
                    EducationalOverlay(type: .arrow, position: .zero, timestamp: 0, content: "CTA Arrow"),
                    EducationalOverlay(type: .callout, position: .zero, timestamp: 5, content: "Key Concept")
                ]),
                selectedMusic: .constant(BackgroundMusicPreset.presets.first),
                isDuckingEnabled: .constant(true),
                musicVolume: .constant(0.3),
                onAddOverlay: {},
                onDismiss: {}
            )
        }
    }
}
