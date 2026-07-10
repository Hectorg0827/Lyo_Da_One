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
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import ProfileHeader from '@/components/profile/ProfileHeader';
import LearningStatsPanel from '@/components/profile/LearningStats';
import { cn, formatTimeAgo } from '@/lib/utils';
import type { LearningStats } from '@/types';

// ── Fallback color / emoji palettes for dynamic data ──

const courseGradients = [
  'from-blue-600 to-cyan-500',
  'from-pink-600 to-rose-500',
  'from-purple-600 to-indigo-500',
  'from-amber-500 to-orange-400',
  'from-green-600 to-teal-500',
];
const courseEmojis = ['📚', '🧠', '🎨', '🐍', '🎵', '⚛️'];
const clipGradients = [
  'from-blue-700 to-cyan-600',
  'from-pink-600 to-rose-500',
  'from-green-600 to-teal-500',
  'from-purple-600 to-indigo-500',
  'from-orange-500 to-amber-400',
  'from-violet-600 to-purple-500',
];
const clipEmojis = ['⚡', '🎨', '🐍', '⚛️', '🗄️', '📐'];
const activityIcons = [MessageCircle, BookOpen, Play, Trophy, CheckCircle];
const activityColorPalette = ['#6c63ff', '#22c55e', '#ec4899', '#f59e0b', '#3b82f6'];

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

// ── Types ───────────────────────────────────────────────────────────────────

type ActivityItem = {
  id: string;
  type: string;
  text: string;
  sub: string;
  icon: typeof Activity;
  color: string;
  time: string;
};

type CourseItem = {
  id: string;
  title: string;
  category: string;
  color: string;
  emoji: string;
  xpEarned: number;
  completedAt: string;
};

type ClipItem = {
  id: string;
  title: string;
  views: number;
  color: string;
  emoji: string;
};

type AchievementItem = {
  id: string;
  title: string;
  desc: string;
  xp: number;
  icon: string;
  unlocked: boolean;
};

// ── Main Page ────────────────────────────────────────────────────────────────

export default function UserProfilePage({ params }: { params: { userId: string } }) {
  const [activeTab, setActiveTab] = useState('activity');
  const [isFollowing, setIsFollowing] = useState(false);

  // ProfileHeader toggles its local state then calls this; mirror the
  // toggle against the backend so Follow actually persists.
  const handleFollow = () => {
    const next = !isFollowing;
    setIsFollowing(next);
    if (next) {
      api.users.follow(params.userId).catch(() => setIsFollowing(false));
    } else {
      api.users.unfollow(params.userId).catch(() => setIsFollowing(true));
    }
  };

  // Fetch user profile and related data via API
  const { data: user, isLoading: userLoading } = useApi(() => api.users.get(params.userId), [params.userId]);
  const { data: feedData } = useApi(() => api.users.posts(params.userId), [params.userId]);
  const { data: coursesRaw } = useApi(() => api.courses.list(0, 10), []);
  const { data: clipsRaw } = useApi(() => api.clips.list(1, 10), []);
  const { data: achievementsRaw } = useApi(() => api.gamification.achievements(), []);
  const { data: gamificationData } = useApi(() => api.gamification.overview(), []);

  // Map API responses to typed arrays

  const activity: ActivityItem[] = feedData?.posts
    ? feedData.posts.slice(0, 8).map((p: Record<string, unknown>, i: number) => ({
        id: String(p.id || i),
        type: 'post',
        text: String(p.content || '').slice(0, 80),
        sub: `${p.like_count || 0} likes · ${p.comment_count || 0} comments`,
        icon: activityIcons[i % activityIcons.length],
        color: activityColorPalette[i % activityColorPalette.length],
        time: (p.created_at as string) || new Date().toISOString(),
      }))
    : [];

  const courses: CourseItem[] = coursesRaw
    ? (coursesRaw as Record<string, unknown>[]).map((c, i) => ({
        id: String(c.id || i),
        title: (c.title as string) || 'Untitled',
        category: (c.subject as string) || 'General',
        color: courseGradients[i % courseGradients.length],
        emoji: courseEmojis[i % courseEmojis.length],
        xpEarned: 500,
        completedAt: (c.created_at as string)?.slice(0, 10) || '',
      }))
    : [];

  const clips: ClipItem[] = clipsRaw?.clips
    ? clipsRaw.clips.map((c: Record<string, unknown>, i: number) => ({
        id: String(c.id || i),
        title: (c.title as string) || 'Untitled',
        views: (c.view_count as number) || (c.views as number) || 0,
        color: clipGradients[i % clipGradients.length],
        emoji: clipEmojis[i % clipEmojis.length],
      }))
    : [];

  const achievements: AchievementItem[] = achievementsRaw
    ? achievementsRaw.map((a: Record<string, unknown>, i: number) => ({
        id: String(a.id || i),
        title: (a.name as string) || (a.achievement_name as string) || 'Achievement',
        desc: (a.description as string) || '',
        xp: (a.xp_reward as number) || 100,
        icon: (a.icon as string) || '🏆',
        unlocked: (a.completed as boolean) || (a.is_completed as boolean) || false,
      }))
    : [];

  const stats: LearningStats = {
    totalHoursLearned: (gamificationData?.xp_summary as Record<string, unknown>)?.total
      ? Math.round(((gamificationData?.xp_summary as Record<string, unknown>)?.total as number) / 50)
      : 0,
    coursesCompleted: user?.coursesCompleted || 0,
    coursesInProgress: courses.length,
    quizzesPassed: 0,
    currentStreak: user?.streak || 0,
    longestStreak: (gamificationData?.streaks as Record<string, unknown>)?.longest as number || 0,
    xpThisWeek: (gamificationData?.xp_summary as Record<string, unknown>)?.this_week as number || 0,
    topTopics: [],
  };

  // Show nothing while user data is loading
  if (userLoading || !user) return null;

  return (
    <motion.div
      className="max-w-3xl mx-auto px-4 sm:px-6 py-6 space-y-6"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
    >
      {/* Profile Header — isOwnProfile=false shows Follow button */}
      <ProfileHeader user={user} isOwnProfile={false} onFollow={handleFollow} />

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
          {activity.map((item) => {
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
          {courses.map((course) => (
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
          {clips.map((clip) => (
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
          {achievements.map((ach) => (
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
      {activeTab === 'stats' && <LearningStatsPanel stats={stats} />}

      {/* Bottom spacer */}
      <div className="h-4" />
    </motion.div>
  );
}
