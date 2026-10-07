'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
  ChevronRight,
  Users,
  Heart,
  MessageCircle,
  TrendingUp,
  Layers,
  Share,
  MoreHorizontal,
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
import LearnerStats from '@/components/stats/LearnerStats';
import { shouldShowLearnerDashboard } from '@/lib/entry-contract.mjs';
import { streakFrom } from '@/lib/learner-stats.mjs';
import { hasConceptEvidence } from '@/lib/learner-model.mjs';

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

  // The streak reads the same here as in the stats strip below and in
  // Profile's grid, because all three ask the same module (lib/learner-stats).
  const { current: currentStreak } = streakFrom(gamification, user);

  const xpSummary = gamification?.xp_summary as Record<string, unknown> | undefined;
  const achievementsData = gamification?.achievements as Record<string, unknown> | undefined;

  /**
   * Is there anything real to report about this learner yet?
   *
   * A signed-out visitor never has activity. A signed-in learner who has not
   * started anything has none either, and showing them Level 1 / 0 XP /
   * 0 hours / 0 courses is a dashboard of their own nothing — it asks them to
   * admire an empty account before the product has given them anything.
   *
   * When there is no activity we skip the greeting, the course stack and the
   * stats strip entirely and lead with the front door instead. Nothing here
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

      {/* ── Learning stats — only once there is something to count ─
          One row, not four cards in a 2x2 grid. These are numbers a learner
          glances at on the way to something else; a third of a phone screen
          is not what a glance is worth, and it was pushing the page's real
          content below the fold.

          The full read — what each word means, the trends, the sub-lines that
          are the whole reason "Mastered" can be trusted — is on Profile, and
          this taps through to it. Both shapes are built by the same module,
          so they cannot drift into disagreeing about the same learner. ── */}
      {showLearnerDashboard && (
        <motion.div variants={itemVariants}>
          <SectionHeader title="Your Stats" href="/profile" icon={TrendingUp} />
          <LearnerStats
            variant="strip"
            href="/profile"
            conceptSummary={conceptSummary}
            gamification={gamification}
            user={user}
          />
        </motion.div>
      )}

      {/* ── What LYO recommends next ──────────────────────────────
          Driven by the learner's real spaced-repetition schedule. Renders
          nothing when nothing is due. This replaced a hard-coded
          "Daily Challenges" list with invented progress values. */}
      <NextForYou />

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
