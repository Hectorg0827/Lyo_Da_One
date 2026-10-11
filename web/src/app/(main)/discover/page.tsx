'use client';

/**
 * Discover — the learning reel, and the only one.
 *
 * Mirrors iOS `Sources/Views/Main/DiscoverView.swift`: a full-bleed,
 * vertically paged video feed with a floating search overlay, top/bottom
 * scrims, an info overlay on the left and an action strip on the right.
 * Client-side search filters title + subtitle + tags, same as the iOS
 * DiscoverViewModel.
 *
 * There used to be a second reel at `/clips`, on the same clips API. Discover
 * was what everything pointed at — the mobile nav, the search bar, the empty
 * course stack — while commenting and posting lived only on the page almost
 * nothing linked. So on a phone you could watch clips and never reach a way
 * to comment on one or make one. Both now live here, and `/clips` redirects.
 */

import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Search,
  Sparkles,
  GitBranch,
  Bookmark,
  Heart,
  Forward,
  Check,
  Users,
  ArrowRight,
  Play,
  MessageCircle,
} from 'lucide-react';
import { AnimatePresence } from 'framer-motion';
import { useRouter, useSearchParams } from 'next/navigation';
import { formatNumber } from '@/lib/utils';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import ClipCommentsDrawer from '@/components/clips/ClipCommentsDrawer';
import CreateClipModal from '@/components/clips/CreateClipModal';
import { draftSubject, draftTitle } from '@/lib/teach-it.mjs';

interface Reel {
  id: string;
  title: string;
  subtitle: string;
  videoUrl: string;
  posterUrl: string;
  author: { name: string; avatar: string; level: 'beginner' | 'intermediate' | 'advanced' };
  keyPoints: string[];
  relatedGroup: string | null;
  tags: string[];
  likes: number;
  comments: number;
  isLiked: boolean;
  isSaved: boolean;
}

// iOS ReelInfoOverlay level ring colors (system green / yellow / red)
const LEVEL_RING: Record<Reel['author']['level'], string> = {
  beginner: '#34c759',
  intermediate: '#ffcc00',
  advanced: '#ff3b30',
};

function adaptReel(raw: Record<string, unknown>): Reel {
  const metadata = (raw.metadata as Record<string, unknown>) || {};
  const rawLevel = String(
    (metadata.level as string) || (raw.difficulty as string) || 'beginner'
  ).toLowerCase();
  const level: Reel['author']['level'] =
    rawLevel === 'advanced' ? 'advanced' : rawLevel === 'intermediate' ? 'intermediate' : 'beginner';

  const keyPoints = (
    (metadata.key_points as string[]) ||
    (raw.key_points as string[]) ||
    []
  ).filter(Boolean);

  return {
    id: String(raw.id),
    title: (raw.title as string) || 'Untitled',
    subtitle:
      (raw.description as string) || (metadata.subject as string) || (raw.subject as string) || '',
    videoUrl: (raw.videoURL as string) || (raw.video_url as string) || '',
    posterUrl: (raw.thumbnailURL as string) || (raw.thumbnail_url as string) || '',
    author: {
      name:
        (raw.authorName as string) ||
        (raw.creator_name as string) ||
        (raw.user_name as string) ||
        'Member',
      avatar: (raw.authorAvatarURL as string) || (raw.creator_avatar as string) || '',
      level,
    },
    keyPoints: keyPoints.slice(0, 3),
    relatedGroup: (metadata.related_group as string) || null,
    tags: ((metadata.tags as string[]) || (raw.tags as string[]) || []).filter(Boolean),
    likes: (raw.likeCount as number) || (raw.like_count as number) || 0,
    comments: (raw.commentCount as number) || (raw.comment_count as number) || 0,
    isLiked: (raw.isLiked as boolean) || (raw.is_liked as boolean) || false,
    isSaved: (raw.isSaved as boolean) || (raw.is_saved as boolean) || false,
  };
}

// ─── Action strip (iOS ReelActionStrip) ──────────────────────────────────────

function ActionButton({
  label,
  onClick,
  children,
}: {
  label: string;
  onClick?: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={(e) => {
        e.stopPropagation();
        onClick?.();
      }}
      className="flex flex-col items-center gap-0.5 active:scale-90 transition-transform duration-150"
    >
      {children}
      <span className="text-[10px] font-bold text-white">{label}</span>
    </button>
  );
}

function ActionStrip({
  reel,
  onAsk,
  onCourse,
  onComment,
  onLike,
  onSave,
  onShare,
}: {
  reel: Reel;
  onAsk: () => void;
  onCourse: () => void;
  onComment: () => void;
  onLike: () => void;
  onSave: () => void;
  onShare: () => void;
}) {
  return (
    <div className="flex flex-col items-center gap-4 shrink-0">
      <ActionButton label="Ask Lio" onClick={onAsk}>
        <span
          className="w-[38px] h-[38px] rounded-full flex items-center justify-center"
          style={{ background: 'linear-gradient(135deg, #007aff, #af52de)' }}
        >
          <Sparkles className="w-[18px] h-[18px] text-white" />
        </span>
      </ActionButton>

      <ActionButton label="Course" onClick={onCourse}>
        <span className="w-[38px] h-[38px] rounded-full flex items-center justify-center bg-black/60 border border-white/30">
          <GitBranch className="w-[18px] h-[18px] text-white" />
        </span>
      </ActionButton>

      <ActionButton label={reel.isSaved ? 'Saved' : 'Save'} onClick={onSave}>
        <Bookmark
          className="w-[26px] h-[26px]"
          style={{ color: reel.isSaved ? '#ffcc00' : '#ffffff' }}
          fill={reel.isSaved ? '#ffcc00' : 'none'}
        />
      </ActionButton>

      <ActionButton label={formatNumber(reel.likes)} onClick={onLike}>
        <Heart
          className="w-[26px] h-[26px]"
          style={{ color: reel.isLiked ? '#ff3b30' : '#ffffff' }}
          fill={reel.isLiked ? '#ff3b30' : 'none'}
        />
      </ActionButton>

      <ActionButton label={formatNumber(reel.comments)} onClick={onComment}>
        <MessageCircle className="w-[26px] h-[26px] text-white" />
      </ActionButton>

      <ActionButton label="Share" onClick={onShare}>
        <Forward className="w-6 h-6 text-white" />
      </ActionButton>
    </div>
  );
}

// ─── Info overlay (iOS ReelInfoOverlay) ──────────────────────────────────────

function InfoOverlay({ reel }: { reel: Reel }) {
  const initial = reel.author.name.charAt(0).toUpperCase();

  return (
    <div className="flex flex-col gap-3 flex-1 min-w-0">
      {/* Author */}
      <div className="flex items-center gap-2">
        <span
          className="relative w-[34px] h-[34px] rounded-full flex items-center justify-center shrink-0"
          style={{ boxShadow: `inset 0 0 0 2px ${LEVEL_RING[reel.author.level]}` }}
        >
          {reel.author.avatar ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={reel.author.avatar}
              alt={reel.author.name}
              className="w-8 h-8 rounded-full object-cover"
            />
          ) : (
            <span className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center text-xs font-bold text-white">
              {initial}
            </span>
          )}
        </span>
        <div className="flex flex-col gap-[2px] min-w-0">
          <span className="text-base font-semibold text-white truncate">{reel.author.name}</span>
          
        </div>
      </div>

      {/* Title */}
      <h2 className="text-[17px] font-bold text-white leading-snug line-clamp-2">{reel.title}</h2>

      {/* Key points, or the subtitle when there are none */}
      {reel.keyPoints.length > 0 ? (
        <div className="flex flex-col gap-1 py-1">
          {reel.keyPoints.map((point) => (
            <div key={point} className="flex items-start gap-1.5">
              <Check
                className="w-[11px] h-[11px] mt-[3px] shrink-0 text-[#34c759]"
                strokeWidth={3}
              />
              <span className="text-xs text-white/95 leading-snug">{point}</span>
            </div>
          ))}
        </div>
      ) : (
        reel.subtitle && (
          <p className="text-xs text-white/90 leading-snug line-clamp-2">{reel.subtitle}</p>
        )
      )}

      {/* Community link */}
      {reel.relatedGroup && (
        <a
          href="/community/groups"
          onClick={(e) => e.stopPropagation()}
          className="flex items-center gap-1.5 w-fit px-2.5 py-1.5 rounded-lg text-[11px] text-white"
          style={{ backgroundColor: 'rgba(0, 122, 255, 0.8)' }}
        >
          <Users className="w-3 h-3" />
          <span className="font-bold">Find {reel.relatedGroup} Study Group</span>
          <ArrowRight className="w-3 h-3" />
        </a>
      )}
    </div>
  );
}

// ─── A single full-viewport slide ────────────────────────────────────────────

function ReelSlide({
  reel,
  isActive,
  shouldLoad,
  onEnded,
  onAsk,
  onCourse,
  onComment,
  onLike,
  onSave,
  onShare,
}: {
  reel: Reel;
  isActive: boolean;
  shouldLoad: boolean;
  onEnded: () => void;
  onAsk: () => void;
  onCourse: () => void;
  onComment: () => void;
  onLike: () => void;
  onSave: () => void;
  onShare: () => void;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [paused, setPaused] = useState(false);
  const [loadFailed, setLoadFailed] = useState(false);
  const [retryKey, setRetryKey] = useState(0);

  // Play only the visible slide. Preloaded neighbouring slides remain paused.
  // A rejected play promise must be visible, not a permanently black frame.
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (isActive && !paused && !loadFailed) {
      video.play().catch(() => {
        if (videoRef.current === video && !video.paused) return;
        if (videoRef.current === video) setLoadFailed(true);
      });
    } else {
      video.pause();
    }
  }, [isActive, paused, loadFailed, retryKey, shouldLoad]);

  useEffect(() => {
    if (!isActive) setPaused(false);
  }, [isActive]);

  useEffect(() => {
    setLoadFailed(false);
    setRetryKey(0);
  }, [reel.videoUrl]);

  const retry = () => {
    setLoadFailed(false);
    setPaused(false);
    setRetryKey((key) => key + 1);
  };

  return (
    <section
      className="relative w-full h-full shrink-0 snap-start snap-always overflow-hidden bg-black"
      onClick={() => reel.videoUrl && setPaused((p) => !p)}
    >
      {/* Media */}
      {reel.videoUrl && shouldLoad ? (
        <video
          key={retryKey}
          ref={videoRef}
          src={reel.videoUrl}
          poster={reel.posterUrl || undefined}
          preload="auto"
          playsInline
          muted
          onError={() => setLoadFailed(true)}
          onLoadedData={() => setLoadFailed(false)}
          onEnded={onEnded}
          className="absolute inset-0 w-full h-full object-cover"
        />
      ) : reel.posterUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={reel.posterUrl} alt="" className="absolute inset-0 w-full h-full object-cover" />
      ) : (
        // iOS no-video fallback: translucent blue→purple over black
        <div
          className="absolute inset-0"
          style={{
            background: 'linear-gradient(135deg, rgba(0,0,255,0.3), rgba(128,0,128,0.3)), #000000',
          }}
        />
      )}

      {/* Playback errors must offer a way out even when the media URL is dead. */}
      {loadFailed && isActive && reel.videoUrl && (
        <div className="absolute inset-0 z-[2] flex items-center justify-center bg-black/50">
          <div className="flex flex-col items-center gap-3 p-5 rounded-xl bg-black/80 text-white">
            <span className="text-sm font-semibold">Video couldn't load</span>
            <button className="rounded-lg border border-white/40 px-4 py-2 text-sm" onClick={(e) => { e.stopPropagation(); retry(); }}>
              Retry video
            </button>
            <button className="text-sm underline" onClick={(e) => { e.stopPropagation(); onEnded(); }}>
              Next clip
            </button>
          </div>
        </div>
      )}

      {/* Paused affordance */}
      {paused && reel.videoUrl && !loadFailed && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <span className="w-16 h-16 rounded-full bg-black/50 flex items-center justify-center">
            <Play className="w-7 h-7 text-white" fill="white" />
          </span>
        </div>
      )}

      {/* Scrims */}
      <div
        className="absolute inset-x-0 top-0 h-[150px] pointer-events-none"
        style={{ background: 'linear-gradient(to bottom, rgba(0,0,0,0.6), transparent)' }}
      />
      <div
        className="absolute inset-x-0 bottom-0 h-[300px] pointer-events-none"
        style={{ background: 'linear-gradient(to top, rgba(0,0,0,0.8), transparent)' }}
      />

      {/* Bottom content */}
      <div className="absolute inset-x-0 bottom-0 flex items-end gap-4 px-4 pb-[110px] md:pb-8">
        <InfoOverlay reel={reel} />
        <ActionStrip
          reel={reel}
          onAsk={onAsk}
          onCourse={onCourse}
          onComment={onComment}
          onLike={onLike}
          onSave={onSave}
          onShare={onShare}
        />
      </div>
    </section>
  );
}

// ─── Empty state (iOS EmptyStateView) ────────────────────────────────────────

function EmptyState({ message }: { message: string }) {
  return (
    <div className="flex flex-col items-center justify-center h-full px-4 text-center gap-6">
      <span
        className="w-[100px] h-[100px] rounded-full flex items-center justify-center"
        style={{ backgroundColor: 'rgba(59, 130, 246, 0.1)' }}
      >
        <Search className="w-10 h-10" strokeWidth={1} style={{ color: '#3b82f6' }} />
      </span>
      <div className="space-y-2">
        <h2 className="font-rounded text-[22px] font-bold text-white">No results found</h2>
        <p className="text-[17px] text-white/60 px-8 max-w-md">{message}</p>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

function DiscoverContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const queryParam = searchParams.get('q')?.trim() ?? '';
  // `?compose=clip` opens the composer, and `topic` fills it in. The finish
  // screen in the classroom links here that way: a learner who just finished
  // something is the best source of a clip this app will ever get, and the
  // composer has to be addressable for that link to exist at all.
  const composeParam = searchParams.get('compose');
  const topicParam = searchParams.get('topic');
  // `?clip=<id>` names the clip to open. Both the Share button here and the
  // redirect from the old /clips route produce links shaped that way, and
  // neither worked: the parameter was carried across and then ignored, so a
  // shared clip opened whatever happened to be first in the feed.
  const clipParam = searchParams.get('clip');
  const [composing, setComposing] = useState(composeParam === 'clip');
  const [query, setQuery] = useState(queryParam);
  const [activeIndex, setActiveIndex] = useState(0);

  useEffect(() => {
    setQuery(queryParam);
    setActiveIndex(0);
  }, [queryParam]);

  useEffect(() => {
    setComposing(composeParam === 'clip');
  }, [composeParam]);
  const [overrides, setOverrides] = useState<Record<string, Partial<Reel>>>({});
  const [commentsFor, setCommentsFor] = useState<string | null>(null);
  const scrollerRef = useRef<HTMLDivElement>(null);
  const viewed = useRef<Set<string>>(new Set());

  const { data, isLoading, error: feedError, refetch } = useApi(() => api.clips.discover(), []);
  const [moreClips, setMoreClips] = useState<Record<string, unknown>[]>([]);
  const nextPage = useRef(2);
  const fetchingPage = useRef(false);

  // Load subsequent pages before the user reaches the end. Discover is a
  // continuous feed, not a reel that silently stops after 20 clips.
  useEffect(() => {
    nextPage.current = 2;
    fetchingPage.current = false;
    setMoreClips([]);
  }, [data]);

  // A named clip need not be on the first page of Discover. When it is not,
  // it is fetched by id and put at the front, so the link lands on the clip
  // it named rather than silently on something else.
  const [namedReel, setNamedReel] = useState<Reel | null>(null);
  useEffect(() => {
    if (!clipParam) {
      setNamedReel(null);
      return;
    }
    let live = true;
    api.clips
      .get(clipParam)
      .then((result) => {
        if (live && result?.clip) setNamedReel(adaptReel(result.clip));
      })
      .catch(() => {
        // The clip is gone or private. The feed still works, so the learner
        // sees Discover rather than an error page for a dead link.
        if (live) setNamedReel(null);
      });
    return () => {
      live = false;
    };
  }, [clipParam]);

  const reels = useMemo(() => {
    const list = [...((data?.clips as Record<string, unknown>[]) || []), ...moreClips].map(adaptReel);
    // The named clip leads, and is not repeated further down the feed.
    const ordered = namedReel
      ? [namedReel, ...list.filter((r) => r.id !== namedReel.id)]
      : list;
    return ordered.map((r) => ({ ...r, ...overrides[r.id] }));
  }, [data, overrides, namedReel, moreClips]);

  useEffect(() => {
    if (isLoading || !data || query || fetchingPage.current) return;
    const loadedCount = (data.clips?.length || 0) + moreClips.length;
    if (activeIndex < reels.length - 4 || loadedCount >= (data.total || 0)) return;
    fetchingPage.current = true;
    const page = nextPage.current;
    api.clips.discover(page).then((result) => {
      nextPage.current = page + 1;
      setMoreClips((current) => [...current, ...(result.clips || [])]);
    }).catch(() => {
      // Don't hold playback hostage to pagination; retry as the user moves.
    }).finally(() => {
      fetchingPage.current = false;
    });
  }, [activeIndex, isLoading, data, moreClips.length, reels.length, query]);

  // Client-side filter over title + subtitle + tags (iOS DiscoverViewModel)
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return reels;
    return reels.filter(
      (r) =>
        r.title.toLowerCase().includes(q) ||
        r.subtitle.toLowerCase().includes(q) ||
        r.tags.some((t) => t.toLowerCase().includes(q))
    );
  }, [reels, query]);

  // Snap instantly to the next ready clip on natural completion. The last
  // clip stays paused when there is no subsequent item to advance into.
  const advanceFrom = useCallback((index: number) => {
    if (index + 1 >= filtered.length) return;
    setActiveIndex(index + 1);
    const scroller = scrollerRef.current;
    if (scroller) scroller.scrollTo({ top: (index + 1) * scroller.clientHeight, behavior: 'auto' });
  }, [filtered.length]);

  useEffect(() => {
    setActiveIndex(0);
    scrollerRef.current?.scrollTo({ top: 0 });
  }, [query]);

  // Track which slide is in view so only it plays
  useEffect(() => {
    const scroller = scrollerRef.current;
    if (!scroller) return;
    const onScroll = () => {
      if (!scroller.clientHeight) return;
      setActiveIndex(Math.round(scroller.scrollTop / scroller.clientHeight));
    };
    scroller.addEventListener('scroll', onScroll, { passive: true });
    return () => scroller.removeEventListener('scroll', onScroll);
  }, []);

  // The named clip is put at the front, so the feed has to be looking at the
  // front for that to mean anything — it can arrive after the first page has
  // already rendered and been scrolled.
  useEffect(() => {
    if (!namedReel) return;
    setActiveIndex(0);
    scrollerRef.current?.scrollTo({ top: 0 });
  }, [namedReel]);

  const patch = useCallback((id: string, next: Partial<Reel>) => {
    setOverrides((o) => ({ ...o, [id]: { ...o[id], ...next } }));
  }, []);

  const handleLike = useCallback(
    (reel: Reel) => {
      patch(reel.id, {
        isLiked: !reel.isLiked,
        likes: reel.likes + (reel.isLiked ? -1 : 1),
      });
      api.clips.like(reel.id).catch(() => {});
    },
    [patch]
  );

  const handleSave = useCallback(
    (reel: Reel) => {
      patch(reel.id, { isSaved: !reel.isSaved });
      api.clips.save(reel.id).catch(() => {});
    },
    [patch]
  );

  const handleAsk = useCallback((reel: Reel) => {
    router.push(`/chat?prompt=${encodeURIComponent(`Explain ${reel.title} and help me understand it.`)}`);
  }, [router]);

  const handleCourse = useCallback((reel: Reel) => {
    router.push(`/chat?prompt=${encodeURIComponent(`Create a course about ${reel.title}.`)}`);
  }, [router]);

  const handleShare = useCallback(async (reel: Reel) => {
    const url = `${window.location.origin}/discover?clip=${reel.id}`;
    try {
      if (navigator.share) {
        await navigator.share({ title: reel.title, url });
      } else {
        await navigator.clipboard.writeText(url);
      }
      // Count it. The old handler copied a link and told the server nothing,
      // so a creator's share count never moved for anyone sharing from here.
      api.clips.share(reel.id).catch(() => {});
    } catch {
      /* dismissed */
    }
  }, []);

  // A view is recorded once per clip per visit, when its slide is the one in
  // front of the viewer. Creators cannot be shown a view count the feed never
  // reported, and the old Discover reported none at all.
  useEffect(() => {
    const reel = filtered[activeIndex];
    if (!reel || viewed.current.has(reel.id)) return;
    viewed.current.add(reel.id);
    api.clips.view(reel.id).catch(() => {});
  }, [filtered, activeIndex]);

  return (
    <div className="relative w-full h-full overflow-hidden bg-black">
      {/* Feed */}
      <div
        ref={scrollerRef}
        className="w-full h-full overflow-y-auto snap-y snap-mandatory no-scrollbar"
      >
        {isLoading ? (
          <div className="flex items-center justify-center h-full gap-2">
            {[0, 1, 2].map((i) => (
              <span
                key={i}
                className="w-2.5 h-2.5 rounded-full bg-white animate-pulse"
                style={{ animationDelay: `${i * 0.15}s` }}
              />
            ))}
          </div>
        ) : feedError && !data ? (
          <div className="flex h-full flex-col items-center justify-center gap-4 px-6 text-center text-white">
            <p>Discover couldn't load. Check your connection and try again.</p>
            <button className="rounded-lg border border-white/40 px-5 py-2" onClick={refetch}>Retry Discover</button>
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            message={
              query
                ? 'Try a different search term or check back later for new discoveries.'
                : 'New discoveries will appear here as clips are published.'
            }
          />
        ) : (
          filtered.map((reel, i) => (
            <ReelSlide
              key={reel.id}
              reel={reel}
              isActive={i === activeIndex}
              shouldLoad={Math.abs(i - activeIndex) <= 1}
              onEnded={() => advanceFrom(i)}
              onAsk={() => handleAsk(reel)}
              onCourse={() => handleCourse(reel)}
              onComment={() => setCommentsFor(reel.id)}
              onLike={() => handleLike(reel)}
              onSave={() => handleSave(reel)}
              onShare={() => handleShare(reel)}
            />
          ))
        )}
      </div>

      {/* Floating search header */}
      <div
        className="absolute inset-x-0 top-0 z-10 px-4 pt-6 pb-4"
        style={{
          background: 'linear-gradient(to bottom, rgba(0,0,0,0.8), rgba(0,0,0,0.4), transparent)',
        }}
      >
        <label className="flex items-center gap-3 p-3.5 rounded-2xl bg-black/40 border border-white/20">
          <Search className="w-[17px] h-[17px] text-white/80 shrink-0" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search discoveries…"
            aria-label="Search discoveries"
            className="flex-1 bg-transparent text-white placeholder-white/70 text-[15px] focus:outline-none"
          />
        </label>
      </div>

      {composing && (
        <CreateClipModal
          initialTitle={draftTitle(topicParam) ?? ''}
          initialSubject={draftSubject(topicParam) ?? ''}
          onClose={() => {
            setComposing(false);
            // Drop the params so a refresh does not reopen the composer over
            // a clip the learner has already published.
            router.replace('/discover');
          }}
          onCreated={() => router.replace('/discover')}
        />
      )}

      <AnimatePresence>
        {commentsFor && (
          <ClipCommentsDrawer
            key={commentsFor}
            clipId={commentsFor}
            onClose={() => setCommentsFor(null)}
            onCountChange={(count) => patch(commentsFor, { comments: count })}
          />
        )}
      </AnimatePresence>

    </div>
  );
}


export default function DiscoverPage() {
  return (
    <Suspense fallback={<div className="h-full bg-black" aria-label="Loading Discover" />}>
      <DiscoverContent />
    </Suspense>
  );
}
