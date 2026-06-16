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
import { cn } from '@/lib/utils';

// ── Mock data ──────────────────────────────────────────────────────────────────

const inProgressCourses = [
  {
    id: '1',
    title: 'Machine Learning Fundamentals',
    category: 'AI & ML',
    progress: 68,
    color: '#6c63ff',
    emoji: '🤖',
    timeLeft: '3h 20m left',
  },
  {
    id: '2',
    title: 'UI/UX Design Principles',
    category: 'Design',
    progress: 42,
    color: '#ec4899',
    emoji: '🎨',
    timeLeft: '5h 10m left',
  },
  {
    id: '3',
    title: 'Python for Data Science',
    category: 'Programming',
    progress: 81,
    color: '#22c55e',
    emoji: '🐍',
    timeLeft: '1h 45m left',
  },
  {
    id: '4',
    title: 'Music Theory Basics',
    category: 'Music',
    progress: 25,
    color: '#f59e0b',
    emoji: '🎵',
    timeLeft: '8h 0m left',
  },
];

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

const learningStats = [
  {
    label: 'Hours Learned',
    value: '14.5',
    sub: 'this week',
    icon: Clock,
    color: '#6c63ff',
    trend: '+2.3h vs last week',
  },
  {
    label: 'Courses Done',
    value: '23',
    sub: 'total completed',
    icon: BookOpen,
    color: '#22c55e',
    trend: '2 this month',
  },
  {
    label: 'XP Earned',
    value: '1,240',
    sub: 'this week',
    icon: Zap,
    color: '#f59e0b',
    trend: 'Top 15%',
  },
  {
    label: 'Ranking',
    value: '#128',
    sub: 'on leaderboard',
    icon: Trophy,
    color: '#ec4899',
    trend: 'Up 34 spots',
  },
];

const recommendedCourses = [
  {
    id: '1',
    title: 'Deep Learning with PyTorch',
    category: 'AI & ML',
    duration: '12h',
    students: '8.4k',
    rating: 4.9,
    difficulty: 'Intermediate',
    emoji: '🧠',
    color: 'from-[#6c63ff] to-[#8b5cf6]',
    isAI: true,
  },
  {
    id: '2',
    title: 'Figma for Product Designers',
    category: 'Design',
    duration: '6h',
    students: '12.1k',
    rating: 4.8,
    difficulty: 'Beginner',
    emoji: '✏️',
    color: 'from-[#ec4899] to-[#f43f5e]',
    isAI: false,
  },
  {
    id: '3',
    title: 'React & Next.js Mastery',
    category: 'Programming',
    duration: '18h',
    students: '15.7k',
    rating: 4.9,
    difficulty: 'Advanced',
    emoji: '⚛️',
    color: 'from-[#3b82f6] to-[#06b6d4]',
    isAI: false,
  },
  {
    id: '4',
    title: 'Music Production 101',
    category: 'Music',
    duration: '9h',
    students: '5.2k',
    rating: 4.7,
    difficulty: 'Beginner',
    emoji: '🎧',
    color: 'from-[#f59e0b] to-[#ef4444]',
    isAI: true,
  },
];

const communityActivity = [
  {
    id: '1',
    author: 'Maya Chen',
    username: 'mayalearns',
    initials: 'MC',
    color: '#6c63ff',
    action: 'shared a course',
    content: 'Just finished "Neural Networks from Scratch" — absolutely mind-bending! Highly recommend for anyone serious about ML.',
    likes: 47,
    comments: 12,
    timeAgo: '15 min ago',
    type: 'course_share',
  },
  {
    id: '2',
    author: 'Jordan Park',
    username: 'jparkdev',
    initials: 'JP',
    color: '#22c55e',
    action: 'hit a milestone',
    content: '🔥 30-day learning streak! Started with zero Python knowledge. Now building my first ML model. LYO changed my life.',
    likes: 134,
    comments: 28,
    timeAgo: '42 min ago',
    type: 'achievement',
  },
  {
    id: '3',
    author: 'Sofia Martinez',
    username: 'sofiadesigns',
    initials: 'SM',
    color: '#ec4899',
    action: 'asked a question',
    content: 'What\'s the best approach for responsive typography in Figma? Trying to create consistent scale across breakpoints.',
    likes: 19,
    comments: 35,
    timeAgo: '1h ago',
    type: 'question',
  },
];

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

  useEffect(() => {
    setMounted(true);
  }, []);

  const firstName = user?.displayName.split(' ')[0] ?? 'Learner';

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
            You&apos;re on a roll — {user?.streak ?? 12}-day streak and counting!
          </p>
        </div>
        {/* Quick streak badge */}
        <div
          className="glass-card px-4 py-2.5 flex items-center gap-2 shrink-0"
          style={{ borderColor: 'rgba(245,158,11,0.3)', background: 'rgba(245,158,11,0.08)' }}
        >
          <Flame size={20} className="text-orange-400" />
          <div className="text-right">
            <p className="text-lg font-black text-orange-400 leading-none">{user?.streak ?? 12}</p>
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
              <span className="text-3xl font-black text-white">{user?.streak ?? 12}</span>
              <span className="text-base font-semibold text-orange-300">day streak</span>
            </div>
            <p className="text-sm text-orange-200/80 mt-0.5">
              Keep it up! You&apos;re in the top 8% of learners this week 🏆
            </p>
          </div>
          <div className="hidden sm:flex flex-col items-end gap-1 shrink-0">
            <span className="text-xs text-orange-300/70">Best streak</span>
            <span className="text-sm font-bold text-orange-300">21 days</span>
          </div>
        </div>
        {/* Day dots */}
        <div className="mt-4 flex gap-1.5">
          {Array.from({ length: 14 }).map((_, i) => {
            const isActive = i < (user?.streak ?? 12);
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
                  <span className="flex items-center gap-1">
                    <Star size={11} className="text-yellow-400" /> {course.rating}
                  </span>
                  <span
                    className="ml-auto text-[10px] px-2 py-0.5 rounded-full font-medium"
                    style={{
                      backgroundColor:
                        course.difficulty === 'Beginner'
                          ? 'rgba(34,197,94,0.15)'
                          : course.difficulty === 'Advanced'
                          ? 'rgba(239,68,68,0.15)'
                          : 'rgba(108,99,255,0.15)',
                      color:
                        course.difficulty === 'Beginner'
                          ? '#22c55e'
                          : course.difficulty === 'Advanced'
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
      </motion.div>

      {/* ── Recent Community Activity ─────────────────────────── */}
      <motion.div variants={itemVariants}>
        <SectionHeader title="Community Activity" href="/community" icon={Users} />
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
      </motion.div>

      {/* ── Bottom spacer for mobile nav ─────────────────────── */}
      <div className="h-2 md:h-4" />
    </motion.div>
  );
}
