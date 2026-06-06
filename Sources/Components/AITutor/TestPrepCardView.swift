import SwiftUI

struct TestPrepCardView: View {
    let data: TestPrepBlockData
    var onSchedule: (Date, String, String, [String]) -> Void // Date, selected course, description, attachmentIds
    
    @State private var selectedDate: Date
    @State private var selectedCourse: String
    @State private var testDescription: String
    
    @StateObject private var mediaService = MediaPickerService.shared
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var isUploading = false
    
    init(data: TestPrepBlockData, onSchedule: @escaping (Date, String, String, [String]) -> Void) {
        self.data = data
        self.onSchedule = onSchedule
        _selectedDate = State(initialValue: data.date ?? Date())
        _selectedCourse = State(initialValue: data.courses.first ?? "")
        _testDescription = State(initialValue: data.description ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(DesignTokens.Colors.accent)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Test Prep Mode")
                        .font(DesignTokens.Typography.titleSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text("Set up your study plan for \(data.topic)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .padding(.bottom, 4)
            
            // Date Picker
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Label("Exam Date & Time", systemImage: "clock.fill")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                
                DatePicker("", selection: $selectedDate)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceElevated)
                    .cornerRadius(DesignTokens.Radius.md)
            }
            
            // Course Selector
            if !data.courses.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Label("Select Course", systemImage: "book.closed.fill")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    Picker("Course", selection: $selectedCourse) {
                        ForEach(data.courses, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.surfaceElevated)
                    .cornerRadius(DesignTokens.Radius.md)
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Label("Test Description", systemImage: "pencil.and.outline")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                
                TextField("E.g. Midterm covering chapters 1-5", text: $testDescription)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.surfaceElevated)
                    .cornerRadius(DesignTokens.Radius.md)
                    .font(DesignTokens.Typography.bodyMedium)
            }
            
            // Attachments
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Label("Study Materials", systemImage: "folder.fill")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    Spacer()
                    
                    Menu {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        
                        Button {
                            showDocumentPicker = true
                        } label: {
                            Label("Files", systemImage: "folder")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add")
                        }
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.accent)
                    }
                }
                
                if !mediaService.selectedMedia.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(mediaService.selectedMedia) { media in
                                HStack(spacing: 4) {
                                    if let thumb = media.thumbnail {
                                        Image(uiImage: thumb)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 24, height: 24)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    } else {
                                        Image(systemName: "doc.fill")
                                    }
                                    
                                    Text(media.filename)
                                        .lineLimit(1)
                                        .frame(maxWidth: 120)
                                    
                                    Button {
                                        mediaService.removeMedia(media)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                }
                                .font(DesignTokens.Typography.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DesignTokens.Colors.accent.opacity(0.1))
                                .cornerRadius(DesignTokens.Radius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                        .stroke(DesignTokens.Colors.accent.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            
            // Action Button
            Button {
                Task {
                    isUploading = true
                    do {
                        let ids = try await mediaService.uploadSelectedMedia()
                        mediaService.clearSelection()
                        onSchedule(selectedDate, selectedCourse, testDescription, ids)
                    } catch {
                        // Handle error (maybe show alert)
                        print("Failed to upload attachments: \(error)")
                        onSchedule(selectedDate, selectedCourse, testDescription, [])
                    }
                    isUploading = false
                }
            } label: {
                HStack {
                    if isUploading {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 8)
                    }
                    Text(isUploading ? "Uploading..." : "Schedule & Create Study Plan")
                        .font(DesignTokens.Typography.labelLarge.bold())
                    if !isUploading {
                        Image(systemName: "sparkles")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(isUploading ? AnyShapeStyle(Color.gray) : AnyShapeStyle(DesignTokens.Colors.accentGradient))
                .foregroundColor(.white)
                .cornerRadius(DesignTokens.Radius.lg)
                .applyShadow(DesignTokens.Shadow.glow)
            }
            .disabled(isUploading)
            .padding(.top, 4)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                if let url = url {
                    Task {
                        try? await mediaService.processDocumentURL(url)
                    }
                }
            }
        }

        .padding(DesignTokens.Spacing.lg)
        .background(
            ZStack {
                DesignTokens.Colors.surface
                DesignTokens.Colors.accent.opacity(0.05)
            }
        )
        .cornerRadius(DesignTokens.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                .stroke(DesignTokens.Colors.surfaceHighlight, lineWidth: 1)
        )
        .applyMultiLayerShadow()
    }
}
