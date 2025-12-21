#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(Dir.pwd, 'Lyo.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the Sources group
sources_group = project.main_group['Sources']

# Files to add with their full paths
files_to_add = [
  'Sources/Core/Configuration/AppConfig.swift',
  'Sources/Models/LearningModels.swift',
  'Sources/Core/DesignSystem.swift',
  'Sources/Core/Errors/LyoError.swift',
  'Sources/Core/Networking/Endpoint.swift',
  'Sources/Core/Networking/NetworkCache.swift',
  'Sources/Core/Networking/NetworkClient.swift',
  'Sources/Core/Networking/NetworkLogger.swift',
  'Sources/Core/Networking/StreamingResponseManager.swift',
  'Sources/Core/Networking/WebSocketManager.swift',
  'Sources/Core/Security/TokenManager.swift',
  'Sources/Models/Chat.swift',
  'Sources/Models/Community.swift',
  'Sources/Models/StackModels.swift',
  'Sources/Models/FeedModels.swift',
  'Sources/Models/CampusModels.swift',
  'Sources/Services/Repositories/DefaultAIRepository.swift',
  'Sources/Services/Repositories/DefaultAuthRepository.swift',
  'Sources/Services/Repositories/DefaultCommunityRepository.swift',
  'Sources/Services/Repositories/DefaultGamificationRepository.swift',
  'Sources/Services/Repositories/DefaultLearningRepository.swift',
  'Sources/Services/Repositories/DefaultSocialRepository.swift',
  'Sources/Services/Repositories/DefaultTTSRepository.swift',
  'Sources/Services/Repositories/RepositoryProtocols.swift',
  'Sources/Services/VisionService.swift',
  'Sources/Services/StackService.swift',
  'Sources/Services/AuthService.swift',
  'Sources/Tests/RepositoryTests.swift',
  'Sources/ViewModels/ChatViewModel.swift',
  'Sources/ViewModels/CommunityViewModel.swift',
  'Sources/ViewModels/FeedViewModel.swift',
  'Sources/ViewModels/QuizViewModel.swift',
  'Sources/ViewModels/RootViewModel.swift',
  'Sources/ViewModels/TTSViewModel.swift',
  'Sources/Views/Auth/EditProfileView.swift',
  'Sources/Views/Auth/LoginView.swift',
  'Sources/Views/Auth/OnboardingView.swift',
  'Sources/Views/Auth/RegisterView.swift',
  'Sources/Views/Community/CommunityMapView.swift',
  'Sources/Views/HomeView.swift',
  'Sources/Views/Learning/QuizView.swift',
  'Sources/Views/Learning/TTSView.swift',
  'Sources/Views/Main/AITutor/EnhancedLyoHomeView.swift',
  'Sources/Views/Main/FocusView.swift',
  'Sources/Views/Main/DiscoverView.swift',
  'Sources/Views/Main/CampusView.swift',
  'Sources/Views/Main/StackDrawerView.swift',
  'Sources/Views/ProfileView.swift',
  'Sources/Views/SettingsView.swift',
  'Sources/Views/Social/ChatView.swift',
  'Sources/Views/Social/FeedView.swift',
  'Sources/Components/Errors/ErrorView.swift',
  'Sources/Components/Errors/OfflineIndicator.swift',
  'Sources/Components/Vision/ImagePickerView.swift',
  'Sources/Views/Main/Hybrid/LyoOverlayView.swift',
  'Sources/Views/Main/Hybrid/LyoAvatarView.swift',
  'Sources/Views/Main/Hybrid/ChatBubbleView.swift',
  'GoogleService-Info.plist',
  'Sources/Views/Main/ReelComponents/ReelHeaderView.swift',
  'Sources/Views/Main/ReelComponents/ReelActionStrip.swift',
  'Sources/Views/Main/ReelComponents/ReelInfoOverlay.swift',
  'Sources/Views/Main/ReelComponents/QuizOverlayView.swift',
  'Sources/Services/CameraManager.swift',
  'Sources/Views/Main/Creation/CameraPreview.swift',
  'Sources/Views/Community/Components/CommunityDockView.swift',
  'Sources/Views/Community/Components/CommunityCardView.swift',
  'Sources/Views/Components/Stories/StoryCircleView.swift',
  'Sources/Views/Components/Stories/StoriesRailView.swift',
  'Sources/Views/Components/Stories/StoryViewer.swift',
  'Sources/Models/ChatHistoryModels.swift',
  'Sources/ViewModels/TutorViewModel.swift',
  'Sources/Models/TutorModels.swift',
  'Sources/Views/Main/NotificationsView.swift',
  'Sources/Views/Main/GlobalSearchView.swift',
  'Sources/Views/Main/NotificationsView.swift',
  'Sources/Views/Main/GlobalSearchView.swift',
  'Sources/Views/Main/Drawer/ChatHistoryView.swift',
  'Sources/Models/NotificationModels.swift',
  'Sources/Services/Repositories/NotificationRepository.swift',
  'Sources/Services/ChatPersistenceService.swift',
]

def find_or_create_group(parent_group, path_components)
  return parent_group if path_components.empty?

  group_name = path_components.first
  group = parent_group[group_name] || parent_group.new_group(group_name, group_name)

  find_or_create_group(group, path_components[1..-1])
end

files_to_add.each do |file_path|
  full_path = File.join(Dir.pwd, file_path)

  unless File.exist?(full_path)
    puts "WARNING: File does not exist: #{full_path}"
    next
  end

  # Parse path to find the right group
  if file_path.start_with?('Sources/')
    path_parts = file_path.split('/')[1..-1]  # Remove 'Sources' prefix
    group_to_use = sources_group
  else
    path_parts = file_path.split('/')
    group_to_use = project.main_group
  end
  file_name = path_parts.pop

  # Find or create the appropriate group
  group = find_or_create_group(group_to_use, path_parts)

  # Check if file is already in the group to avoid duplicates
  existing_file = group.files.find { |f| f.path == full_path }
  
  if existing_file
    puts "Skipping existing file: #{file_path}"
  else
    # Add the file reference
    file_ref = group.new_file(full_path)

    # Add to build phase if it's a Swift file
    if file_name.end_with?('.swift')
      target.add_file_references([file_ref])
    elsif file_name == 'GoogleService-Info.plist'
      target.add_resources([file_ref])
      puts "Added resource: #{file_path}"
    end
    puts "Added: #{file_path}"
  end
end

# Save the project
project.save

puts "\n✅ Successfully added all files to Xcode project!"
