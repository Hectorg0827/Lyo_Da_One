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
  Clock,
  CheckCircle,
  MessageCircle,
  FileText,
  Lock,
  Zap,
} from 'lucide-react';
import { useAuthStore } from '@/stores/auth-store';
import ProfileHeader from '@/components/profile/ProfileHeader';
import LearningStatsPanel from '@/components/profile/LearningStats';
import { cn, formatTimeAgo } from '@/lib/utils';
import type { LearningStats } from '@/types';

// ── Mock Data ────────────────────────────────────────────────────────────────

const mockStats: LearningStats = {
  totalHoursLearned: 142,
  coursesCompleted: 23,
  coursesInProgress: 4,
  quizzesPassed: 87,
  currentStreak: 12,
  longestStreak: 21,
  xpThisWeek: 1240,
  topTopics: [
    { topic: 'Machine Learning', hours: 38 },
    { topic: 'Python', hours: 29 },
    { topic: 'UI/UX Design', hours: 22 },
    { topic: 'Mathematics', hours: 18 },
    { topic: 'Music Theory', hours: 12 },
  ],
};

const mockActivity = [
  {
    id: '1',
    type: 'course_complete',
    text: 'Completed "Python for Data Science"',
    sub: 'Earned 500 XP',
    icon: CheckCircle,
    color: '#22c55e',
    time: '2024-06-14T10:30:00Z',
  },
  {
    id: '2',
    type: 'clip_posted',
    text: 'Posted a clip: "Quick Sort in 60 seconds"',
    sub: '247 views · 34 likes',
    icon: Play,
    color: '#ec4899',
    time: '2024-06-13T16:00:00Z',
  },
  {
    id: '3',
    type: 'post_created',
    text: 'Asked a question in the community',
    sub: '"Best resources for learning Rust?"',
    icon: MessageCircle,
    color: '#6c63ff',
    time: '2024-06-12T09:45:00Z',
  },
  {
    id: '4',
    type: 'achievement',
    text: 'Unlocked Achievement: "Week Warrior"',
    sub: '7-day streak milestone · +200 XP',
    icon: Trophy,
    color: '#f59e0b',
    time: '2024-06-10T18:00:00Z',
  },
  {
    id: '5',
    type: 'course_enrolled',
    text: 'Enrolled in "Advanced React Patterns"',
    sub: 'Intermediate · 8 hours',
    icon: BookOpen,
    color: '#3b82f6',
    time: '2024-06-09T11:20:00Z',
  },
];

const mockCompletedCourses = [
  {
    id: '1',
    title: 'Python for Data Science',
    category: 'Programming',
    color: 'from-blue-600 to-cyan-500',
    emoji: '🐍',
    rating: 4.9,
    completedAt: '2024-06-14',
    xpEarned: 500,
  },
  {
    id: '2',
    title: 'UI/UX Design Fundamentals',
    category: 'Design',
    color: 'from-pink-600 to-rose-500',
    emoji: '🎨',
    rating: 4.8,
    completedAt: '2024-05-28',
    xpEarned: 450,
  },
  {
    id: '3',
    title: 'Machine Learning Basics',
    category: 'AI & ML',
    color: 'from-purple-600 to-indigo-500',
    emoji: '🤖',
    rating: 4.7,
    completedAt: '2024-05-10',
    xpEarned: 600,
  },
  {
    id: '4',
    title: 'Music Theory Essentials',
    category: 'Music',
    color: 'from-amber-500 to-orange-400',
    emoji: '🎵',
    rating: 4.6,
    completedAt: '2024-04-22',
    xpEarned: 350,
  },
];

const mockClips = [
  { id: '1', title: 'Quick Sort in 60s', views: 247, color: 'from-blue-700 to-cyan-600', emoji: '⚡' },
  { id: '2', title: 'CSS Grid Tricks', views: 1820, color: 'from-pink-600 to-rose-500', emoji: '🎨' },
  { id: '3', title: 'Python List Comprehensions', views: 3401, color: 'from-green-600 to-teal-500', emoji: '🐍' },
  { id: '4', title: 'React Hooks Explained', views: 5782, color: 'from-purple-600 to-indigo-500', emoji: '⚛️' },
  { id: '5', title: 'SQL Joins Visual', views: 892, color: 'from-orange-500 to-amber-400', emoji: '🗄️' },
  { id: '6', title: 'Linear Algebra Basics', views: 1130, color: 'from-violet-600 to-purple-500', emoji: '📐' },
];

const mockAchievements = [
  { id: '1', title: 'First Step', desc: 'Complete your first lesson', xp: 50, icon: '🎯', unlocked: true },
  { id: '2', title: 'Week Warrior', desc: '7-day learning streak', xp: 200, icon: '🔥', unlocked: true },
  { id: '3', title: 'Quiz Master', desc: 'Pass 10 quizzes with 80%+', xp: 300, icon: '🧠', unlocked: true },
  { id: '4', title: 'Course Graduate', desc: 'Complete 5 courses', xp: 500, icon: '🎓', unlocked: true },
  { id: '5', title: 'Speed Learner', desc: 'Finish a course in one day', xp: 400, icon: '⚡', unlocked: true },
  { id: '6', title: 'Social Star', desc: 'Get 100 followers', xp: 250, icon: '⭐', unlocked: false },
  { id: '7', title: 'Content Creator', desc: 'Post 10 clips', xp: 300, icon: '🎬', unlocked: false },
  { id: '8', title: 'Legend Streak', desc: '30-day learning streak', xp: 1000, icon: '🏆', unlocked: false },
  { id: '9', title: 'Top Contributor', desc: 'Help 50 learners', xp: 600, icon: '🤝', unlocked: false },
  { id: '10', title: 'Master Mind', desc: 'Reach Level 20', xp: 800, icon: '💎', unlocked: false },
  { id: '11', title: 'Marathon Learner', desc: 'Learn 100 hours total', xp: 700, icon: '🏅', unlocked: false },
  { id: '12', title: 'XP Millionaire', desc: 'Earn 10,000 XP total', xp: 1000, icon: '💰', unlocked: false },
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

export default function ProfilePage() {
  const { user } = useAuthStore();
  const [activeTab, setActiveTab] = useState('activity');

  if (!user) return null;

  return (
    <motion.div
      className="max-w-3xl mx-auto px-4 sm:px-6 py-6 space-y-6"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
    >
      {/* Profile Header */}
      <ProfileHeader user={user} isOwnProfile={true} />

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
          {mockCompletedCourses.map((course) => (
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
              {/* Play overlay */}
              <div className="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-all duration-200 flex items-center justify-center">
                <div className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-200 backdrop-blur-sm">
                  <Play size={16} className="text-white fill-white ml-0.5" />
                </div>
              </div>
              {/* Views badge */}
              <div className="absolute bottom-2 left-2 right-2 flex items-center gap-1 text-[10px] text-white/90">
                <Eye size={10} />
                <span>{clip.views.toLocaleString()}</span>
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
              style={
                ach.unlocked
                  ? { borderColor: 'rgba(108,99,255,0.3)' }
                  : {}
              }
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
      {activeTab === 'stats' && (
        <LearningStatsPanel stats={mockStats} />
      )}

      {/* Bottom spacer */}
      <div className="h-4" />
    </motion.div>
  );
}
