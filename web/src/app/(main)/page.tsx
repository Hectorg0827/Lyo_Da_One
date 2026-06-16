'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
  Flame,
  Clock,
  BookOpen,
  Zap,
  Star,
  ChevronRight,
  Brain,
  Sparkles,
  Play,
  Users,
  Heart,
  MessageCircle,
  Trophy,
  Target,
  TrendingUp,
  Layers,
} from 'lucide-react';
import Link from 'next/link';
import { useAuthStore } from '@/stores/auth-store';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';

// ── Daily challenges (TODO: wire to gamification challenges when endpoint available) ──

const dailyChallenges = [
  {
    id: '1',
    title: 'Complete 2 Lessons',
    description: 'Finish any 2 lessons in your active courses',
    xpReward: 150,
    progress: 1,
    requirement: 2,
    icon: BookOpen,
    color: '#6c63ff',
  },
  {
    id: '2',
    title: '10-Minute Learning Sprint',
    description: 'Study for 10 uninterrupted minutes',
    xpReward: 100,
    progress: 7,
    requirement: 10,
    icon: Clock,
    color: '#3b82f6',
  },
  {
    id: '3',
    title: 'Quiz Master',
    description: 'Score 80% or higher on a quiz',
    xpReward: 200,
    progress: 0,
    requirement: 1,
    icon: Target,
    color: '#f59e0b',
  },
];

// Color palette for dynamically mapped courses
const courseColors = ['#6c63ff', '#ec4899', '#22c55e', '#f59e0b', '#3b82f6'];
const courseEmojis = ['📚', '🧠', '🎨', '🐍', '🎵', '⚛️'];
const gradientPairs = [
  'from-[#6c63ff] to-[#8b5cf6]',
  'from-[#ec4899] to-[#f43f5e]',
  'from-[#3b82f6] to-[#06b6d4]',
  'from-[#f59e0b] to-[#ef4444]',
  'from-[#22c55e] to-[#14b8a6]',
];
const activityColors = ['#6c63ff', '#22c55e', '#ec4899', '#3b82f6', '#f59e0b'];

// ── Helpers ────────────────────────────────────────────────────────────────────

function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

function formatDate() {
  return new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });
}

function formatTimeAgoShort(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

// ── Animation variants ─────────────────────────────────────────────────────────

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.08, delayChildren: 0.1 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.4, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] },
  },
};

// ── Sub-components ─────────────────────────────────────────────────────────────

function SectionHeader({
  title,
  href,
  icon: Icon,
}: {
  title: string;
  href?: string;
  icon?: React.ComponentType<{ size?: number | string; className?: string }>;
}) {
  return (
    <div className="flex items-center justify-between mb-4">
      <div className="flex items-center gap-2">
        {Icon && <Icon size={18} className="text-secondary" />}
        <h2 className="text-base font-bold text-primary">{title}</h2>
      </div>
      {href && (
        <Link
          href={href}
          className="flex items-center gap-1 text-xs font-medium text-secondary hover:text-primary transition-colors duration-200"
        >
          See all <ChevronRight size={14} />
        </Link>
      )}
    </div>
  );
}

function ProgressBar({
  value,
  color = '#6c63ff',
  height = 4,
}: {
  value: number;
  color?: string;
  height?: number;
}) {
  return (
    <div
      className="w-full rounded-full overflow-hidden"
      style={{ height, backgroundColor: 'rgba(255,255,255,0.08)' }}
    >
      <div
        className="h-full rounded-full transition-all duration-700"
        style={{ width: `${Math.min(100, Math.max(0, value))}%`, backgroundColor: color }}
      />
    </div>
  );
}

function MiniAvatar({
  initials,
  color,
  size = 36,
}: {
  initials: string;
  color: string;
  size?: number;
}) {
  return (
    <div
      className="rounded-full flex items-center justify-center shrink-0 font-bold text-white select-none"
      style={{ width: size, height: size, backgroundColor: color, fontSize: size * 0.38 }}
    >
      {initials}
    </div>
  );
}

// ── Main Page ──────────────────────────────────────────────────────────────────

export default function HomePage() {
  const { user } = useAuthStore();
  const [mounted, setMounted] = useState(false);

  const { data: gamification } = useApi(() => api.gamification.overview(), []);
  const { data: courses } = useApi(() => api.courses.list(0, 4), []);
  const { data: feedData } = useApi(() => api.feed.publicFeed(1, 3), []);

  useEffect(() => {
    setMounted(true);
  }, []);

  const firstName = user?.displayName.split(' ')[0] ?? 'Learner';

  // Derive streak from gamification or user profile
  const streakData = gamification?.streaks as Record<string, unknown> | undefined;
  const currentStreak = (streakData?.current as number) || user?.streak || 0;
  const bestStreak = (streakData?.longest as number) || (streakData?.best as number) || currentStreak;

  // Derive stats from gamification overview
  const xpSummary = gamification?.xp_summary as Record<string, unknown> | undefined;
  const userLevel = gamification?.user_level as Record<string, unknown> | undefined;
  const achievementsData = gamification?.achievements as Record<string, unknown> | undefined;
  const learningStats = [
    {
      label: 'Hours Learned',
      value: String((userLevel?.total_hours as number) || user?.xp ? Math.round((user?.xp || 0) / 100) : 0),
      sub: 'total',
      icon: Clock,
      color: '#6c63ff',
      trend: '',
    },
    {
      label: 'Courses Done',
      value: String((achievementsData?.completed as number) || user?.coursesCompleted || 0),
      sub: 'total completed',
      icon: BookOpen,
      color: '#22c55e',
      trend: '',
    },
    {
      label: 'XP Earned',
      value: String((xpSummary?.total as number) || user?.xp || 0),
      sub: 'total',
      icon: Zap,
      color: '#f59e0b',
      trend: `Level ${(userLevel?.level as number) || user?.level || 1}`,
    },
    {
      label: 'Streak',
      value: `${currentStreak}d`,
      sub: 'current',
      icon: Trophy,
      color: '#ec4899',
      trend: bestStreak > currentStreak ? `Best: ${bestStreak}d` : '',
    },
  ];

  // Map API courses to display format
  const inProgressCourses = (courses || []).map((c: Record<string, unknown>, i: number) => ({
    id: String(c.id ?? i),
    title: (c.title as string) || 'Untitled Course',
    category: (c.subject as string) || (c.category as string) || 'General',
    progress: (c.progress as number) || 0,
    color: courseColors[i % courseColors.length],
    emoji: courseEmojis[i % courseEmojis.length],
    timeLeft: c.estimated_duration ? `${c.estimated_duration}h total` : '',
  }));

  // Map API courses to recommended format
  const recommendedCourses = (courses || []).map((c: Record<string, unknown>, i: number) => ({
    id: String(c.id ?? i),
    title: (c.title as string) || 'Untitled Course',
    category: (c.subject as string) || (c.category as string) || 'General',
    duration: c.estimated_duration ? `${c.estimated_duration}h` : '?',
    students: c.enrolled_count ? `${c.enrolled_count}` : '0',
    rating: (c.rating as number) || 0,
    difficulty: (c.difficulty as string) || 'Beginner',
    emoji: courseEmojis[i % courseEmojis.length],
    color: gradientPairs[i % gradientPairs.length],
    isAI: (c.is_ai_generated as boolean) || false,
  }));

  // Map feed posts to community activity format
  const feedPosts = (feedData?.posts || []) as Record<string, unknown>[];
  const communityActivity = feedPosts.map((post: Record<string, unknown>, i: number) => {
    const author = post.author as Record<string, unknown> | undefined;
    const authorName = (author?.display_name as string) || (author?.username as string) || 'User';
    const initials = authorName
      .split(' ')
      .map((w: string) => w[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();
    return {
      id: String(post.id ?? i),
      author: authorName,
      username: (author?.username as string) || '',
      initials,
      color: activityColors[i % activityColors.length],
      action: 'posted',
      content: (post.content as string) || '',
      likes: (post.likes_count as number) || (post.likes as number) || 0,
      comments: (post.comments_count as number) || (post.comments as number) || 0,
      timeAgo: post.created_at ? formatTimeAgoShort(post.created_at as string) : '',
      type: (post.type as string) || 'post',
    };
  });

  return (
    <motion.div
      className="max-w-5xl mx-auto px-4 sm:px-6 py-6 space-y-8"
      variants={containerVariants}
      initial="hidden"
      animate={mounted ? 'visible' : 'hidden'}
    >
      {/* ── Greeting ──────────────────────────────────────────── */}
      <motion.div variants={itemVariants} className="flex items-start justify-between gap-4">
        <div>
          <p className="text-sm text-secondary mb-1">{mounted ? formatDate() : ''}</p>
          <h1 className="text-2xl sm:text-3xl font-black text-primary leading-tight">
            {getGreeting()},{' '}
            <span className="gradient-text">{firstName}</span> 👋
          </h1>
          <p className="text-sm text-secondary mt-1">
            You&apos;re on a roll — {currentStreak}-day streak and counting!
          </p>
        </div>
        {/* Quick streak badge */}
        <div
          className="glass-card px-4 py-2.5 flex items-center gap-2 shrink-0"
          style={{ borderColor: 'rgba(245,158,11,0.3)', background: 'rgba(245,158,11,0.08)' }}
        >
          <Flame size={20} className="text-orange-400" />
          <div className="text-right">
            <p className="text-lg font-black text-orange-400 leading-none">{currentStreak}</p>
            <p className="text-[10px] text-secondary">day streak</p>
          </div>
        </div>
      </motion.div>

      {/* ── Streak hero card ──────────────────────────────────── */}
      <motion.div
        variants={itemVariants}
        className="relative overflow-hidden rounded-2xl p-5 sm:p-6"
        style={{
          background: 'linear-gradient(135deg, rgba(245,158,11,0.18) 0%, rgba(239,68,68,0.12) 60%, rgba(17,17,24,0.4) 100%)',
          border: '1px solid rgba(245,158,11,0.25)',
          backdropFilter: 'blur(12px)',
        }}
      >
        {/* Background orb */}
        <div
          className="absolute -right-8 -top-8 w-40 h-40 rounded-full blur-3xl pointer-events-none opacity-30"
          style={{ background: 'radial-gradient(circle, #f59e0b, #ef4444)' }}
        />
        <div className="relative flex items-center gap-4">
          <div
            className="w-14 h-14 rounded-2xl flex items-center justify-center shadow-lg shrink-0"
            style={{ background: 'linear-gradient(135deg, #f59e0b, #ef4444)' }}
          >
            <Flame size={28} className="text-white" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-baseline gap-2">
              <span className="text-3xl font-black text-white">{currentStreak}</span>
              <span className="text-base font-semibold text-orange-300">day streak</span>
            </div>
            <p className="text-sm text-orange-200/80 mt-0.5">
              Keep it up! You&apos;re in the top 8% of learners this week 🏆
            </p>
          </div>
          <div className="hidden sm:flex flex-col items-end gap-1 shrink-0">
            <span className="text-xs text-orange-300/70">Best streak</span>
            <span className="text-sm font-bold text-orange-300">{bestStreak} days</span>
          </div>
        </div>
        {/* Day dots */}
        <div className="mt-4 flex gap-1.5">
          {Array.from({ length: 14 }).map((_, i) => {
            const isActive = i < (currentStreak);
            return (
              <div
                key={i}
                className="flex-1 h-1.5 rounded-full transition-all duration-300"
                style={{
                  background: isActive
                    ? 'linear-gradient(90deg,#f59e0b,#ef4444)'
                    : 'rgba(255,255,255,0.1)',
                }}
              />
            );
          })}
        </div>
      </motion.div>

      {/* ── Quick Actions ─────────────────────────────────────── */}
      <motion.div variants={itemVariants}>
        <SectionHeader title="Quick Actions" icon={Sparkles} />
        <div className="grid grid-cols-3 gap-3">
          <Link
            href="/chat"
            className="group relative overflow-hidden rounded-xl p-4 flex flex-col gap-2 transition-transform duration-200 hover:scale-[1.02] active:scale-[0.98]"
            style={{ background: 'linear-gradient(135deg, #6c63ff 0%, #8b5cf6 100%)' }}
          >
            <div className="absolute inset-0 bg-white/10 opacity-0 group-hover:opacity-100 transition-opacity duration-200" />
            <Brain size={22} className="text-white relative z-10" />
            <div className="relative z-10">
              <p className="text-sm font-bold text-white leading-tight">Ask LYO</p>
              <p className="text-[11px] text-white/70">AI tutor</p>
            </div>
          </Link>
          <Link
            href="/discover"
            className="glass-card group p-4 flex flex-col gap-2 transition-all duration-200 hover:scale-[1.02] active:scale-[0.98] hover:bg-white/[0.07]"
          >
            <Layers size={22} className="text-[#6c63ff]" />
            <div>
              <p className="text-sm font-bold text-primary leading-tight">Browse</p>
              <p className="text-[11px] text-secondary">Courses</p>
            </div>
          </Link>
          <Link
            href="/clips"
            className="glass-card group p-4 flex flex-col gap-2 transition-all duration-200 hover:scale-[1.02] active:scale-[0.98] hover:bg-white/[0.07]"
          >
            <Play size={22} className="text-accent-pink" style={{ color: '#ec4899' }} />
            <div>
              <p className="text-sm font-bold text-primary leading-tight">Watch</p>
              <p className="text-[11px] text-secondary">Clips</p>
            </div>
          </Link>
        </div>
      </motion.div>

      {/* ── Continue Learning ─────────────────────────────────── */}
      <motion.div variants={itemVariants}>
        <SectionHeader title="Continue Learning" href="/courses" icon={BookOpen} />
        {inProgressCourses.length === 0 ? (
          <Link
            href="/discover"
            className="glass-card p-6 flex flex-col items-center gap-2 text-center transition-all duration-200 hover:bg-white/[0.07]"
          >
            <BookOpen size={28} className="text-secondary" />
            <p className="text-sm font-semibold text-primary">Start learning</p>
            <p className="text-xs text-secondary">Browse courses and begin your journey</p>
          </Link>
        ) : (
          <div className="flex gap-3 overflow-x-auto no-scrollbar pb-2 -mx-4 px-4 sm:mx-0 sm:px-0 sm:grid sm:grid-cols-2 sm:overflow-visible">
            {inProgressCourses.map((course) => (
              <Link
                key={course.id}
                href={`/courses/${course.id}`}
                className="glass-card p-4 flex flex-col gap-3 transition-all duration-200 hover:scale-[1.02] hover:bg-white/[0.07] shrink-0 w-52 sm:w-auto"
              >
                <div className="flex items-start gap-3">
                  <div
                    className="w-10 h-10 rounded-xl flex items-center justify-center text-xl shrink-0"
                    style={{ backgroundColor: `${course.color}20`, border: `1px solid ${course.color}30` }}
                  >
                    {course.emoji}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-primary leading-tight line-clamp-2">
                      {course.title}
                    </p>
                    <p className="text-[11px] text-secondary mt-0.5">{course.category}</p>
                  </div>
                </div>
                <div className="space-y-1.5">
                  <div className="flex justify-between items-center">
                    <span className="text-[11px] text-secondary">{course.progress}% complete</span>
                    <span className="text-[11px] text-secondary">{course.timeLeft}</span>
                  </div>
                  <ProgressBar value={course.progress} color={course.color} height={4} />
                </div>
              </Link>
            ))}
          </div>
        )}
      </motion.div>

      {/* ── Learning Stats ────────────────────────────────────── */}
      <motion.div variants={itemVariants}>
        <SectionHeader title="Your Stats" icon={TrendingUp} />
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {learningStats.map((stat) => {
            const Icon = stat.icon;
            return (
              <div key={stat.label} className="glass-card p-4 space-y-2">
                <div
                  className="w-8 h-8 rounded-lg flex items-center justify-center"
                  style={{ backgroundColor: `${stat.color}20` }}
                >
                  <Icon size={16} style={{ color: stat.color }} />
                </div>
                <div>
                  <p className="text-xl font-black text-primary leading-none">{stat.value}</p>
                  <p className="text-[11px] text-secondary mt-0.5">{stat.label}</p>
                </div>
                <p className="text-[10px] font-medium" style={{ color: stat.color }}>
                  {stat.trend}
                </p>
              </div>
            );
          })}
        </div>
      </motion.div>

      {/* ── Daily Challenges ──────────────────────────────────── */}
      <motion.div variants={itemVariants}>
        <SectionHeader title="Daily Challenges" href="/challenges" icon={Target} />
        <div className="space-y-3">
          {dailyChallenges.map((challenge) => {
            const Icon = challenge.icon;
            const pct = Math.round((challenge.progress / challenge.requirement) * 100);
            const isDone = challenge.progress >= challenge.requirement;

            return (
              <div
                key={challenge.id}
                className={cn(
                  'glass-card p-4 flex items-center gap-4 transition-all duration-200',
                  isDone && 'opacity-70'
                )}
              >
                <div
                  className="w-11 h-11 rounded-xl flex items-center justify-center shrink-0"
                  style={{ backgroundColor: `${challenge.color}20`, border: `1px solid ${challenge.color}25` }}
                >
                  <Icon size={20} style={{ color: challenge.color }} />
                </div>
                <div className="flex-1 min-w-0 space-y-1.5">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-sm font-semibold text-primary truncate">{challenge.title}</p>
                    <span
                      className="text-xs font-bold px-2 py-0.5 rounded-full shrink-0"
                      style={{
                        backgroundColor: `${challenge.color}20`,
                        color: challenge.color,
                      }}
                    >
                      +{challenge.xpReward} XP
                    </span>
                  </div>
                  <p className="text-[11px] text-secondary truncate">{challenge.description}</p>
                  <div className="flex items-center gap-2">
                    <ProgressBar value={pct} color={challenge.color} height={3} />
                    <span className="text-[10px] text-secondary shrink-0 w-16 text-right">
                      {isDone ? '✓ Done' : `${challenge.progress}/${challenge.requirement}`}
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </motion.div>

      {/* ── Recommended For You ───────────────────────────────── */}
      <motion.div variants={itemVariants}>
        <SectionHeader title="Recommended For You" href="/discover" icon={Star} />
        {recommendedCourses.length === 0 ? (
          <div className="glass-card p-6 flex flex-col items-center gap-2 text-center">
            <Star size={28} className="text-secondary" />
            <p className="text-sm text-secondary">Recommendations will appear as you learn more</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {recommendedCourses.map((course) => (
              <Link
                key={course.id}
                href={`/courses/${course.id}`}
                className="glass-card overflow-hidden group transition-all duration-200 hover:scale-[1.01] hover:bg-white/[0.06]"
              >
                {/* Course header gradient */}
                <div
                  className={cn('h-20 w-full flex items-center justify-center text-4xl relative', `bg-gradient-to-br ${course.color}`)}
                >
                  {course.isAI && (
                    <span
                      className="absolute top-2 left-2 text-[10px] font-bold px-2 py-0.5 rounded-full flex items-center gap-1"
                      style={{ background: 'rgba(0,0,0,0.35)', color: '#fff' }}
                    >
                      <Sparkles size={9} /> AI
                    </span>
                  )}
                  {course.emoji}
                </div>
                <div className="p-4 space-y-2">
                  <div className="flex items-start justify-between gap-2">
                    <p className="text-sm font-bold text-primary leading-tight flex-1">{course.title}</p>
                  </div>
                  <p className="text-[11px] text-secondary">{course.category}</p>
                  <div className="flex items-center gap-3 text-[11px] text-secondary">
                    <span className="flex items-center gap-1">
                      <Clock size={11} /> {course.duration}
                    </span>
                    <span className="flex items-center gap-1">
                      <Users size={11} /> {course.students}
                    </span>
                    {course.rating > 0 && (
                      <span className="flex items-center gap-1">
                        <Star size={11} className="text-yellow-400" /> {course.rating}
                      </span>
                    )}
                    <span
                      className="ml-auto text-[10px] px-2 py-0.5 rounded-full font-medium"
                      style={{
                        backgroundColor:
                          course.difficulty === 'beginner' || course.difficulty === 'Beginner'
                            ? 'rgba(34,197,94,0.15)'
                            : course.difficulty === 'advanced' || course.difficulty === 'Advanced'
                            ? 'rgba(239,68,68,0.15)'
                            : 'rgba(108,99,255,0.15)',
                        color:
                          course.difficulty === 'beginner' || course.difficulty === 'Beginner'
                            ? '#22c55e'
                            : course.difficulty === 'advanced' || course.difficulty === 'Advanced'
                            ? '#ef4444'
                            : '#8b83ff',
                      }}
                    >
                      {course.difficulty}
                    </span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </motion.div>

      {/* ── Recent Community Activity ─────────────────────────── */}
      <motion.div variants={itemVariants}>
        <SectionHeader title="Community Activity" href="/community" icon={Users} />
        {communityActivity.length === 0 ? (
          <div className="glass-card p-6 flex flex-col items-center gap-2 text-center">
            <Users size={28} className="text-secondary" />
            <p className="text-sm text-secondary">No community activity yet</p>
          </div>
        ) : (
          <div className="space-y-3">
            {communityActivity.map((post) => (
              <div key={post.id} className="glass-card p-4 space-y-3">
                <div className="flex items-start gap-3">
                  <MiniAvatar initials={post.initials} color={post.color} size={38} />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <span className="text-sm font-bold text-primary">{post.author}</span>
                      <span className="text-[11px] text-secondary">{post.action}</span>
                      <span className="text-[11px] text-secondary ml-auto">{post.timeAgo}</span>
                    </div>
                    <p className="text-sm text-secondary leading-relaxed mt-1 line-clamp-3">
                      {post.content}
                    </p>
                  </div>
                </div>
                <div
                  className="flex items-center gap-4 pt-1"
                  style={{ borderTop: '1px solid rgba(255,255,255,0.05)' }}
                >
                  <button className="flex items-center gap-1.5 text-[11px] text-secondary hover:text-red-400 transition-colors duration-150">
                    <Heart size={13} /> {post.likes}
                  </button>
                  <button className="flex items-center gap-1.5 text-[11px] text-secondary hover:text-[#6c63ff] transition-colors duration-150">
                    <MessageCircle size={13} /> {post.comments}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </motion.div>

      {/* ── Bottom spacer for mobile nav ─────────────────────── */}
      <div className="h-2 md:h-4" />
    </motion.div>
  );
}
