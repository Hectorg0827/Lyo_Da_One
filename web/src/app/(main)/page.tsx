'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
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
  TrendingUp,
  Layers,
  Share,
  MoreHorizontal,
  List,
} from 'lucide-react';
import Link from 'next/link';
import { useAuthStore } from '@/stores/auth-store';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import { listCourseStacks, postCourseToCommunity, courseShareUrl } from '@/lib/stack';
import NextForYou from '@/components/home/NextForYou';
import CourseStack from '@/components/home/CourseStack';
import HomeTestPrepCard from '@/components/home/HomeTestPrepCard';
import FrontDoor from '@/components/home/FrontDoor';
import { shouldShowLearnerDashboard } from '@/lib/entry-contract.mjs';
import { hasConceptEvidence, shouldLeadWithConcepts } from '@/lib/learner-model.mjs';

// Color palette for dynamically mapped courses
const courseColors = ['#6366f1', '#ec4899', '#22c55e', '#f59e0b', '#3b82f6'];
const courseEmojis = ['📚', '🧠', '🎨', '🐍', '🎵', '⚛️'];
const gradientPairs = [
  'from-[#6366f1] to-[#8b5cf6]',
  'from-[#ec4899] to-[#f43f5e]',
  'from-[#3b82f6] to-[#06b6d4]',
  'from-[#f59e0b] to-[#ef4444]',
  'from-[#22c55e] to-[#14b8a6]',
];
const activityColors = ['#6366f1', '#22c55e', '#ec4899', '#3b82f6', '#f59e0b'];

// iOS FocusView.DiscoverStrip — pill chips injected into the feed
const discoverChips = [
  { label: 'People', color: '#a855f7', href: '/community' },
  { label: 'Content', color: '#22d3ee', href: '/clips' },
  { label: 'Courses', color: '#f59e0b', href: '/courses' },
  { label: 'Search', color: '#6366f1', href: '/discover' },
];

// ── Helpers ────────────────────────────────────────────────────────────────────

function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
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
        <h2 className="font-rounded text-xl font-bold leading-tight">
          <span className="headline-gradient-text">{title}</span>
        </h2>
      </div>
      {href && (
        <Link
          href={href}
          className="flex items-center gap-1 text-[13px] font-semibold text-[#A9B7FF] hover:text-white transition-colors duration-200"
        >
          See all <ChevronRight size={14} />
        </Link>
      )}
    </div>
  );
}

function ProgressBar({
  value,
  color = '#6366f1',
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

/** Real share (Web Share API, falling back to clipboard — the same idiom
 *  PostCard.tsx's handleShare already uses) + post-to-Community actions
 *  for a Stacks course card. Mirrors Android's HomeScreen StackCourseCard
 *  dropdown ("Share…" / "Post to Community"). Stops the click from
 *  bubbling to the card's wrapping <Link> so opening the menu doesn't
 *  also navigate into the course. */
function ShareOrPostMenu({
  courseId,
  title,
  progressPercent,
  dark = false,
  showShareItem = true,
}: {
  courseId: string;
  title: string;
  progressPercent: number;
  dark?: boolean;
  /** Omit the "Share…" menu item when the card already has its own
   *  dedicated Share button next to this menu (the hero card), so the
   *  same action isn't offered twice. */
  showShareItem?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [status, setStatus] = useState<'idle' | 'copied' | 'posted' | 'error'>('idle');

  const flash = (next: 'copied' | 'posted' | 'error') => {
    setStatus(next);
    setTimeout(() => setStatus('idle'), 2200);
  };

  const handleShare = async () => {
    setOpen(false);
    const url = courseShareUrl(courseId);
    try {
      if (navigator.share) {
        await navigator.share({ title: `${title} — LYO`, text: `Check out "${title}" on Lyo`, url });
      } else {
        await navigator.clipboard.writeText(url);
        flash('copied');
      }
    } catch (error) {
      if ((error as DOMException).name !== 'AbortError') console.error('Unable to share course', error);
    }
  };

  const handlePost = async () => {
    setOpen(false);
    const ok = await postCourseToCommunity(courseId, title, progressPercent);
    flash(ok ? 'posted' : 'error');
  };

  return (
    <div
      className="relative"
      onClick={(e) => { e.preventDefault(); e.stopPropagation(); }}
    >
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-label="Course options"
        aria-haspopup="menu"
        aria-expanded={open}
        className={cn(
          'w-8 h-8 rounded-full backdrop-blur-md flex items-center justify-center transition-colors',
          dark ? 'bg-black/25 text-white hover:bg-black/40' : 'bg-white/10 text-white/70 hover:bg-white/20 hover:text-white',
        )}
      >
        <MoreHorizontal size={15} />
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
          <div
            role="menu"
            aria-label="Course options"
            className="absolute right-0 top-full z-20 mt-1.5 w-44 overflow-hidden rounded-xl border border-white/10 bg-[#151b30] shadow-2xl"
          >
            {showShareItem && (
              <button
                type="button"
                role="menuitem"
                onClick={handleShare}
                className="flex w-full items-center gap-2 px-3.5 py-2.5 text-left text-[13px] text-white/80 hover:bg-white/10 hover:text-white"
              >
                <Share size={13} /> Share…
              </button>
            )}
            <button
              type="button"
              role="menuitem"
              onClick={handlePost}
              className="flex w-full items-center gap-2 px-3.5 py-2.5 text-left text-[13px] text-white/80 hover:bg-white/10 hover:text-white"
            >
              <Users size={13} /> Post to Community
            </button>
          </div>
        </>
      )}
      {status !== 'idle' && (
        <div className="absolute right-0 top-full z-20 mt-1.5 whitespace-nowrap rounded-lg bg-black/85 px-2.5 py-1 text-[11px] text-white">
          {status === 'copied' ? 'Link copied' : status === 'posted' ? 'Posted to Community' : 'Could not post'}
        </div>
      )}
    </div>
  );
}

// ── Main Page ──────────────────────────────────────────────────────────────────

export default function HomePage() {
  const { user, isAuthenticated, isLoading: authLoading } = useAuthStore();
  const [mounted, setMounted] = useState(false);

  const { data: gamification } = useApi(() => api.gamification.overview(), []);
  const { data: conceptSummary } = useApi(() => api.personalization.conceptSummary(), []);
  const { data: courses } = useApi(() => api.courses.list(0, 4), []);
  // People this learner actually follows — not the public feed.
  //
  // This section called itself "Today in your world" while reading
  // /feed/public, which told the learner these were people they had chosen
  // to follow when they were not. `verify-android-focus-honesty.mjs` bans
  // exactly that substitution on Android's Focus screen for the same reason.
  // `sort_by=following` is the scope iOS's rail already requests from this
  // same route. An empty result says so rather than falling back to
  // strangers to fill the space.
  const { data: feedData } = useApi(() => api.community.posts(1, 5, 'following'), []);
  // Device- and platform-agnostic Stacks: courses this learner has actually
  // started, synced via the real backend (not a single-slot local pointer) —
  // this is what the "Your courses" stack below is sourced from, the same
  // list Android's HomeScreen and iOS's Focus tab read.
  const { data: stackItems } = useApi(() => listCourseStacks(), []);

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
  const activityStats = [
    {
      label: 'Hours Learned',
      value: String((userLevel?.total_hours as number) || user?.xp ? Math.round((user?.xp || 0) / 100) : 0),
      sub: 'total',
      icon: Clock,
      color: '#6366f1',
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

  /**
   * Lead with what the learner knows, not how often they showed up.
   *
   * XP, level, hours and streak are real, but they measure attendance. A
   * learner with a thirty-day streak still cannot tell from that whether they
   * understand anything. These counts are earned from their own evidence
   * server-side — see `lyo_app/events/concept_summary.py` for what each word
   * requires — so the headline means what it says.
   *
   * Streak keeps the fourth slot. It is honest about being a habit measure,
   * and it is the one number here that rewards coming back tomorrow.
   *
   * If the summary is unavailable — an older backend, a failed request — the
   * activity stats are shown instead. Rendering zeroes for a learner who has
   * demonstrably done work would be the same fabrication this page was
   * cleaned up to remove, just with a more flattering vocabulary.
   */
  // Narrowed here rather than inline: the decision lives in a .mjs module, so
  // TypeScript cannot see through the call to know the summary is non-null.
  const leadingConcepts = shouldLeadWithConcepts(conceptSummary) ? conceptSummary : null;

  const conceptStats = leadingConcepts
    ? [
        {
          label: 'Learned',
          value: String(leadingConcepts.learned),
          sub: 'concepts explained',
          icon: BookOpen,
          color: '#6366f1',
          trend: leadingConcepts.exploring > 0 ? `${leadingConcepts.exploring} exploring` : '',
        },
        {
          label: 'Mastered',
          value: String(leadingConcepts.mastered),
          sub: 'applied, transferred, retained',
          icon: Trophy,
          color: '#22c55e',
          trend: '',
        },
        {
          label: 'Retained',
          value: String(leadingConcepts.retained),
          sub: 'recalled after a break',
          icon: Zap,
          color: '#f59e0b',
          trend: '',
        },
        {
          label: 'Streak',
          value: `${currentStreak}d`,
          sub: 'current',
          icon: Clock,
          color: '#ec4899',
          trend: bestStreak > currentStreak ? `Best: ${bestStreak}d` : '',
        },
      ]
    : null;

  const learningStats = conceptStats ?? activityStats;

  // Map real Stack items — device- and platform-agnostic, backend-synced,
  // sourced from every course a course card's Start action has actually
  // saved (see /classroom's upsertCourseOnStart effect and CoursePlayer's
  // progress sync) — NOT the generic catalog list used below for
  // The catalogue grid below. Not personalised — see <NextForYou /> for the
  // learner's actual recommendations.
  const STATUS_LABEL: Record<string, string> = {
    not_started: 'Not started',
    in_progress: 'In progress',
    completed: 'Completed',
    paused: 'Paused',
  };
  /**
   * Is there anything real to report about this learner yet?
   *
   * A signed-out visitor never has activity. A signed-in learner who has not
   * started anything has none either, and showing them Level 1 / 0 XP /
   * 0 hours / 0 courses is a dashboard of their own nothing — it asks them to
   * admire an empty account before the product has given them anything.
   *
   * When there is no activity we skip the greeting, the hero card and the
   * stats grid entirely and lead with the front door instead. Nothing here
   * invents a number to fill the space.
   */
  const hasRealActivity =
    hasConceptEvidence(conceptSummary) ||
    (stackItems || []).length > 0 ||
    ((xpSummary?.total as number) || user?.xp || 0) > 0 ||
    ((achievementsData?.completed as number) || user?.coursesCompleted || 0) > 0 ||
    currentStreak > 0;

  const showLearnerDashboard = shouldShowLearnerDashboard({
    authLoading,
    isAuthenticated,
    hasRealActivity,
  });

  // Map API courses to recommended format
  const catalogueCourses = (courses || []).map((c: Record<string, unknown>, i: number) => ({
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

  // Map community posts (the /community/posts wire shape: `items`, with
  // snake_case author and count fields) to what the row below renders.
  const feedPosts = (feedData?.items || []) as Record<string, unknown>[];
  const communityActivity = feedPosts.map((post: Record<string, unknown>, i: number) => {
    const authorName = (post.author_name as string) || 'User';
    const initials = authorName
      .split(' ')
      .map((w: string) => w[0])
      .filter(Boolean)
      .join('')
      .slice(0, 2)
      .toUpperCase();
    return {
      id: String(post.id ?? i),
      author: authorName,
      username: '',
      initials: initials || '?',
      color: activityColors[i % activityColors.length],
      action: 'posted',
      content: (post.content as string) || '',
      likes: (post.like_count as number) || 0,
      comments: (post.comment_count as number) || 0,
      timeAgo: post.created_at ? formatTimeAgoShort(post.created_at as string) : '',
      type: (post.post_type as string) || 'post',
    };
  });

  return (
    <motion.div
      className="max-w-5xl mx-auto px-4 sm:px-6 py-5 space-y-6 sm:py-6 sm:space-y-8"
      variants={containerVariants}
      initial="hidden"
      animate={mounted ? 'visible' : 'hidden'}
    >
      {/* ── Who this is, and where they left off ───────────────────
          A returning learner opens this page to get back into something they
          already started. That is what the top of the screen is for now:
          their name, the one line that says what finishing a lesson is worth
          today, and then their courses — newest first, so the card under the
          greeting is the one they were last in.

          The front door follows, because "start something new" is the second
          question for someone who already has courses and the first question
          only for someone who has none. A learner with no activity does not
          reach this block at all (see shouldShowLearnerDashboard), so for
          them the front door still leads the page. ── */}
      {showLearnerDashboard && (
        <>
          {/* ── Greeting (matches iOS FocusView greetingSection) ──── */}
          <motion.div variants={itemVariants}>
            <h1 className="font-rounded text-[26px] sm:text-[34px] font-bold leading-tight drop-shadow-[0_4px_12px_rgba(168,85,247,0.25)]">
              <span className="text-white/70">{getGreeting()}, </span>
              <span className="headline-gradient-text">{firstName}</span>
            </h1>
            <p className="text-[13px] sm:text-sm font-medium text-white/65 mt-1">
              You&apos;re one lesson away from {currentStreak > 0 ? `a ${currentStreak + 1}-day streak` : 'starting a streak'}.
            </p>
          </motion.div>

          {/* ── Your courses — every course this learner has started, synced
              via the real backend so it shows up the same way on any device
              or platform they're signed into (see lib/stack.ts).

              One list, once. This section and a hero card above it were once
              the same array: the newest course rendered large, then all of
              them rendered small, which made one collection look like two
              features. This is the whole stack, newest first — so the top
              card is the course they were last in — with chips to narrow it
              and a card that turns over for the description the backend
              already sends and this page used to drop. ── */}
          <motion.div variants={itemVariants}>
            <SectionHeader title="Your courses" href="/courses" icon={Layers} />
            <CourseStack
              items={stackItems || []}
              renderMenu={(item) => (
                <ShareOrPostMenu
                  courseId={item.content_id || String(item.id)}
                  title={item.title}
                  progressPercent={Math.round((item.progress || 0) * 100)}
                />
              )}
            />
          </motion.div>
        </>
      )}

      {/* ── Front door — the question the product exists to answer.
          Shown to everyone so the Classroom and "I have a test" entries are
          always one action away. It leads the page for a learner with no
          activity yet, and renders compact under the courses of one who has
          (see FrontDoor's `compact`). */}
      <FrontDoor knownLearner={showLearnerDashboard} />

      {showLearnerDashboard && (
        /* ── The test you have coming up ────────────────────────────
            Answered in place: readiness, days remaining and the next session,
            instead of a CTA that said nothing about this learner's own plan.
            Every figure comes from lib/test-prep.mjs, so "nothing assessed
            yet" stays distinct from "0% ready".

            It renders nothing when there is no plan. The front door directly
            above it now carries a full "I have a test" tile, and two
            invitations to the same page, stacked, is one invitation and one
            piece of clutter. ── */
        <motion.div variants={itemVariants}>
          <HomeTestPrepCard enabled={isAuthenticated && !authLoading} promptWhenEmpty={false} />
        </motion.div>
      )}

      {/* ── Quick Actions ─────────────────────────────────────── */}
      <motion.div variants={itemVariants}>
        <SectionHeader title="Quick Actions" icon={Sparkles} />
        <div className="grid grid-cols-3 gap-3">
          <Link
            href="/chat"
            className="group relative overflow-hidden rounded-xl p-4 flex flex-col gap-2 transition-transform duration-200 hover:scale-[1.02] active:scale-[0.98]"
            style={{ background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)' }}
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
            <Layers size={22} className="text-[#6366f1]" />
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

      {/* ── Learning Stats — only once there is something to count ─ */}
      {showLearnerDashboard && (
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

      )}

      {/* ── What LYO recommends next ──────────────────────────────
          Driven by the learner's real spaced-repetition schedule. Renders
          nothing when nothing is due. This replaced a hard-coded
          "Daily Challenges" list with invented progress values. */}
      <NextForYou />

      {/* ── Browse the catalogue ──────────────────────────────────
          This was headed "Recommended For You" over `courses.list(0, 4)` —
          the first four rows of the catalogue, identical for every learner.
          Not invented data, but a claim about the learner ("for you") that
          nothing behind it supported.

          Real recommendations live in <NextForYou /> above, drawn from this
          learner's own review schedule and mastery profile, each carrying the
          reason it was chosen. The catalogue is still worth browsing; it just
          is not personalised, so it no longer says it is. */}
      <motion.div variants={itemVariants}>
        <SectionHeader title="Browse the catalogue" href="/discover" icon={Star} />
        {catalogueCourses.length === 0 ? (
          <div className="glass-card p-6 flex flex-col items-center gap-2 text-center">
            <Star size={28} className="text-secondary" />
            <p className="text-sm text-secondary">Courses will appear here as they are published</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {catalogueCourses.map((course) => (
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
                            : 'rgba(99,102,241,0.15)',
                        color:
                          course.difficulty === 'beginner' || course.difficulty === 'Beginner'
                            ? '#22c55e'
                            : course.difficulty === 'advanced' || course.difficulty === 'Advanced'
                            ? '#ef4444'
                            : '#a78bfa',
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
        <SectionHeader title="From people you follow" href="/community" icon={Users} />

        {/* Discover strip (iOS FocusView.DiscoverStrip) */}
        <div className="flex gap-2 overflow-x-auto no-scrollbar pb-3 -mx-4 px-4 sm:mx-0 sm:px-0">
          {discoverChips.map((chip) => (
            <Link
              key={chip.label}
              href={chip.href}
              className="shrink-0 px-4 py-1.5 rounded-full text-[13px] font-semibold transition-all duration-200 hover:scale-[1.04] active:scale-95"
              style={{
                backgroundColor: `${chip.color}26`,
                border: `1px solid ${chip.color}40`,
                color: chip.color,
              }}
            >
              {chip.label}
            </Link>
          ))}
        </div>

        {communityActivity.length === 0 ? (
          <div className="glass-card p-6 flex flex-col items-center gap-2 text-center">
            <Users size={28} className="text-secondary" />
            <p className="text-sm text-secondary">No posts yet from people you follow</p>
          </div>
        ) : (
          <div className="space-y-3">
            {communityActivity.map((post) => (
              <div key={post.id} className="glass-card p-4 space-y-3">
                <div className="flex items-start gap-3">
                  {/* Accent ring around the avatar (iOS FocusFeedCardView) */}
                  <span
                    className="rounded-full p-[2px] shrink-0"
                    style={{ background: `linear-gradient(135deg, ${post.color}, ${post.color}40)` }}
                  >
                    <MiniAvatar initials={post.initials} color={post.color} size={38} />
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-rounded text-[15px] font-semibold text-white">
                        {post.author}
                      </span>
                      <span
                        className="font-rounded text-[11px] font-bold uppercase tracking-[0.6px] px-2 py-0.5 rounded-full"
                        style={{
                          backgroundColor: `${post.color}26`,
                          border: `1px solid ${post.color}40`,
                          color: post.color,
                        }}
                      >
                        {post.type}
                      </span>
                      <span className="text-xs font-medium text-white/50 ml-auto">
                        {post.timeAgo}
                      </span>
                    </div>
                    <p className="text-sm text-white/70 leading-relaxed mt-1.5 line-clamp-3">
                      {post.content}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-4 pt-1 border-t border-white/[0.06]">
                  <button className="flex items-center gap-1.5 text-[11px] text-white/50 hover:text-red-400 transition-colors duration-150">
                    <Heart size={13} /> {post.likes}
                  </button>
                  <button className="flex items-center gap-1.5 text-[11px] text-white/50 hover:text-lyo-300 transition-colors duration-150">
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
