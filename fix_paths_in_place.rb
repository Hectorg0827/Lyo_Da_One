#!/usr/bin/env ruby
# encoding: UTF-8
# Fix file paths in Xcode project - update paths to correct locations under Sources/
require 'fileutils'

project_file = '/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj'

# Backup
backup_path = "#{project_file}.backup_path_fix_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.cp(project_file, backup_path)
puts "Created backup: #{backup_path}"

content = File.read(project_file, encoding: 'UTF-8')
original_size = content.length

# File path mappings - these files exist in Sources/ but project references root-level paths
# Format: [old_path, new_path]
path_fixes = [
  # Views/Main files that were at root
  ['path = CameraPreview.swift;', 'path = Sources/Views/Main/Creation/CameraPreview.swift; sourceTree = SOURCE_ROOT;'],
  ['path = CampusItemDetailSheet.swift;', 'path = Sources/Views/Main/Campus/CampusItemDetailSheet.swift; sourceTree = SOURCE_ROOT;'],
  ['path = CampusView.swift;', 'path = Sources/Views/Main/CampusView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = ChallengesHomeView.swift;', 'path = Sources/Views/Main/Challenges/ChallengesHomeView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = ChatBubbleView.swift;', 'path = Sources/Views/Main/Hybrid/ChatBubbleView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = ChatHistoryView.swift;', 'path = Sources/Views/Main/Drawer/ChatHistoryView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = ChatOverlayView.swift;', 'path = Sources/Views/Main/Hybrid/ChatOverlayView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = ClassroomView.swift;', 'path = Sources/Views/Main/Classroom/ClassroomView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = CourseDrawerView.swift;', 'path = Sources/Views/Main/AITutor/CourseDrawerView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = CreateEventView.swift;', 'path = Sources/Views/Main/CreateEventView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = CreationSheet.swift;', 'path = Sources/Views/Main/Creation/CreationSheet.swift; sourceTree = SOURCE_ROOT;'],
  ['path = DiscoverReelView.swift;', 'path = Sources/Views/Main/DiscoverReelView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = DiscoverView.swift;', 'path = Sources/Views/Main/DiscoverView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = EnhancedLyoHomeView.swift;', 'path = Sources/Views/Main/AITutor/EnhancedLyoHomeView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = FloatingOrbView.swift;', 'path = Sources/Views/Main/Hybrid/FloatingOrbView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = FocusView.swift;', 'path = Sources/Views/Main/FocusView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = GlobalSearchView.swift;', 'path = Sources/Views/Main/GlobalSearchView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = HeroSectionView.swift;', 'path = Sources/Views/Main/Hybrid/HeroSectionView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = HybridLyoHomeView.swift;', 'path = Sources/Views/Main/Hybrid/HybridLyoHomeView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = LioChatSheet.swift;', 'path = Sources/Views/Main/AITutor/LioChatSheet.swift; sourceTree = SOURCE_ROOT;'],
  ['path = LiveClassroomView.swift;', 'path = Sources/Views/Main/Classroom/LiveClassroomView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = LyoAvatarView.swift;', 'path = Sources/Views/Main/Hybrid/LyoAvatarView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = LyoHomeView.swift;', 'path = Sources/Views/Main/AITutor/LyoHomeView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = LyoOverlayView.swift;', 'path = Sources/Views/Main/Hybrid/LyoOverlayView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = MasteryProfileView.swift;', 'path = Sources/Views/Main/Profile/MasteryProfileView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = NotificationsView.swift;', 'path = Sources/Views/Main/NotificationsView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = PostEditorView.swift;', 'path = Sources/Views/Main/Creation/PostEditorView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = PremiumHomeView.swift;', 'path = Sources/Views/Main/Home/PremiumHomeView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = ProfileHomeView.swift;', 'path = Sources/Views/Main/Profile/ProfileHomeView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = QuizOverlayView.swift;', 'path = Sources/Views/Main/ReelComponents/QuizOverlayView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = ReelActionStrip.swift;', 'path = Sources/Views/Main/ReelComponents/ReelActionStrip.swift; sourceTree = SOURCE_ROOT;'],
  ['path = ReelHeaderView.swift;', 'path = Sources/Views/Main/ReelComponents/ReelHeaderView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = ReelInfoOverlay.swift;', 'path = Sources/Views/Main/ReelComponents/ReelInfoOverlay.swift; sourceTree = SOURCE_ROOT;'],
  ['path = SimpleVideoContextSheet.swift;', 'path = Sources/Views/Main/SimpleVideoContextSheet.swift; sourceTree = SOURCE_ROOT;'],
  ['path = SocialFeedSection.swift;', 'path = Sources/Views/Main/Hybrid/SocialFeedSection.swift; sourceTree = SOURCE_ROOT;'],
  ['path = StackDrawerView.swift;', 'path = Sources/Views/Main/StackDrawerView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = StackPanelView.swift;', 'path = Sources/Views/Main/Stack/StackPanelView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = TopHeaderView.swift;', 'path = Sources/Views/Main/TopHeaderView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = TranscriptSheet.swift;', 'path = Sources/Views/Main/Classroom/TranscriptSheet.swift; sourceTree = SOURCE_ROOT;'],
  ['path = TutorModeView.swift;', 'path = Sources/Views/Main/Classroom/TutorModeView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = VideoContextSheet.swift;', 'path = Sources/Views/Main/ReelComponents/VideoContextSheet.swift; sourceTree = SOURCE_ROOT;'],
  ['path = VideoRecorderView.swift;', 'path = Sources/Views/Main/Creation/VideoRecorderView.swift; sourceTree = SOURCE_ROOT;'],
  
  # Profile views  
  ['path = Views/Profile/HolisticProfileView.swift;', 'path = Sources/Views/Profile/HolisticProfileView.swift; sourceTree = SOURCE_ROOT;'],
  ['path = "Views/Profile/HolisticProfileView.swift";', 'path = Sources/Views/Profile/HolisticProfileView.swift; sourceTree = SOURCE_ROOT;'],
  
  # Components
  ['path = Views/Components/ProactiveHintBanner.swift;', 'path = Sources/Views/Components/ProactiveHintBanner.swift; sourceTree = SOURCE_ROOT;'],
  ['path = "Views/Components/ProactiveHintBanner.swift";', 'path = Sources/Views/Components/ProactiveHintBanner.swift; sourceTree = SOURCE_ROOT;'],
  
  # Services
  ['path = Services/SmartMemoryService.swift;', 'path = Sources/Services/SmartMemoryService.swift; sourceTree = SOURCE_ROOT;'],
  ['path = "Services/SmartMemoryService.swift";', 'path = Sources/Services/SmartMemoryService.swift; sourceTree = SOURCE_ROOT;'],
  ['path = Services/SoftSkillsService.swift;', 'path = Sources/Services/SoftSkillsService.swift; sourceTree = SOURCE_ROOT;'],
  ['path = "Services/SoftSkillsService.swift";', 'path = Sources/Services/SoftSkillsService.swift; sourceTree = SOURCE_ROOT;'],
]

fixed_count = 0

path_fixes.each do |old_path, new_path|
  if content.include?(old_path)
    # Also remove sourceTree = "<group>" if it exists after path
    pattern_with_source_tree = /#{Regexp.escape(old_path)}\s*sourceTree\s*=\s*"<group>";/
    pattern_simple = /#{Regexp.escape(old_path)}/
    
    if content.gsub!(pattern_with_source_tree, new_path)
      fixed_count += 1
      puts "Fixed: #{old_path.split(' = ').last.gsub(';', '')} (with sourceTree)"
    elsif content.gsub!(pattern_simple, new_path)
      fixed_count += 1
      puts "Fixed: #{old_path.split(' = ').last.gsub(';', '')}"
    end
  end
end

File.write(project_file, content, encoding: 'UTF-8')

puts ""
puts "Fixed #{fixed_count} file paths"
puts "Project file size: #{original_size} -> #{content.length} bytes"
puts "Backup saved: #{backup_path}"
