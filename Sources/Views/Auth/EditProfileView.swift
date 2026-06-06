import SwiftUI
import PhotosUI

// MARK: - Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var email: String
    @State private var bio = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var selectedImageData: Data?
    @State private var isLoading = false
    @State private var uploadProgress: String?
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false

    init() {
        // Initialize with empty values, will be set in onAppear
        _name = State(initialValue: "")
        _email = State(initialValue: "")
    }

    var body: some View {
        NavigationView {
            Form {
                // Profile Photo Section
                Section {
                    HStack {
                        Spacer()

                        VStack(spacing: 16) {
                            // Avatar
                            ZStack(alignment: .bottomTrailing) {
                                if let profileImage = profileImage {
                                    profileImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else if let avatarURL = rootViewModel.userAvatarURL {
                                    AsyncImage(url: URL(string: avatarURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .overlay(
                                                Text(String(name.prefix(1)).uppercased())
                                                    .font(.system(size: 40, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Text(String(name.prefix(1)).uppercased())
                                                .font(.system(size: 40, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }

                                // Change photo button
                                PhotosPicker(selection: $selectedImage, matching: .images) {
                                    Image(systemName: "camera.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .background(Circle().fill(Color(.systemBackground)))
                                }
                            }

                            Text("Tap to change photo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Personal Information
                Section("Personal Information") {
                    HStack {
                        Text("Name")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("Your name", text: $name)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Email")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(email)
                            .foregroundColor(.secondary)
                    }
                }

                // Bio Section
                Section("About") {
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                }

                // Progress, Error or Success Message
                if let progress = uploadProgress {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(progress)
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }

                if showSuccessMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Profile updated successfully")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveProfile()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .onChange(of: selectedImage) {
                Task {
                    if let data = try? await selectedImage?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        profileImage = Image(uiImage: uiImage)
                        selectedImageData = data  // Store for upload
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadCurrentProfile() {
        if let user = rootViewModel.currentUser {
            name = user.name
            email = user.email
        }
    }

    private func saveProfile() {
        errorMessage = nil
        showSuccessMessage = false
        uploadProgress = nil
        isLoading = true

        Task {
            do {
                var avatarURL: String? = nil
                
                // Upload new avatar if image was changed
                if let imageData = selectedImageData,
                   let uiImage = UIImage(data: imageData) {
                    uploadProgress = "Uploading photo..."
                    
                    let uploadResponse = try await CloudStorageService.shared.uploadAvatar(image: uiImage)
                    avatarURL = uploadResponse.avatarUrl
                }

                uploadProgress = "Saving profile..."
                try await rootViewModel.updateProfile(name: name.isEmpty ? nil : name, avatar: avatarURL)

                showSuccessMessage = true
                isLoading = false
                uploadProgress = nil

                // Dismiss after a short delay
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            } catch {
                if let lyoError = error as? LyoError {
                    errorMessage = lyoError.errorDescription ?? "Failed to update profile"
                } else if let storageError = error as? CloudStorageError {
                    errorMessage = storageError.localizedDescription
                } else {
                    errorMessage = "Unable to update profile. Please try again."
                }
                isLoading = false
                uploadProgress = nil
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView()
            .environmentObject(RootViewModel())
    }
}
