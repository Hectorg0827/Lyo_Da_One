'use client';

/**
 * Moderation — where a moderator decides on Discover videos.
 *
 * The API decides who may use it (a superuser, or an email on its
 * DISCOVER_MODERATOR_EMAILS list); everyone else gets a short note. Reported
 * lists what learners reported, most reporters first; All videos lists every
 * video that is not removed; Removed lists what was taken down, by whom and
 * why. Keep, Remove and Restore act on the server and the video then leaves
 * the tab it was in.
 */

import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import toast from 'react-hot-toast';
import { Check, Flag, Loader2, Play, RotateCcw, Search, ShieldCheck, Trash2 } from 'lucide-react';
import { api } from '@/lib/api';
import { formatTimeAgo } from '@/lib/utils';
import { pagesToFetch } from '@/lib/discover-report.mjs';
import {
  DECISION_MESSAGES,
  MODERATION_VIEWS,
  actionsFor,
  belongsIn,
  reasonLabel,
  statusLabel,
  type ModerationAction,
  type ModerationView,
} from '@/lib/moderation.mjs';

interface ModerationClip {
  id: string;
  title: string;
  description: string;
  videoUrl: string;
  posterUrl: string;
  authorName: string;
  createdAt: string | null;
  moderationStatus: string;
  reports: { pending: number; total: number; reasons: Record<string, number>; notes: { text: string; reason: string }[] };
  moderatedAt: string | null;
  moderatedBy: string | null;
  moderationNote: string | null;
}

function adaptClip(raw: Record<string, unknown>): ModerationClip {
  const reports = (raw.reports as ModerationClip['reports']) || { pending: 0, total: 0, reasons: {}, notes: [] };
  return {
    id: String(raw.id),
    title: (raw.title as string) || 'Untitled',
    description: (raw.description as string) || '',
    videoUrl: (raw.videoURL as string) || '',
    posterUrl: (raw.thumbnailURL as string) || '',
    authorName: (raw.authorName as string) || 'Member',
    createdAt: (raw.createdAt as string) || null,
    moderationStatus: (raw.moderationStatus as string) || 'active',
    reports,
    moderatedAt: (raw.moderatedAt as string) || null,
    moderatedBy: (raw.moderatedBy as string) || null,
    moderationNote: (raw.moderationNote as string) || null,
  };
}

function Preview({ clip }: { clip: ModerationClip }) {
  const [playing, setPlaying] = useState(false);
  const offline = clip.moderationStatus === 'removed';
  if (playing && !offline) {
    return (
      <video
        src={clip.videoUrl}
        poster={clip.posterUrl || undefined}
        controls
        autoPlay
        playsInline
        className="aspect-[9/16] w-28 shrink-0 rounded-xl bg-black object-contain sm:w-32"
      />
    );
  }
  return (
    <button
      type="button"
      disabled={offline}
      onClick={() => setPlaying(true)}
      aria-label={offline ? 'Video is offline' : `Play ${clip.title}`}
      className="relative flex aspect-[9/16] w-28 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-white/[0.06] sm:w-32"
    >
      {!offline && clip.posterUrl && (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={clip.posterUrl} alt="" className="absolute inset-0 h-full w-full object-cover" />
      )}
      {offline ? (
        <span className="px-2 text-center text-xs text-white/50">Files offline</span>
      ) : (
        <span className="relative flex h-10 w-10 items-center justify-center rounded-full bg-black/60">
          <Play className="h-5 w-5 text-white" />
        </span>
      )}
    </button>
  );
}

function ClipCard({
  clip,
  busy,
  onDecide,
}: {
  clip: ModerationClip;
  busy: boolean;
  onDecide: (clip: ModerationClip, action: ModerationAction, note?: string) => void;
}) {
  const [confirmingRemove, setConfirmingRemove] = useState(false);
  const [note, setNote] = useState('');
  const reasons = Object.entries(clip.reports.reasons);

  return (
    <li className="flex gap-4 rounded-2xl border border-white/[0.08] bg-white/[0.035] p-4">
      <Preview clip={clip} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-start justify-between gap-2">
          <h2 className="min-w-0 break-words text-base font-semibold text-white">{clip.title}</h2>
          <span
            className={`shrink-0 rounded-full px-2.5 py-0.5 text-xs font-semibold ${
              clip.moderationStatus === 'hidden'
                ? 'bg-amber-400/15 text-amber-200'
                : clip.moderationStatus === 'removed'
                  ? 'bg-red-500/15 text-red-300'
                  : 'bg-emerald-400/10 text-emerald-300'
            }`}
          >
            {statusLabel(clip.moderationStatus)}
          </span>
        </div>
        <p className="mt-0.5 text-sm text-white/50">
          by {clip.authorName}
          {clip.createdAt ? ` · ${formatTimeAgo(clip.createdAt)}` : ''}
        </p>

        {clip.reports.pending > 0 && (
          <div className="mt-3">
            <p className="flex items-center gap-1.5 text-sm font-semibold text-red-300">
              <Flag className="h-3.5 w-3.5" aria-hidden="true" />
              {clip.reports.pending} {clip.reports.pending === 1 ? 'report' : 'reports'}
            </p>
            <div className="mt-1.5 flex flex-wrap gap-1.5">
              {reasons.map(([reason, count]) => (
                <span key={reason} className="rounded-full bg-white/[0.07] px-2.5 py-0.5 text-xs text-white/80">
                  {reasonLabel(reason)}
                  {count > 1 ? ` ×${count}` : ''}
                </span>
              ))}
            </div>
            {clip.reports.notes.length > 0 && (
              <ul className="mt-2 space-y-1">
                {clip.reports.notes.map((item, index) => (
                  <li key={index} className="break-words text-sm italic text-white/60">
                    “{item.text}”
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

        {clip.moderationStatus === 'removed' && (
          <p className="mt-3 break-words text-sm text-white/60">
            Removed{clip.moderatedBy ? ` by ${clip.moderatedBy}` : ''}
            {clip.moderatedAt ? ` · ${formatTimeAgo(clip.moderatedAt)}` : ''}
            {clip.moderationNote ? ` — “${clip.moderationNote}”` : ''}
          </p>
        )}

        {confirmingRemove ? (
          <form
            className="mt-3 space-y-2"
            onSubmit={(event) => {
              event.preventDefault();
              onDecide(clip, 'remove', note.trim());
            }}
          >
            <label className="block text-sm text-white/70">
              Why are you removing it? (optional, only moderators see this)
              <textarea
                value={note}
                onChange={(event) => setNote(event.target.value)}
                maxLength={500}
                rows={2}
                className="mt-1 w-full resize-none rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white outline-none focus:border-red-400/60"
              />
            </label>
            <div className="flex flex-wrap gap-2">
              <button
                type="submit"
                disabled={busy}
                className="flex items-center gap-1.5 rounded-xl bg-red-500 px-4 py-2 text-sm font-semibold text-white disabled:opacity-40"
              >
                {busy ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" /> : <Trash2 className="h-4 w-4" aria-hidden="true" />}
                Remove video
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={() => setConfirmingRemove(false)}
                className="rounded-xl border border-white/15 px-4 py-2 text-sm text-white/80"
              >
                Cancel
              </button>
            </div>
          </form>
        ) : (
          <div className="mt-3 flex flex-wrap gap-2">
            {actionsFor(clip).map((action) =>
              action === 'remove' ? (
                <button
                  key={action}
                  type="button"
                  disabled={busy}
                  onClick={() => setConfirmingRemove(true)}
                  className="flex items-center gap-1.5 rounded-xl border border-red-400/40 px-4 py-2 text-sm font-semibold text-red-300 hover:bg-red-500/10 disabled:opacity-40"
                >
                  <Trash2 className="h-4 w-4" aria-hidden="true" />
                  Remove
                </button>
              ) : (
                <button
                  key={action}
                  type="button"
                  disabled={busy}
                  onClick={() => onDecide(clip, action)}
                  className="flex items-center gap-1.5 rounded-xl bg-white px-4 py-2 text-sm font-semibold text-[#0d0f18] disabled:opacity-40"
                >
                  {busy ? (
                    <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />
                  ) : action === 'keep' ? (
                    <Check className="h-4 w-4" aria-hidden="true" />
                  ) : (
                    <RotateCcw className="h-4 w-4" aria-hidden="true" />
                  )}
                  {action === 'keep' ? 'Keep' : 'Restore'}
                </button>
              )
            )}
          </div>
        )}
      </div>
    </li>
  );
}

export default function ModerationPage() {
  const [access, setAccess] = useState<'checking' | 'moderator' | 'denied' | 'error'>('checking');
  const [view, setView] = useState<ModerationView>('reported');
  const [searchText, setSearchText] = useState('');
  const [query, setQuery] = useState('');
  const [clips, setClips] = useState<ModerationClip[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const [busyIds, setBusyIds] = useState<Set<string>>(() => new Set());
  // Bumped by every list request and by every decision, so an answer that
  // started before either is dropped rather than shown over newer state.
  const generation = useRef(0);
  // Bumped when a list starts over (new tab, search or reload); a decision
  // only edits the list it was made in.
  const listVersion = useRef(0);
  // Each decision takes a video out of this list on the server too, so later
  // pages start that many places earlier (see pagesToFetch).
  const decidedSinceLoad = useRef(0);

  const checkAccess = useCallback(() => {
    setAccess('checking');
    api.moderation
      .me()
      .then((result) => setAccess(result.moderator ? 'moderator' : 'denied'))
      // A failed check is not a "no": it gets its own message and a retry.
      .catch(() => setAccess('error'));
  }, []);

  useEffect(() => {
    checkAccess();
  }, [checkAccess]);

  const load = useCallback(async (nextView: ModerationView, nextQuery: string, nextPage: number) => {
    const current = ++generation.current;
    if (nextPage === 1) {
      listVersion.current += 1;
      decidedSinceLoad.current = 0;
      setClips([]);
      setTotal(0);
      setPage(1);
    }
    setLoading(true);
    setFailed(false);
    try {
      const pages = pagesToFetch(nextPage, decidedSinceLoad.current, 20);
      const results = await Promise.all(
        pages.map((number) => api.moderation.clips(nextView, { q: nextQuery || undefined, page: number }))
      );
      if (current !== generation.current) return;
      const incoming = results.flatMap((result) => (result.clips || []).map(adaptClip));
      setClips((previous) => {
        const merged = nextPage === 1 ? [] : [...previous];
        for (const clip of incoming) if (!merged.some((item) => item.id === clip.id)) merged.push(clip);
        return merged;
      });
      setTotal(results[results.length - 1].total || 0);
      setPage(nextPage);
    } catch {
      if (current === generation.current) setFailed(true);
    } finally {
      if (current === generation.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (access === 'moderator') void load(view, query, 1);
  }, [access, view, query, load]);

  // Deciding on every loaded video empties the list while more remain on the
  // server; those are now its first page.
  useEffect(() => {
    if (access === 'moderator' && !loading && !failed && clips.length === 0 && total > 0 && decidedSinceLoad.current > 0) {
      void load(view, query, 1);
    }
  }, [access, loading, failed, clips.length, total, view, query, load]);

  const setBusy = (id: string, busy: boolean) =>
    setBusyIds((previous) => {
      const next = new Set(previous);
      if (busy) next.add(id);
      else next.delete(id);
      return next;
    });

  const decide = async (clip: ModerationClip, action: ModerationAction, note?: string) => {
    const startedIn = listVersion.current;
    setBusy(clip.id, true);
    try {
      const result = await api.moderation.decide(clip.id, action, note);
      if (listVersion.current === startedIn) {
        // A list page still in flight was read before this decision.
        generation.current += 1;
        setLoading(false);
        const updated = adaptClip(result.clip);
        if (belongsIn(view, updated)) {
          setClips((previous) => previous.map((item) => (item.id === clip.id ? updated : item)));
        } else {
          // It moved to another tab, or a kept video left Reported.
          setClips((previous) => previous.filter((item) => item.id !== clip.id));
          setTotal((previous) => Math.max(0, previous - 1));
          decidedSinceLoad.current += 1;
        }
      }
      toast(DECISION_MESSAGES[action]);
    } catch (err) {
      toast.error(err instanceof Error && err.message ? err.message : 'That could not be saved. Please try again.');
      // The decision may have been saved even though its answer was lost, or
      // someone else decided first: show what the server has now.
      if (listVersion.current === startedIn) void load(view, query, 1);
    } finally {
      setBusy(clip.id, false);
    }
  };

  if (access === 'checking') {
    return (
      <div className="flex h-[60vh] items-center justify-center" aria-label="Loading moderation">
        <Loader2 className="h-6 w-6 animate-spin text-white/60" />
      </div>
    );
  }

  if (access === 'error') {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center px-6 text-center text-white">
        <h1 className="text-xl font-bold">Couldn&apos;t check your access</h1>
        <p className="mt-2 max-w-sm text-sm text-white/60">Check your connection and try again.</p>
        <button type="button" onClick={checkAccess} className="mt-6 rounded-full bg-white px-5 py-2.5 text-sm font-bold text-[#0d0f18]">
          Try again
        </button>
      </div>
    );
  }

  if (access === 'denied') {
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center px-6 text-center text-white">
        <ShieldCheck className="h-8 w-8 text-white/40" aria-hidden="true" />
        <h1 className="mt-3 text-xl font-bold">This page is for moderators</h1>
        <p className="mt-2 max-w-sm text-sm text-white/60">If you see something wrong in Discover, use the Report button on the video.</p>
        <Link href="/discover" className="mt-6 rounded-full bg-white px-5 py-2.5 text-sm font-bold text-[#0d0f18]">
          Back to Discover
        </Link>
      </div>
    );
  }

  const currentView = MODERATION_VIEWS.find((item) => item.id === view)!;

  return (
    <div className="mx-auto max-w-3xl space-y-5 px-4 py-6 text-white sm:px-6">
      <header>
        <h1 className="font-rounded text-2xl font-black">Moderation</h1>
        <p className="mt-1 text-sm text-white/60">
          Reported videos wait here. Three reports from different people hide a video until you decide.
        </p>
      </header>

      <nav aria-label="Moderation views" className="flex gap-1 rounded-2xl bg-white/[0.04] p-1">
        {MODERATION_VIEWS.map((item) => (
          <button
            key={item.id}
            type="button"
            aria-pressed={view === item.id}
            onClick={() => setView(item.id)}
            className={`flex-1 rounded-xl px-3 py-2 text-sm font-semibold transition-colors ${
              view === item.id ? 'bg-white text-[#0d0f18]' : 'text-white/70 hover:text-white'
            }`}
          >
            {item.label}
            {view === item.id && !loading ? ` (${total})` : ''}
          </button>
        ))}
      </nav>

      <form
        role="search"
        onSubmit={(event) => {
          event.preventDefault();
          setQuery(searchText.trim());
        }}
        className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/[0.04] px-3"
      >
        <Search className="h-4 w-4 shrink-0 text-white/50" aria-hidden="true" />
        <input
          value={searchText}
          onChange={(event) => setSearchText(event.target.value)}
          placeholder="Search titles, subjects and tags"
          aria-label="Search videos"
          className="min-w-0 flex-1 bg-transparent py-2.5 text-sm text-white outline-none placeholder:text-white/40"
        />
      </form>

      {failed && clips.length === 0 ? (
        <div className="rounded-2xl border border-white/10 p-6 text-center">
          <p className="text-sm text-white/70">The list couldn&apos;t load. Check your connection and try again.</p>
          <button type="button" onClick={() => void load(view, query, 1)} className="mt-3 rounded-xl border border-white/30 px-4 py-2 text-sm">
            Try again
          </button>
        </div>
      ) : loading && clips.length === 0 ? (
        <div className="flex justify-center py-10">
          <Loader2 className="h-6 w-6 animate-spin text-white/60" aria-label="Loading videos" />
        </div>
      ) : clips.length === 0 ? (
        <p className="py-10 text-center text-sm text-white/50">{currentView.empty}</p>
      ) : (
        <ul className="space-y-3">
          {clips.map((clip) => (
            <ClipCard key={clip.id} clip={clip} busy={busyIds.has(clip.id)} onDecide={decide} />
          ))}
        </ul>
      )}

      {failed && clips.length > 0 && (
        <p className="text-center text-sm text-red-300">
          More videos couldn&apos;t load.{' '}
          <button type="button" onClick={() => void load(view, query, page + 1)} className="underline">
            Try again
          </button>
        </p>
      )}

      {clips.length > 0 && clips.length < total && !failed && (
        <div className="flex justify-center">
          <button
            type="button"
            disabled={loading}
            onClick={() => void load(view, query, page + 1)}
            className="rounded-xl border border-white/20 px-5 py-2 text-sm text-white/80 disabled:opacity-40"
          >
            {loading ? 'Loading…' : 'Show more'}
          </button>
        </div>
      )}
    </div>
  );
}
