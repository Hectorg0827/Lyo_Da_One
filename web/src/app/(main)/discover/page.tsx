'use client';

/**
 * Discover — the learning reel, and the only one.
 *
 * Mirrors iOS `Sources/Views/Main/DiscoverView.swift`: a full-bleed,
 * vertically paged video feed with dynamic topic tabs and top/bottom scrims.
 * The single global TopBar search filters the entire library via URL state.
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
  Pause,
  Volume2,
  VolumeX,
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
import { DiscoverPlaybackController, DiscoverPageCursor, mergeClipPage, nextClipIndex } from '@/lib/discover-playback.mjs';
import { normalizeDiscoverFeed, discoverFilterHref, discoverSubjects } from '@/lib/discover-filters.mjs';

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
    <div className="flex flex-col items-center gap-3 shrink-0">
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
  foreground,
  muted,
  onMutedChange,
  onInteraction,
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
  foreground: boolean;
  muted: boolean;
  onMutedChange: (muted: boolean) => void;
  onInteraction: () => void;
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
  const [autoplayBlocked, setAutoplayBlocked] = useState(false);
  const [scrubbing, setScrubbing] = useState(false);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(0);
  const [ended, setEnded] = useState(false);
  const controllerRef = useRef<DiscoverPlaybackController | null>(null);
  const intent = { selected: isActive, foreground, paused, scrubbing, failed: loadFailed, ended };

  // One owner per element; pause/dispose invalidates outstanding play promises.
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    const controller = new DiscoverPlaybackController(video, {
      onBlocked: () => setAutoplayBlocked(true),
      onError: () => setLoadFailed(true),
    });
    controllerRef.current = controller;
    return () => { controller.dispose(); controllerRef.current = null; };
  }, [retryKey, shouldLoad, reel.videoUrl]);

  useEffect(() => {
    controllerRef.current?.update({ selected: isActive, foreground, paused, scrubbing, failed: loadFailed, ended });
  }, [isActive, foreground, paused, scrubbing, loadFailed, ended, retryKey, shouldLoad, reel.videoUrl, muted]);

  useEffect(() => {
    if (!isActive) {
      setPaused(false);
      setScrubbing(false);
      setAutoplayBlocked(false);
      if (videoRef.current?.ended) { controllerRef.current?.seek(0); setEnded(false); }
    }
  }, [isActive]);

  useEffect(() => {
    setLoadFailed(false);
    setRetryKey(0);
    setDuration(0);
    setPosition(0);
    setEnded(false);
  }, [reel.videoUrl]);

  const retry = () => {
    onInteraction();
    setLoadFailed(false);
    setPaused(false);
    setAutoplayBlocked(false);
    setEnded(false);
    setRetryKey((key) => key + 1);
  };

  const togglePlayback = () => {
    if (!isActive || !foreground || loadFailed) return;
    onInteraction();
    const nextPaused = !(paused || autoplayBlocked || ended);
    if (ended) controllerRef.current?.seek(0);
    setEnded(false);
    setPaused(nextPaused);
    setAutoplayBlocked(false);
    // Invoke play inside the gesture for browsers requiring user activation.
    controllerRef.current?.update({ ...intent, paused: nextPaused, ended: false });
  };
  const setSeeking = (value: boolean) => {
    if (value) onInteraction();
    setScrubbing(value);
    controllerRef.current?.update({ ...intent, scrubbing: value });
  };
  const timeLabel = (seconds: number) => `${Math.floor(seconds / 60)}:${Math.floor(seconds % 60).toString().padStart(2, '0')}`;

  return (
    <section
      className="relative w-full h-full shrink-0 snap-start snap-always overflow-hidden bg-black"
      aria-label={reel.title}
      onClick={togglePlayback}
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
          muted={muted}
          onError={() => setLoadFailed(true)}
          onLoadedData={() => setLoadFailed(false)}
          onLoadedMetadata={(event) => { const value = event.currentTarget.duration; setDuration(Number.isFinite(value) ? value : 0); }}
          onDurationChange={(event) => { const value = event.currentTarget.duration; setDuration(Number.isFinite(value) ? value : 0); }}
          onTimeUpdate={(event) => { if (!scrubbing) setPosition(event.currentTarget.currentTime); }}
          onPlaying={() => { setAutoplayBlocked(false); setEnded(false); }}
          onEnded={() => { if (controllerRef.current?.canAdvance()) onEnded(); setEnded(true); }}
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

      {autoplayBlocked && isActive && !loadFailed && (
        <button className="absolute inset-0 z-[1] m-auto h-12 w-36 rounded-lg bg-black/70 text-white" onClick={(event) => { event.stopPropagation(); togglePlayback(); }}>
          Tap to play
        </button>
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
      <div className="absolute inset-x-0 bottom-0 flex items-end gap-3 px-4 pb-[calc(9.5rem+env(safe-area-inset-bottom))] md:pb-20">
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
      {reel.videoUrl && isActive && !loadFailed && (
        <div className="absolute inset-x-4 bottom-[76px] md:bottom-3 flex items-center gap-3 text-white" onClick={(event) => event.stopPropagation()}>
          <button aria-label={paused || autoplayBlocked || ended ? 'Play video' : 'Pause video'} onClick={togglePlayback} className="p-2">
            {paused || autoplayBlocked || ended ? <Play size={20} /> : <Pause size={20} />}
          </button>
          <input type="range" aria-label="Seek video" className="min-w-0 flex-1 accent-white touch-none" min={0} max={duration || 1} step={0.1} value={Math.min(position, duration || 0)} disabled={duration <= 0}
            onPointerDown={() => setSeeking(true)} onPointerUp={() => setSeeking(false)} onPointerCancel={() => setSeeking(false)} onBlur={() => setSeeking(false)}
            onKeyDown={(event) => { if (['ArrowLeft', 'ArrowRight', 'Home', 'End', 'PageUp', 'PageDown'].includes(event.key)) setSeeking(true); }} onKeyUp={() => setSeeking(false)}
            onChange={(event) => { const value = Number(event.target.value); setPosition(value); controllerRef.current?.seek(value); }} />
          <span className="text-xs tabular-nums">{timeLabel(position)} / {timeLabel(duration)}</span>
          <button aria-label={muted ? 'Unmute video' : 'Mute video'} className="p-2" onClick={() => {
            const video = videoRef.current;
            if (video) video.muted = !muted;
            onMutedChange(!muted);
            controllerRef.current?.update(intent);
          }}>{muted ? <VolumeX size={20} /> : <Volume2 size={20} />}</button>
        </div>
      )}
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
  const query = queryParam;
  const feedMode: 'for_you' | 'latest' | 'popular' | 'saved' = normalizeDiscoverFeed(searchParams.get('feed'));
  const subject = searchParams.get('subject')?.trim() ?? '';
  const filterKey = `${feedMode}::${subject}::${query}`;
  const [activeIndex, setActiveIndex] = useState(0);
  const [foreground, setForeground] = useState(true);
  const [muted, setMuted] = useState(true);
  const [pendingAdvanceId, setPendingAdvanceId] = useState<string | null>(null);
  const activeIndexRef = useRef(0);
  activeIndexRef.current = activeIndex;

  useEffect(() => {
    const update = () => setForeground(!document.hidden);
    update();
    document.addEventListener('visibilitychange', update);
    return () => document.removeEventListener('visibilitychange', update);
  }, []);

  useEffect(() => {
    setActiveIndex(0);
  }, [filterKey]);

  useEffect(() => {
    setComposing(composeParam === 'clip');
  }, [composeParam]);
  const [overrides, setOverrides] = useState<Record<string, Partial<Reel>>>({});
  const [commentsFor, setCommentsFor] = useState<string | null>(null);
  const scrollerRef = useRef<HTMLDivElement>(null);
  const viewed = useRef<Set<string>>(new Set());

  const requestOptions = { q: query || undefined, subject: subject || undefined };
  const { data, isLoading, error: feedError, refetch } = useApi(
    () => feedMode === 'saved'
      ? api.clips.saved(1, 20, requestOptions)
      : api.clips.discover(1, 20, { ...requestOptions, sort: feedMode }),
    [filterKey],
  );
  const { data: availableFilters } = useApi(() => api.clips.discoverFilters(), []);
  const [moreClips, setMoreClips] = useState<Record<string, unknown>[]>([]);
  const pageCursor = useRef(new DiscoverPageCursor());

  const subjectChoices = useMemo(
    () => discoverSubjects(availableFilters?.subjects || [], (data?.clips || []) as Record<string, unknown>[], subject),
    [availableFilters, data, subject],
  );

  const chooseFilter = (mode: 'for_you' | 'latest' | 'popular' | 'saved', nextSubject = '') => {
    if (mode === feedMode && nextSubject === subject) return;
    router.replace(discoverFilterHref(searchParams.toString(), mode, nextSubject), { scroll: false });
  };

  // Load subsequent pages before the user reaches the end. Discover is a
  // continuous feed, not a reel that silently stops after 20 clips.
  useEffect(() => {
    pageCursor.current.reset();
    setMoreClips([]);
    setPendingAdvanceId(null);
    setActiveIndex(0);
    scrollerRef.current?.scrollTo({ top: 0 });
  }, [data, filterKey]);

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
    const list = mergeClipPage((data?.clips as Record<string, unknown>[]) || [], moreClips).map(adaptReel);
    // The named clip leads, and is not repeated further down the feed.
    const ordered = namedReel && feedMode === 'for_you' && !subject && !query
      ? [namedReel, ...list.filter((r) => r.id !== namedReel.id)]
      : list;
    return ordered.map((r) => ({ ...r, ...overrides[r.id] }));
  }, [data, overrides, namedReel, moreClips, feedMode, subject, query]);

  useEffect(() => {
    if (isLoading || !data) return;
    const loadedCount = (data.clips?.length || 0) + moreClips.length;
    if (activeIndex < reels.length - 4 || loadedCount >= (data.total || 0)) return;
    const request = pageCursor.current.begin();
    if (!request) return;
    const page = request.page;
    const load = feedMode === 'saved'
      ? api.clips.saved(page, 20, requestOptions)
      : api.clips.discover(page, 20, { ...requestOptions, sort: feedMode });
    load.then((result) => {
      if (!pageCursor.current.complete(request)) return;
      setMoreClips((current) => mergeClipPage(current, result.clips || []));
    }).catch(() => {
      pageCursor.current.fail(request);
    });
  }, [activeIndex, isLoading, data, moreClips.length, reels.length, filterKey]);

  // Search and topic filters run on the server before pagination.
  const filtered = reels;

  // Snap instantly to the next ready clip on natural completion. The last
  // clip stays paused when there is no subsequent item to advance into.
  const advanceFrom = useCallback((index: number) => {
    const finished = filtered[index]?.id;
    if (!finished || index !== activeIndexRef.current || !foreground || composing || commentsFor) return;
    const next = nextClipIndex(filtered.map((reel) => reel.id), filtered[activeIndexRef.current]?.id, finished);
    if (next === null) { setPendingAdvanceId(finished); return; }
    setPendingAdvanceId(null);
    activeIndexRef.current = next;
    setActiveIndex(next);
    const scroller = scrollerRef.current;
    if (scroller) scroller.scrollTo({ top: next * scroller.clientHeight, behavior: 'auto' });
  }, [filtered, foreground, composing, commentsFor]);

  useEffect(() => {
    if (pendingAdvanceId && filtered[activeIndex]?.id === pendingAdvanceId && activeIndex + 1 < filtered.length) advanceFrom(activeIndex);
  }, [pendingAdvanceId, filtered, activeIndex, advanceFrom]);

  useEffect(() => {
    setActiveIndex(0);
    setPendingAdvanceId(null);
    scrollerRef.current?.scrollTo({ top: 0 });
  }, [filterKey]);

  // Track which slide is in view so only it plays
  useEffect(() => {
    const scroller = scrollerRef.current;
    if (!scroller) return;
    const onScroll = () => {
      if (!scroller.clientHeight) return;
      const next = Math.round(scroller.scrollTop / scroller.clientHeight);
      activeIndexRef.current = next;
      setActiveIndex(next);
      setPendingAdvanceId(null);
    };
    scroller.addEventListener('scroll', onScroll, { passive: true });
    return () => scroller.removeEventListener('scroll', onScroll);
  }, [isLoading, filtered.length]);

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
              feedMode === 'saved'
                ? 'No saved videos match this selection. Save a clip to find it here.'
                : query || subject
                  ? 'No videos match this search or topic. Try For You or another subject.'
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
              foreground={foreground && !composing && !commentsFor}
              muted={muted}
              onMutedChange={setMuted}
              onInteraction={() => setPendingAdvanceId(null)}
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

      {/* Search lives in the global TopBar. Filters are navigable with touch,
          trackpad, keyboard and buttons; the gradient protects readability. */}
      <nav
        aria-label="Discover video filters"
        className="absolute inset-x-0 top-0 z-20 overflow-hidden bg-gradient-to-b from-[#10101c]/95 via-black/60 to-transparent pt-2 pb-5"
      >
        <div className="flex items-center gap-1.5 overflow-x-auto overscroll-x-contain touch-pan-x no-scrollbar px-4 snap-x snap-proximity [scrollbar-width:none]">
          {([
            { id: 'for_you', label: 'For You', mode: 'for_you' },
            { id: 'latest', label: 'Latest', mode: 'latest' },
            { id: 'popular', label: 'Popular', mode: 'popular' },
            { id: 'saved', label: 'Saved', mode: 'saved' },
          ] as const).map((tab) => {
            const active = !subject && feedMode === tab.mode;
            return (
              <button
                key={tab.id}
                type="button"
                aria-pressed={active}
                onClick={(event) => {
                  chooseFilter(tab.mode);
                  event.currentTarget.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
                }}
                className={`relative snap-center shrink-0 whitespace-nowrap px-3.5 pt-2 pb-3 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400 rounded-t-md ${active ? 'text-white' : 'text-white/60 hover:text-white'}`}
              >
                {tab.label}
                {active && <span className="absolute inset-x-3.5 bottom-1 h-[3px] rounded-full bg-gradient-to-r from-[#5f7bff] to-[#ac67ff]" />}
              </button>
            );
          })}
          {subjectChoices.map((name) => {
            const active = subject === name;
            return (
              <button
                key={`subject:${name}`}
                type="button"
                aria-pressed={active}
                onClick={(event) => {
                  chooseFilter('for_you', name);
                  event.currentTarget.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
                }}
                className={`relative snap-center shrink-0 whitespace-nowrap px-3.5 pt-2 pb-3 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400 rounded-t-md ${active ? 'text-white' : 'text-white/60 hover:text-white'}`}
              >
                {name}
                {active && <span className="absolute inset-x-3.5 bottom-1 h-[3px] rounded-full bg-gradient-to-r from-[#5f7bff] to-[#ac67ff]" />}
              </button>
            );
          })}
        </div>
        <div aria-hidden="true" className="pointer-events-none absolute inset-y-0 right-0 w-9 bg-gradient-to-l from-[#10101c]/95 to-transparent" />
      </nav>

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
