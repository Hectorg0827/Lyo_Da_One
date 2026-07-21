'use client';

import { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Play,
  Heart,
  MessageCircle,
  Share2,
  Bookmark,
  Grid3X3,
  MonitorPlay,
  Plus,
  Eye,
  TrendingUp,
  Users,
  Loader2,
  Send,
  Trash2,
  X,
} from 'lucide-react';
import { formatNumber, formatTimeAgo } from '@/lib/utils';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import { useAuthStore } from '@/stores/auth-store';

interface Clip {
  id: string;
  title: string;
  videoUrl: string;
  author: { name: string; avatar: string; username: string };
  thumbnailGradient: string;
  duration: string;
  views: number;
  likes: number;
  comments: number;
  tags: string[];
  category: string;
  isLiked: boolean;
  isBookmarked: boolean;
  createdAt: string;
}

interface ClipComment {
  id: string;
  userId: string;
  authorName: string;
  authorAvatar: string | null;
  content: string;
  createdAt: string;
}

const GRADIENT_LIST = [
  'from-blue-600 to-purple-600',
  'from-pink-600 to-red-600',
  'from-teal-500 to-green-500',
  'from-orange-500 to-yellow-500',
  'from-red-500 to-orange-500',
  'from-indigo-600 to-blue-500',
  'from-violet-600 to-purple-500',
  'from-amber-500 to-red-500',
  'from-emerald-500 to-teal-500',
  'from-rose-500 to-pink-500',
];

function formatDuration(totalSeconds: number): string {
  const mins = Math.floor(totalSeconds / 60);
  const secs = Math.round(totalSeconds % 60);
  return `${mins}:${String(secs).padStart(2, '0')}`;
}

/** Backend serializes clips in camelCase (Clip.to_dict); keep snake_case fallbacks for older payloads. */
function adaptClip(raw: Record<string, unknown>, index: number): Clip {
  const metadata = (raw.metadata as Record<string, unknown>) || {};
  const durationSeconds =
    (raw.durationSeconds as number) || (raw.duration_seconds as number) || (raw.duration as number) || 0;
  return {
    id: String(raw.id),
    title: (raw.title as string) || 'Untitled Clip',
    videoUrl: (raw.videoURL as string) || (raw.video_url as string) || '',
    author: {
      name: (raw.authorName as string) || (raw.creator_name as string) || (raw.user_name as string) || 'Member',
      avatar: (raw.authorAvatarURL as string) || (raw.creator_avatar as string) || '',
      username: (raw.creator_username as string) || (raw.authorName as string) || 'member',
    },
    thumbnailGradient: GRADIENT_LIST[index % GRADIENT_LIST.length],
    duration: formatDuration(durationSeconds),
    views: (raw.viewCount as number) || (raw.view_count as number) || 0,
    likes: (raw.likeCount as number) || (raw.like_count as number) || 0,
    comments: (raw.commentCount as number) || (raw.comment_count as number) || 0,
    tags: ((metadata.tags as string[]) || (raw.tags as string[]) || []).filter(Boolean),
    category:
      (metadata.subject as string) || (raw.subject as string) || (raw.topic as string) || (raw.category as string) || 'General',
    isLiked: (raw.isLiked as boolean) || (raw.is_liked as boolean) || false,
    isBookmarked: (raw.isSaved as boolean) || (raw.is_saved as boolean) || false,
    createdAt: (raw.createdAt as string) || (raw.created_at as string) || new Date().toISOString(),
  };
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

const tabs = ['For You', 'Following', 'Trending'];

async function shareClip(clip: Clip) {
  const url = `${window.location.origin}/clips?clip=${clip.id}`;
  try {
    if (navigator.share) {
      await navigator.share({ title: clip.title, text: `${clip.author.name} on LYO: ${clip.title}`, url });
    } else {
      await navigator.clipboard.writeText(url);
    }
    api.clips.share(clip.id).catch(() => {});
  } catch (error) {
    if ((error as DOMException)?.name !== 'AbortError') console.error(error);
  }
}

// ── Comments drawer ──────────────────────────────────────────────────────────

function ClipCommentsDrawer({ clip, onClose }: { clip: Clip; onClose: () => void }) {
  const currentUser = useAuthStore((state) => state.user);
  const [comments, setComments] = useState<ClipComment[]>([]);
  const [loading, setLoading] = useState(true);
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.clips
      .comments(clip.id)
      .then((result) => setComments((result.items ?? []).map(adaptComment)))
      .catch(() => setError('Unable to load comments.'))
      .finally(() => setLoading(false));
  }, [clip.id]);

  const submit = async () => {
    const content = text.trim();
    if (!content || sending) return;
    setSending(true);
    setError(null);
    try {
      const created = await api.clips.createComment(clip.id, content);
      setComments((prev) => [adaptComment(created), ...prev]);
      setText('');
    } catch {
      setError('Unable to post your comment. Please try again.');
    } finally {
      setSending(false);
    }
  };

  const remove = async (commentId: string) => {
    try {
      await api.clips.deleteComment(clip.id, commentId);
      setComments((prev) => prev.filter((c) => c.id !== commentId));
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
      className="fixed inset-y-0 right-0 z-[60] flex w-full max-w-sm flex-col border-l border-white/10 bg-[#0a0a0f]"
    >
      <header className="flex items-center justify-between border-b border-white/10 px-4 py-3">
        <h2 className="text-sm font-semibold text-white">Comments ({comments.length})</h2>
        <button onClick={onClose} aria-label="Close comments" className="rounded-lg p-2 text-white/50 hover:bg-white/10 hover:text-white">
          <X className="h-4 w-4" />
        </button>
      </header>

      <div className="flex-1 space-y-4 overflow-y-auto p-4">
        {loading ? (
          <div className="flex justify-center py-10"><Loader2 className="h-5 w-5 animate-spin text-lyo-500" /></div>
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
                    <button onClick={() => remove(comment.id)} aria-label="Delete comment" className="ml-auto text-white/30 hover:text-red-400">
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
        <form className="flex gap-2" onSubmit={(event) => { event.preventDefault(); submit(); }}>
          <input
            value={text}
            onChange={(event) => setText(event.target.value)}
            disabled={sending}
            placeholder="Add a comment…"
            className="min-w-0 flex-1 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-gray-500 outline-none focus:border-lyo-500/50"
          />
          <button type="submit" disabled={!text.trim() || sending} aria-label="Post comment" className="rounded-xl bg-lyo-500 p-2.5 text-white disabled:opacity-40">
            {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
          </button>
        </form>
        {error && <p role="alert" className="mt-2 text-xs text-red-400">{error}</p>}
      </footer>
    </motion.aside>
  );
}

// ── Create reel modal ────────────────────────────────────────────────────────

function CreateClipModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState('');
  const [subject, setSubject] = useState('');
  const [description, setDescription] = useState('');
  const [progress, setProgress] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);

  const submit = async () => {
    if (!file || !title.trim() || progress) return;
    setError(null);
    try {
      setProgress('Uploading video…');
      const uploaded = await api.media.upload(file, 'clips');
      setProgress('Publishing…');
      const duration = videoRef.current?.duration && isFinite(videoRef.current.duration)
        ? videoRef.current.duration
        : 0;
      await api.clips.create({
        title: title.trim(),
        description: description.trim() || null,
        videoUrl: uploaded.url,
        thumbnailUrl: null,
        durationSeconds: duration,
        subject: subject.trim() || null,
        topic: null,
        level: 'beginner',
        keyPoints: [],
        tags: subject.trim() ? [subject.trim().toLowerCase()] : [],
        isPublic: true,
        enableCourseGeneration: true,
      });
      onCreated();
      onClose();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to publish the clip.');
      setProgress(null);
    }
  };

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section role="dialog" aria-modal="true" className="w-full max-w-lg overflow-hidden rounded-2xl border border-white/10 bg-[#11121a] shadow-2xl">
        <header className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <h2 className="text-lg font-semibold text-white">Create a Clip</h2>
          <button onClick={onClose} aria-label="Close" className="rounded-lg p-2 text-white/50 hover:bg-white/10 hover:text-white"><X className="h-5 w-5" /></button>
        </header>

        <div className="max-h-[70vh] space-y-4 overflow-y-auto p-5">
          <label className="block text-sm text-white/65">
            Video (mp4, mov, or webm — up to 200MB)
            <input
              type="file"
              accept="video/mp4,video/quicktime,video/webm"
              onChange={(event) => setFile(event.target.files?.[0] ?? null)}
              className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white file:mr-3 file:rounded-lg file:border-0 file:bg-lyo-500 file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-white"
            />
          </label>
          {file && (
            <video
              ref={videoRef}
              src={URL.createObjectURL(file)}
              controls
              className="max-h-56 w-full rounded-xl border border-white/10 bg-black"
            />
          )}
          <label className="block text-sm text-white/65">
            Title
            <input value={title} onChange={(event) => setTitle(event.target.value)} maxLength={200} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" />
          </label>
          <label className="block text-sm text-white/65">
            Subject (optional)
            <input value={subject} onChange={(event) => setSubject(event.target.value)} maxLength={100} placeholder="e.g. Mathematics" className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" />
          </label>
          <label className="block text-sm text-white/65">
            Description (optional)
            <textarea value={description} onChange={(event) => setDescription(event.target.value)} rows={2} maxLength={2000} className="mt-1.5 w-full resize-y rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" />
          </label>
          {error && <p role="alert" className="text-sm text-red-400">{error}</p>}
        </div>

        <footer className="flex justify-end gap-3 border-t border-white/10 px-5 py-4">
          <button onClick={onClose} disabled={!!progress} className="rounded-xl border border-white/15 px-4 py-2.5 text-sm text-white/70 hover:bg-white/10">Cancel</button>
          <button onClick={submit} disabled={!file || !title.trim() || !!progress} className="flex min-w-36 items-center justify-center gap-2 rounded-xl bg-lyo-500 px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-50">
            {progress ? (<><Loader2 className="h-4 w-4 animate-spin" />{progress}</>) : 'Publish clip'}
          </button>
        </footer>
      </section>
    </div>
  );
}

// ── Cards & fullscreen player ────────────────────────────────────────────────

function ClipGridCard({ clip, onClick, onLike }: { clip: Clip; onClick: () => void; onLike?: (clipId: string) => void }) {
  const [liked, setLiked] = useState(clip.isLiked);

  return (
    <motion.div
      whileHover={{ y: -4 }}
      className="group cursor-pointer overflow-hidden rounded-2xl border border-white/5 bg-white/5 backdrop-blur-sm"
      onClick={onClick}
    >
      <div className={`relative aspect-[9/16] bg-gradient-to-br ${clip.thumbnailGradient}`}>
        {clip.videoUrl && (
          <video src={clip.videoUrl} muted playsInline preload="metadata" className="absolute inset-0 h-full w-full object-cover" />
        )}
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="rounded-full bg-black/30 p-4 backdrop-blur-sm transition group-hover:scale-110 group-hover:bg-black/50">
            <Play className="h-8 w-8 text-white" fill="white" />
          </div>
        </div>
        <div className="absolute bottom-2 right-2 rounded-md bg-black/60 px-1.5 py-0.5 text-xs font-medium text-white">
          {clip.duration}
        </div>
        <div className="absolute left-2 top-2 rounded-md bg-black/40 px-2 py-0.5 text-xs text-white/80">
          {clip.category}
        </div>
      </div>
      <div className="p-3">
        <h3 className="line-clamp-2 text-sm font-medium text-white">{clip.title}</h3>
        <div className="mt-1.5 flex items-center gap-2">
          <div className="flex h-5 w-5 items-center justify-center rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple text-[10px] font-bold text-white">
            {clip.author.name[0]}
          </div>
          <span className="text-xs text-gray-400">{clip.author.name}</span>
        </div>
        <div className="mt-2 flex items-center gap-3 text-xs text-gray-500">
          <span className="flex items-center gap-1">
            <Eye className="h-3 w-3" />
            {formatNumber(clip.views)}
          </span>
          <button
            onClick={(e) => {
              e.stopPropagation();
              setLiked(!liked);
              onLike?.(clip.id);
            }}
            className={`flex items-center gap-1 transition ${liked ? 'text-red-400' : ''}`}
          >
            <Heart className="h-3 w-3" fill={liked ? 'currentColor' : 'none'} />
            {formatNumber(liked ? clip.likes + 1 : clip.likes)}
          </button>
          <span className="flex items-center gap-1">
            <MessageCircle className="h-3 w-3" />
            {formatNumber(clip.comments)}
          </span>
        </div>
      </div>
    </motion.div>
  );
}

function ClipFullscreen({
  clip,
  onClose,
  onLike,
  onSave,
  onView,
  onComments,
}: {
  clip: Clip;
  onClose: () => void;
  onLike?: (clipId: string) => void;
  onSave?: (clipId: string) => void;
  onView?: (clipId: string) => void;
  onComments?: (clip: Clip) => void;
}) {
  const [liked, setLiked] = useState(clip.isLiked);
  const [bookmarked, setBookmarked] = useState(clip.isBookmarked);
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    onView?.(clip.id);
  }, [clip.id, onView]);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 flex items-center justify-center bg-black"
    >
      <div className="relative h-full w-full max-w-md">
        {clip.videoUrl ? (
          <video src={clip.videoUrl} autoPlay loop controls playsInline className="absolute inset-0 h-full w-full bg-black object-contain" />
        ) : (
          <>
            <div className={`absolute inset-0 bg-gradient-to-br ${clip.thumbnailGradient} opacity-80`} />
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="rounded-full bg-black/20 p-6 backdrop-blur-sm">
                <Play className="h-16 w-16 text-white/80" fill="white" />
              </div>
            </div>
          </>
        )}

        <button
          onClick={onClose}
          className="absolute left-4 top-4 z-10 rounded-full bg-black/30 px-3 py-1.5 text-sm text-white backdrop-blur-sm"
        >
          ← Back
        </button>

        <div className="pointer-events-none absolute bottom-16 left-0 right-16 p-4">
          <div className="flex items-center gap-2">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple font-bold text-white">
              {clip.author.name[0]}
            </div>
            <div>
              <p className="text-sm font-semibold text-white">{clip.author.name}</p>
              <p className="text-xs text-white/60">@{clip.author.username}</p>
            </div>
          </div>
          <h3 className="mt-2 text-base font-semibold text-white">{clip.title}</h3>
          <p
            className={`pointer-events-auto mt-1 text-sm text-white/70 ${expanded ? '' : 'line-clamp-2'}`}
            onClick={() => setExpanded(!expanded)}
          >
            Learn {clip.category.toLowerCase()} with this quick tip! {clip.tags.map((t) => `#${t}`).join(' ')}
          </p>
        </div>

        <div className="absolute bottom-16 right-3 flex flex-col items-center gap-5">
          <button onClick={() => { setLiked(!liked); onLike?.(clip.id); }} className="flex flex-col items-center gap-1">
            <motion.div whileTap={{ scale: 1.3 }}>
              <Heart
                className={`h-7 w-7 ${liked ? 'text-red-500' : 'text-white'}`}
                fill={liked ? 'currentColor' : 'none'}
              />
            </motion.div>
            <span className="text-xs text-white">{formatNumber(liked ? clip.likes + 1 : clip.likes)}</span>
          </button>
          <button onClick={() => onComments?.(clip)} className="flex flex-col items-center gap-1">
            <MessageCircle className="h-7 w-7 text-white" />
            <span className="text-xs text-white">{formatNumber(clip.comments)}</span>
          </button>
          <button onClick={() => shareClip(clip)} className="flex flex-col items-center gap-1">
            <Share2 className="h-7 w-7 text-white" />
            <span className="text-xs text-white">Share</span>
          </button>
          <button onClick={() => { setBookmarked(!bookmarked); onSave?.(clip.id); }} className="flex flex-col items-center gap-1">
            <Bookmark
              className={`h-7 w-7 ${bookmarked ? 'text-yellow-400' : 'text-white'}`}
              fill={bookmarked ? 'currentColor' : 'none'}
            />
            <span className="text-xs text-white">Save</span>
          </button>
        </div>
      </div>
    </motion.div>
  );
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function ClipsPage() {
  const [activeTab, setActiveTab] = useState('For You');
  const [viewMode, setViewMode] = useState<'grid' | 'feed'>('grid');
  const [selectedClip, setSelectedClip] = useState<Clip | null>(null);
  const [commentsClip, setCommentsClip] = useState<Clip | null>(null);
  const [showCreate, setShowCreate] = useState(false);

  const { data: clipsData, isLoading, refetch } = useApi(() => api.clips.discover(), []);
  const clips: Clip[] = clipsData?.clips?.map((raw, i) => adaptClip(raw, i)) ?? [];

  const handleLike = async (clipId: string) => { try { await api.clips.like(clipId); } catch { /* ignore */ } };
  const handleSave = async (clipId: string) => { try { await api.clips.save(clipId); } catch { /* ignore */ } };
  const handleView = async (clipId: string) => { try { await api.clips.view(clipId); } catch { /* ignore */ } };

  return (
    <div className="min-h-screen p-6">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Clips</h1>
          <p className="text-sm text-gray-400">Short educational videos from the community</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex rounded-xl border border-white/10 bg-white/5 p-1">
            <button
              onClick={() => setViewMode('grid')}
              className={`rounded-lg p-2 transition ${viewMode === 'grid' ? 'bg-lyo-600 text-white' : 'text-gray-400 hover:text-white'}`}
            >
              <Grid3X3 className="h-4 w-4" />
            </button>
            <button
              onClick={() => setViewMode('feed')}
              className={`rounded-lg p-2 transition ${viewMode === 'feed' ? 'bg-lyo-600 text-white' : 'text-gray-400 hover:text-white'}`}
            >
              <MonitorPlay className="h-4 w-4" />
            </button>
          </div>
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple px-4 py-2.5 text-sm font-medium text-white shadow-lg shadow-lyo-500/20 transition hover:shadow-lyo-500/40"
          >
            <Plus className="h-4 w-4" />
            Create Clip
          </button>
        </div>
      </div>

      <div className="mb-6 flex gap-1 rounded-xl border border-white/10 bg-white/5 p-1">
        {tabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex items-center gap-1.5 rounded-lg px-4 py-2 text-sm font-medium transition ${
              activeTab === tab ? 'bg-lyo-600 text-white' : 'text-gray-400 hover:text-white'
            }`}
          >
            {tab === 'Trending' && <TrendingUp className="h-3.5 w-3.5" />}
            {tab === 'Following' && <Users className="h-3.5 w-3.5" />}
            {tab}
          </button>
        ))}
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="h-8 w-8 animate-spin text-lyo-500" />
        </div>
      ) : clips.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-center">
          <MonitorPlay className="mb-4 h-12 w-12 text-gray-500" />
          <p className="text-lg font-medium text-white">No clips yet</p>
          <p className="mt-1 text-sm text-gray-400">Create your first!</p>
        </div>
      ) : viewMode === 'grid' ? (
        <motion.div
          className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4"
          initial="hidden"
          animate="visible"
          variants={{ visible: { transition: { staggerChildren: 0.05 } } }}
        >
          {clips.map((clip) => (
            <motion.div
              key={clip.id}
              variants={{
                hidden: { opacity: 0, y: 20 },
                visible: { opacity: 1, y: 0 },
              }}
            >
              <ClipGridCard clip={clip} onClick={() => setSelectedClip(clip)} onLike={handleLike} />
            </motion.div>
          ))}
        </motion.div>
      ) : (
        <div className="mx-auto max-w-md">
          <div className="h-[calc(100vh-200px)] snap-y snap-mandatory overflow-y-auto rounded-2xl">
            {clips.map((clip) => (
              <div key={clip.id} className="h-full snap-start">
                <div className={`relative h-full overflow-hidden rounded-2xl bg-gradient-to-br ${clip.thumbnailGradient}`}>
                  {clip.videoUrl ? (
                    <video src={clip.videoUrl} muted loop playsInline autoPlay className="absolute inset-0 h-full w-full bg-black object-cover" />
                  ) : (
                    <div className="absolute inset-0 flex items-center justify-center">
                      <Play className="h-16 w-16 text-white/50" fill="white" />
                    </div>
                  )}
                  <div className="absolute bottom-4 left-4 right-16">
                    <p className="text-sm font-semibold text-white">{clip.author.name}</p>
                    <p className="mt-1 text-sm text-white">{clip.title}</p>
                    <p className="mt-1 text-xs text-white/60">{clip.tags.map((t) => `#${t}`).join(' ')}</p>
                  </div>
                  <div className="absolute bottom-4 right-3 flex flex-col gap-4">
                    <button onClick={() => handleLike(clip.id)} className="flex flex-col items-center gap-0.5">
                      <Heart className="h-6 w-6 text-white" />
                      <span className="text-[10px] text-white">{formatNumber(clip.likes)}</span>
                    </button>
                    <button onClick={() => setCommentsClip(clip)} className="flex flex-col items-center gap-0.5">
                      <MessageCircle className="h-6 w-6 text-white" />
                      <span className="text-[10px] text-white">{formatNumber(clip.comments)}</span>
                    </button>
                    <button onClick={() => shareClip(clip)} className="flex flex-col items-center gap-0.5">
                      <Share2 className="h-6 w-6 text-white" />
                    </button>
                    <button onClick={() => handleSave(clip.id)} className="flex flex-col items-center gap-0.5">
                      <Bookmark className="h-6 w-6 text-white" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <AnimatePresence>
        {selectedClip && (
          <ClipFullscreen
            clip={selectedClip}
            onClose={() => setSelectedClip(null)}
            onLike={handleLike}
            onSave={handleSave}
            onView={handleView}
            onComments={setCommentsClip}
          />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {commentsClip && <ClipCommentsDrawer clip={commentsClip} onClose={() => setCommentsClip(null)} />}
      </AnimatePresence>

      {showCreate && <CreateClipModal onClose={() => setShowCreate(false)} onCreated={refetch} />}
    </div>
  );
}
