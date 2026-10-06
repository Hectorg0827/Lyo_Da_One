'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Loader2, Send, Trash2, X } from 'lucide-react';
import { formatTimeAgo } from '@/lib/utils';
import { api } from '@/lib/api';
import { useAuthStore } from '@/stores/auth-store';

/**
 * Comments on one clip.
 *
 * Lifted out of the old `/clips` page so Discover can use it too. Discover is
 * the surface everything links to — the mobile nav, search, the empty course
 * stack — but it had no way to comment, because commenting lived on a second
 * reel page almost nothing pointed at. One feed, one set of actions.
 *
 * Takes an id rather than a clip, so a caller holding any shape of clip can
 * open it.
 */

interface ClipComment {
  id: string;
  userId: string;
  authorName: string;
  authorAvatar: string | null;
  content: string;
  createdAt: string;
}

function adaptComment(raw: Record<string, unknown>): ClipComment {
  return {
    id: String(raw.id ?? ''),
    userId: String(raw.userId ?? raw.user_id ?? ''),
    authorName: (raw.authorName as string) || 'Member',
    authorAvatar: (raw.authorAvatarURL as string) || null,
    content: (raw.content as string) || '',
    createdAt: (raw.createdAt as string) || new Date().toISOString(),
  };
}

export default function ClipCommentsDrawer({
  clipId,
  onClose,
  onCountChange,
}: {
  clipId: string;
  onClose: () => void;
  /** Lets the feed's comment count follow what the drawer actually holds. */
  onCountChange?: (count: number) => void;
}) {
  const currentUser = useAuthStore((state) => state.user);
  const [comments, setComments] = useState<ClipComment[]>([]);
  // The server's own total, which is not the same as the number of comments
  // loaded: the endpoint returns one page (50 by default). Reporting the
  // page size back to the feed would turn a clip with 137 comments into one
  // with 50 the moment someone opened the drawer, and every later add or
  // delete would count on from that wrong number.
  const [total, setTotal] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let live = true;
    setLoading(true);
    api.clips
      .comments(clipId)
      .then((result) => {
        if (!live) return;
        const next = (result.items ?? []).map(adaptComment);
        setComments(next);
        const serverTotal =
          typeof result.total_count === 'number' ? result.total_count : next.length;
        setTotal(serverTotal);
        onCountChange?.(serverTotal);
      })
      .catch(() => live && setError('Unable to load comments.'))
      .finally(() => live && setLoading(false));
    return () => {
      live = false;
    };
    // onCountChange is a callback from the parent; re-running on its identity
    // would refetch the list on every parent render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [clipId]);

  const submit = async () => {
    const content = text.trim();
    if (!content || sending) return;
    setSending(true);
    setError(null);
    try {
      const created = await api.clips.createComment(clipId, content);
      setComments((prev) => [adaptComment(created), ...prev]);
      // A delta on the server's total, not a recount of what is loaded.
      setTotal((prev) => {
        const next = (prev ?? comments.length) + 1;
        onCountChange?.(next);
        return next;
      });
      setText('');
    } catch {
      setError('Unable to post your comment. Please try again.');
    } finally {
      setSending(false);
    }
  };

  const remove = async (commentId: string) => {
    try {
      await api.clips.deleteComment(clipId, commentId);
      setComments((prev) => prev.filter((c) => c.id !== commentId));
      setTotal((prev) => {
        const next = Math.max(0, (prev ?? comments.length) - 1);
        onCountChange?.(next);
        return next;
      });
    } catch {
      setError('Unable to delete the comment.');
    }
  };

  return (
    <motion.aside
      initial={{ x: '100%' }}
      animate={{ x: 0 }}
      exit={{ x: '100%' }}
      transition={{ type: 'tween', duration: 0.2 }}
      className="fixed inset-y-0 right-0 z-[60] flex w-full max-w-sm flex-col border-l border-white/10 bg-[#050810]"
      onClick={(event) => event.stopPropagation()}
    >
      <header className="flex items-center justify-between border-b border-white/10 px-4 py-3">
        <h2 className="text-sm font-semibold text-white">Comments ({total ?? comments.length})</h2>
        <button
          onClick={onClose}
          aria-label="Close comments"
          className="rounded-lg p-2 text-white/50 hover:bg-white/10 hover:text-white"
        >
          <X className="h-4 w-4" />
        </button>
      </header>

      <div className="flex-1 space-y-4 overflow-y-auto p-4">
        {loading ? (
          <div className="flex justify-center py-10">
            <Loader2 className="h-5 w-5 animate-spin text-lyo-500" />
          </div>
        ) : comments.length === 0 ? (
          <p className="py-10 text-center text-sm text-white/40">No comments yet. Be the first!</p>
        ) : (
          comments.map((comment) => (
            <div key={comment.id} className="flex gap-3">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple text-xs font-bold text-white">
                {comment.authorAvatar ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={comment.authorAvatar} alt="" className="h-full w-full object-cover" />
                ) : (
                  comment.authorName[0]?.toUpperCase() || 'M'
                )}
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-baseline gap-2">
                  <span className="text-sm font-semibold text-white">{comment.authorName}</span>
                  <span className="text-xs text-white/40">{formatTimeAgo(comment.createdAt)}</span>
                  {currentUser && comment.userId === currentUser.id && (
                    <button
                      onClick={() => remove(comment.id)}
                      aria-label="Delete comment"
                      className="ml-auto text-white/30 hover:text-red-400"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  )}
                </div>
                <p className="whitespace-pre-wrap break-words text-sm text-white/80">{comment.content}</p>
              </div>
            </div>
          ))
        )}
      </div>

      <footer className="border-t border-white/10 p-3">
        <form
          className="flex gap-2"
          onSubmit={(event) => {
            event.preventDefault();
            submit();
          }}
        >
          <input
            value={text}
            onChange={(event) => setText(event.target.value)}
            disabled={sending}
            placeholder="Add a comment…"
            className="min-w-0 flex-1 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-gray-500 outline-none focus:border-lyo-500/50"
          />
          <button
            type="submit"
            disabled={!text.trim() || sending}
            aria-label="Post comment"
            className="rounded-xl bg-lyo-500 p-2.5 text-white disabled:opacity-40"
          >
            {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
          </button>
        </form>
        {error && (
          <p role="alert" className="mt-2 text-xs text-red-400">
            {error}
          </p>
        )}
      </footer>
    </motion.aside>
  );
}
