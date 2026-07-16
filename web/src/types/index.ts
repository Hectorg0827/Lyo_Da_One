// ============================================================
// LYO Da ONE — Shared TypeScript Types (mirrors iOS models)
// ============================================================

// ---- Auth & User ----
export interface User {
  id: string;
  email: string;
  displayName: string;
  username: string;
  avatar: string;
  bio: string;
  role: 'student' | 'creator' | 'mentor' | 'admin';
  interests: string[];
  learningGoals: string[];
  streak: number;
  xp: number;
  level: number;
  coursesCompleted: number;
  followersCount: number;
  followingCount: number;
  createdAt: string;
  isPremium: boolean;
}

export interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}

// ---- Chat / LYO AI ----
export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  type: 'text' | 'course_proposal' | 'flashcard' | 'quiz' | 'diagram' | 'roadmap' | 'topic_selection';
  metadata?: Record<string, unknown>;
  createdAt: string;
}

export interface ChatConversation {
  id: string;
  title: string;
  messages: ChatMessage[];
  courseId?: string;
  createdAt: string;
  updatedAt: string;
}

// ---- Courses ----
export interface Course {
  id: string;
  title: string;
  description: string;
  thumbnail: string;
  author: User;
  category: string;
  tags: string[];
  modules: CourseModule[];
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  estimatedDuration: number; // minutes
  enrolledCount: number;
  rating: number;
  reviewCount: number;
  progress?: number; // 0-100
  isAIGenerated: boolean;
  createdAt: string;
}

export interface CourseModule {
  id: string;
  title: string;
  description: string;
  order: number;
  lessons: Lesson[];
  isCompleted?: boolean;
}

export interface Lesson {
  id: string;
  title: string;
  type: 'text' | 'video' | 'quiz' | 'exercise' | 'flashcard' | 'interactive';
  content: LessonBlock[];
  duration: number;
  order: number;
  isCompleted?: boolean;
}

export interface LessonBlock {
  id: string;
  type: 'text' | 'heading' | 'code' | 'image' | 'video' | 'quiz' | 'flashcard' | 'diagram' | 'analogy' | 'summary' | 'exercise';
  content: string;
  metadata?: Record<string, unknown>;
}

export interface Quiz {
  id: string;
  title: string;
  questions: QuizQuestion[];
}

export interface QuizQuestion {
  id: string;
  question: string;
  type: 'multiple_choice' | 'true_false' | 'fill_blank' | 'code';
  options?: string[];
  correctAnswer: string | number;
  explanation: string;
}

export interface Flashcard {
  id: string;
  front: string;
  back: string;
  category: string;
  mastery: number;
}

// ---- Clips (TikTok-style videos) ----
export interface Clip {
  id: string;
  author: User;
  videoUrl: string;
  thumbnailUrl: string;
  title: string;
  description: string;
  tags: string[];
  category: string;
  duration: number;
  views: number;
  likes: number;
  comments: number;
  shares: number;
  isLiked?: boolean;
  isBookmarked?: boolean;
  courseId?: string;
  createdAt: string;
}

export interface ClipComment {
  id: string;
  author: User;
  content: string;
  likes: number;
  isLiked?: boolean;
  createdAt: string;
  replies?: ClipComment[];
}

// ---- Stories ----
export interface Story {
  id: string;
  author: User;
  slides: StorySlide[];
  viewCount: number;
  isViewed?: boolean;
  createdAt: string;
  expiresAt: string;
}

export interface StorySlide {
  id: string;
  type: 'image' | 'video' | 'course_completion' | 'achievement' | 'text';
  mediaUrl?: string;
  text?: string;
  backgroundColor?: string;
  courseId?: string;
  achievementId?: string;
  duration: number;
}

// ---- Community ----
export interface CommunityPost {
  id: string;
  author: User;
  type: 'post' | 'question' | 'study_tip' | 'event' | 'poll' | 'course_share' | 'achievement';
  title: string;
  content: string;
  images?: string[];
  tags: string[];
  category: string;
  likes: number;
  comments: number;
  views: number;
  isLiked?: boolean;
  isBookmarked?: boolean;
  isPinned?: boolean;
  courseId?: string;
  poll?: Poll;
  createdAt: string;
}

export interface Poll {
  id: string;
  options: PollOption[];
  totalVotes: number;
  endsAt: string;
}

export interface PollOption {
  id: string;
  text: string;
  votes: number;
  isSelected?: boolean;
}

export interface Comment {
  id: string;
  author: User;
  content: string;
  likes: number;
  isLiked?: boolean;
  createdAt: string;
  replies?: Comment[];
}

export interface Group {
  id: string;
  name: string;
  description: string;
  coverImage: string;
  icon: string;
  memberCount: number;
  category: string;
  isJoined?: boolean;
  isPrivate: boolean;
  admin: User;
  recentActivity: string;
  createdAt: string;
}

// ---- Discovery ----
export interface EducationalPlace {
  id: string;
  name: string;
  type: 'school' | 'library' | 'workshop' | 'lab' | 'community_center' | 'online';
  description: string;
  address: string;
  coordinates: { lat: number; lng: number };
  rating: number;
  reviewCount: number;
  images: string[];
  categories: string[];
  distance?: number;
  isOpen?: boolean;
  website?: string;
  phone?: string;
}

export interface EducationalEvent {
  id: string;
  title: string;
  description: string;
  host: User | EducationalPlace;
  type: 'class' | 'workshop' | 'meetup' | 'webinar' | 'study_group';
  category: string;
  startDate: string;
  endDate: string;
  location: string;
  isVirtual: boolean;
  meetingUrl?: string;
  maxAttendees: number;
  currentAttendees: number;
  price: number;
  isRegistered?: boolean;
  coverImage: string;
}

// ---- Gamification ----
export interface Achievement {
  id: string;
  title: string;
  description: string;
  icon: string;
  category: 'learning' | 'social' | 'creation' | 'streak' | 'mastery';
  xpReward: number;
  isUnlocked: boolean;
  unlockedAt?: string;
  progress?: number;
  requirement: number;
}

export interface Challenge {
  id: string;
  title: string;
  description: string;
  type: 'daily' | 'weekly' | 'special';
  xpReward: number;
  progress: number;
  requirement: number;
  isCompleted: boolean;
  expiresAt: string;
}

export interface LeaderboardEntry {
  rank: number;
  user: User;
  xp: number;
  streak: number;
}

// ---- Notifications ----
export interface AppNotification {
  id: string;
  type: 'like' | 'comment' | 'follow' | 'course_complete' | 'achievement' | 'mention' | 'group_invite' | 'event_reminder' | 'system';
  title: string;
  body: string;
  actor?: User;
  targetId?: string;
  targetType?: string;
  isRead: boolean;
  createdAt: string;
}

// ---- Messages ----
export interface Conversation {
  id: string;
  participants: User[];
  lastMessage: DirectMessage;
  unreadCount: number;
  updatedAt: string;
}

export interface DirectMessage {
  id: string;
  senderId: string;
  content: string;
  type: 'text' | 'image' | 'video' | 'course_share' | 'clip_share';
  mediaUrl?: string;
  isRead: boolean;
  createdAt: string;
}

// ---- Community Stats ----
export interface CommunityStats {
  totalMembers: number;
  activeToday: number;
  totalPosts: number;
  totalCourses: number;
  totalClips: number;
}

// ---- Learning Stats ----
export interface LearningStats {
  totalHoursLearned: number;
  coursesCompleted: number;
  coursesInProgress: number;
  quizzesPassed: number;
  currentStreak: number;
  longestStreak: number;
  xpThisWeek: number;
  topTopics: { topic: string; hours: number }[];
}

// ---- API Response ----
export interface ApiResponse<T> {
  success: boolean;
  data: T;
  message?: string;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    hasMore: boolean;
  };
}

// ---- Course Generation ----
export interface CourseGenerationRequest {
  query: string;
  difficulty?: 'beginner' | 'intermediate' | 'advanced';
  duration?: 'short' | 'medium' | 'long';
  style?: 'visual' | 'reading' | 'interactive' | 'mixed';
}

export interface CourseGenerationEvent {
  type: 'thinking' | 'outline' | 'module' | 'lesson' | 'quiz' | 'complete' | 'error';
  data: unknown;
  progress: number;
}
