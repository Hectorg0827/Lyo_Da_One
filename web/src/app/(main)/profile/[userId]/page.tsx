'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import {
  BookOpen,
  Play,
  Trophy,
  BarChart2,
  Activity,
  Eye,
  CheckCircle,
  MessageCircle,
  Zap,
  Lock,
} from 'lucide-react';
import ProfileHeader from '@/components/profile/ProfileHeader';
import LearningStatsPanel from '@/components/profile/LearningStats';
import { cn, formatTimeAgo } from '@/lib/utils';
import type { User, LearningStats } from '@/types';

// ── Mock other user data ─────────────────────────────────────────────────────

const mockOtherUser: User = {
  id: 'user_2',
  email: 'maya@lyo.app',
  displayName: 'Maya Chen',
  username: 'mayalearns',
  avatar: '',
  bio: 'AI researcher & lifelong learner. Sharing knowledge one lesson at a time. 🧠',
  role: 'creator',
  interests: ['AI', 'Neuroscience', 'Philosophy', 'Piano'],
  learningGoals: ['Publish AI research paper', 'Learn Japanese'],
  streak: 34,
  xp: 12850,
  level: 28,
  coursesCompleted: 57,
  followersCount: 2840,
  followingCount: 312,
  createdAt: '2023-09-15T00:00:00Z',
  isPremium: true,
};

const mockStats: LearningStats = {
  totalHoursLearned: 386,
  coursesCompleted: 57,
  coursesInProgress: 3,
  quizzesPassed: 214,
  currentStreak: 34,
  longestStreak: 56,
  xpThisWeek: 3100,
  topTopics: [
    { topic: 'Artificial Intelligence', hours: 95 },
    { topic: 'Neuroscience', hours: 62 },
    { topic: 'Philosophy', hours: 48 },
    { topic: 'Piano / Music', hours: 35 },
    { topic: 'Japanese', hours: 20 },
  ],
};

const mockActivity = [
  {
    id: '1',
    type: 'course_complete',
    text: 'Completed "Deep Reinforcement Learning"',
    sub: 'Earned 750 XP',
    icon: CheckCircle,
    color: '#22c55e',
    time: '2024-06-15T08:00:00Z',
  },
  {
    id: '2',
    type: 'clip_posted',
    text: 'Posted a clip: "Neural Networks in 90 seconds"',
    sub: '14.2K views · 1.1K likes',
    icon: Play,
    color: '#ec4899',
    time: '2024-06-14T15:30:00Z',
  },
  {
    id: '3',
    type: 'post',
    text: 'Shared a post in the AI Research community',
    sub: '"Attention mechanisms explained simply"',
    icon: MessageCircle,
    color: '#6c63ff',
    time: '2024-06-13T10:00:00Z',
  },
  {
    id: '4',
    type: 'achievement',
    text: 'Unlocked: "Legend Streak" — 30 days',
    sub: '+1000 XP',
    icon: Trophy,
    color: '#f59e0b',
    time: '2024-06-12T00:00:00Z',
  },
];

const mockCourses = [
  {
    id: '1',
    title: 'Deep Reinforcement Learning',
    category: 'AI & ML',
    color: 'from-purple-600 to-indigo-500',
    emoji: '🤖',
    xpEarned: 750,
    completedAt: '2024-06-15',
  },
  {
    id: '2',
    title: 'Consciousness & the Brain',
    category: 'Neuroscience',
    color: 'from-pink-600 to-rose-500',
    emoji: '🧠',
    xpEarned: 600,
    completedAt: '2024-05-20',
  },
  {
    id: '3',
    title: 'Japanese JLPT N4 Prep',
    category: 'Languages',
    color: 'from-red-600 to-orange-500',
    emoji: '🇯🇵',
    xpEarned: 500,
    completedAt: '2024-04-30',
  },
  {
    id: '4',
    title: 'Advanced Piano Technique',
    category: 'Music',
    color: 'from-amber-500 to-yellow-400',
    emoji: '🎹',
    xpEarned: 400,
    completedAt: '2024-04-10',
  },
];

const mockClips = [
  { id: '1', title: 'Neural Networks 90s', views: 14200, color: 'from-purple-700 to-indigo-600', emoji: '🤖' },
  { id: '2', title: 'AI vs Human Brain', views: 8700, color: 'from-pink-600 to-rose-500', emoji: '🧠' },
  { id: '3', title: 'Softmax Explained', views: 5400, color: 'from-blue-600 to-cyan-500', emoji: '📊' },
  { id: '4', title: 'Piano Practice Tip', views: 3200, color: 'from-amber-500 to-yellow-400', emoji: '🎹' },
  { id: '5', title: 'Japan Daily Life', views: 2900, color: 'from-red-600 to-orange-500', emoji: '🌸' },
  { id: '6', title: 'Reading Nietzsche', views: 1800, color: 'from-green-600 to-teal-500', emoji: '📚' },
];

const mockAchievements = [
  { id: '1', title: 'First Step', desc: 'Complete your first lesson', xp: 50, icon: '🎯', unlocked: true },
  { id: '2', title: 'Week Warrior', desc: '7-day streak', xp: 200, icon: '🔥', unlocked: true },
  { id: '3', title: 'Quiz Master', desc: 'Pass 10 quizzes', xp: 300, icon: '🧠', unlocked: true },
  { id: '4', title: 'Course Graduate', desc: 'Complete 5 courses', xp: 500, icon: '🎓', unlocked: true },
  { id: '5', title: 'Legend Streak', desc: '30-day streak', xp: 1000, icon: '🏆', unlocked: true },
  { id: '6', title: 'Content Creator', desc: 'Post 10 clips', xp: 300, icon: '🎬', unlocked: true },
  { id: '7', title: 'Social Star', desc: 'Get 1000 followers', xp: 500, icon: '⭐', unlocked: true },
  { id: '8', title: 'XP Millionaire', desc: 'Earn 10,000 XP', xp: 1000, icon: '💰', unlocked: true },
  { id: '9', title: 'Marathon Learner', desc: '100 hours learned', xp: 700, icon: '🏅', unlocked: true },
  { id: '10', title: 'Top Contributor', desc: 'Help 50 learners', xp: 600, icon: '🤝', unlocked: false },
  { id: '11', title: 'Master Mind', desc: 'Reach Level 40', xp: 800, icon: '💎', unlocked: false },
  { id: '12', title: 'Speed Learner', desc: 'Finish 3 courses in 1 week', xp: 600, icon: '⚡', unlocked: false },
];

const tabs = [
  { id: 'activity', label: 'Activity', icon: Activity },
  { id: 'courses', label: 'Courses', icon: BookOpen },
  { id: 'clips', label: 'Clips', icon: Play },
  { id: 'achievements', label: 'Achievements', icon: Trophy },
  { id: 'stats', label: 'Stats', icon: BarChart2 },
];

// ── Animation ────────────────────────────────────────────────────────────────

const itemVariants = {
  hidden: { opacity: 0, y: 16 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] } },
};

const containerVariants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { staggerChildren: 0.07 } },
};

// ── Main Page ────────────────────────────────────────────────────────────────

export default function UserProfilePage({ params }: { params: { userId: string } }) {
  const [activeTab, setActiveTab] = useState('activity');
  // In production, fetch user by params.userId. Using mock data here.
  const user = mockOtherUser;

  return (
    <motion.div
      className="max-w-3xl mx-auto px-4 sm:px-6 py-6 space-y-6"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
    >
      {/* Profile Header — isOwnProfile=false shows Follow button */}
      <ProfileHeader user={user} isOwnProfile={false} />

      {/* Tabs */}
      <div className="flex gap-1.5 overflow-x-auto no-scrollbar">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={cn(
                'shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold transition-all duration-200',
                activeTab === tab.id
                  ? 'text-white'
                  : 'text-secondary bg-white/5 border border-white/10 hover:text-primary'
              )}
              style={
                activeTab === tab.id
                  ? { background: 'linear-gradient(135deg, #6c63ff, #8b5cf6)' }
                  : {}
              }
            >
              <Icon size={13} />
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Tab Content */}

      {/* Activity */}
      {activeTab === 'activity' && (
        <motion.div variants={containerVariants} initial="hidden" animate="visible" className="space-y-3">
          {mockActivity.map((item) => {
            const Icon = item.icon;
            return (
              <motion.div key={item.id} variants={itemVariants} className="glass-card p-4 flex items-start gap-3">
                <div
                  className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                  style={{ background: `${item.color}20` }}
                >
                  <Icon size={16} style={{ color: item.color }} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-primary leading-tight">{item.text}</p>
                  <p className="text-xs text-secondary mt-0.5">{item.sub}</p>
                </div>
                <span className="text-[10px] text-secondary shrink-0">{formatTimeAgo(item.time)}</span>
              </motion.div>
            );
          })}
        </motion.div>
      )}

      {/* Courses */}
      {activeTab === 'courses' && (
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="visible"
          className="grid grid-cols-1 sm:grid-cols-2 gap-4"
        >
          {mockCourses.map((course) => (
            <motion.div
              key={course.id}
              variants={itemVariants}
              className="glass-card overflow-hidden cursor-pointer hover:border-white/20 transition-colors"
            >
              <div className={cn('h-24 bg-gradient-to-br flex items-center justify-center text-4xl', course.color)}>
                {course.emoji}
              </div>
              <div className="p-4 space-y-2">
                <h3 className="text-sm font-bold text-primary">{course.title}</h3>
                <p className="text-xs text-secondary">{course.category}</p>
                <div className="flex items-center justify-between">
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-green-500/20 text-green-400 font-semibold flex items-center gap-1">
                    <CheckCircle size={9} /> Completed
                  </span>
                  <span className="text-xs text-secondary">{course.completedAt}</span>
                </div>
                <div className="flex items-center gap-1 text-[11px]" style={{ color: '#f59e0b' }}>
                  <Zap size={11} fill="#f59e0b" />
                  +{course.xpEarned} XP earned
                </div>
              </div>
            </motion.div>
          ))}
        </motion.div>
      )}

      {/* Clips */}
      {activeTab === 'clips' && (
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="visible"
          className="grid grid-cols-3 gap-3"
        >
          {mockClips.map((clip) => (
            <motion.div
              key={clip.id}
              variants={itemVariants}
              className="relative aspect-[9/16] rounded-xl overflow-hidden cursor-pointer group"
            >
              <div className={cn('absolute inset-0 bg-gradient-to-br flex items-center justify-center text-4xl', clip.color)}>
                {clip.emoji}
              </div>
              <div className="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-all duration-200 flex items-center justify-center">
                <div className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-200 backdrop-blur-sm">
                  <Play size={16} className="text-white fill-white ml-0.5" />
                </div>
              </div>
              <div className="absolute bottom-2 left-2 right-2 flex items-center gap-1 text-[10px] text-white/90">
                <Eye size={10} />
                <span>{(clip.views / 1000).toFixed(1)}K</span>
              </div>
            </motion.div>
          ))}
        </motion.div>
      )}

      {/* Achievements */}
      {activeTab === 'achievements' && (
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="visible"
          className="grid grid-cols-2 sm:grid-cols-3 gap-3"
        >
          {mockAchievements.map((ach) => (
            <motion.div
              key={ach.id}
              variants={itemVariants}
              className={cn(
                'glass-card p-4 flex flex-col items-center gap-2 text-center transition-all duration-200',
                ach.unlocked ? 'cursor-pointer hover:scale-[1.02]' : 'opacity-50'
              )}
              style={ach.unlocked ? { borderColor: 'rgba(108,99,255,0.3)' } : {}}
            >
              <div
                className="w-14 h-14 rounded-2xl flex items-center justify-center text-2xl"
                style={
                  ach.unlocked
                    ? { background: 'linear-gradient(135deg, #6c63ff, #a78bfa)' }
                    : { background: 'rgba(255,255,255,0.08)' }
                }
              >
                {ach.unlocked ? ach.icon : <Lock size={20} className="text-white/30" />}
              </div>
              <div>
                <p className="text-xs font-bold text-primary leading-tight">{ach.title}</p>
                <p className="text-[10px] text-secondary mt-0.5 leading-snug">{ach.desc}</p>
              </div>
              <span
                className="text-[10px] font-bold px-2 py-0.5 rounded-full"
                style={
                  ach.unlocked
                    ? { background: 'rgba(245,158,11,0.15)', color: '#f59e0b' }
                    : { background: 'rgba(255,255,255,0.05)', color: 'var(--text-secondary)' }
                }
              >
                +{ach.xp} XP
              </span>
            </motion.div>
          ))}
        </motion.div>
      )}

      {/* Stats */}
      {activeTab === 'stats' && <LearningStatsPanel stats={mockStats} />}

      {/* Bottom spacer */}
      <div className="h-4" />
    </motion.div>
  );
}
