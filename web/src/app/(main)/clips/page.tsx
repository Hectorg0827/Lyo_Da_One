'use client';

import { useState, useEffect } from 'react';
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
  Clock,
  TrendingUp,
  Users,
  Loader2,
} from 'lucide-react';
import { formatNumber, formatTimeAgo } from '@/lib/utils';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';

interface Clip {
  id: string;
  title: string;
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
  const secs = totalSeconds % 60;
  return `${mins}:${String(secs).padStart(2, '0')}`;
}

function adaptClip(raw: Record<string, unknown>, index: number): Clip {
  const durationSeconds = (raw.duration_seconds as number) || (raw.duration as number) || 0;
  return {
    id: String(raw.id),
    title: (raw.title as string) || 'Untitled Clip',
    author: {
      name: (raw.creator_name as string) || (raw.user_name as string) || 'Anonymous',
      avatar: (raw.creator_avatar as string) || (raw.user_avatar as string) || '',
      username: (raw.creator_username as string) || (raw.user_username as string) || 'user',
    },
    thumbnailGradient: GRADIENT_LIST[index % GRADIENT_LIST.length],
    duration: formatDuration(durationSeconds),
    views: (raw.view_count as number) || (raw.views as number) || 0,
    likes: (raw.like_count as number) || (raw.likes as number) || 0,
    comments: (raw.comment_count as number) || (raw.comments as number) || 0,
    tags: (raw.tags as string[]) || [],
    category: (raw.subject as string) || (raw.topic as string) || (raw.category as string) || 'General',
    isLiked: (raw.is_liked as boolean) || false,
    isBookmarked: (raw.is_saved as boolean) || (raw.is_bookmarked as boolean) || false,
    createdAt: (raw.created_at as string) || new Date().toISOString(),
  };
}

const tabs = ['For You', 'Following', 'Trending'];

function ClipGridCard({ clip, onClick, onLike }: { clip: Clip; onClick: () => void; onLike?: (clipId: string) => void }) {
  const [liked, setLiked] = useState(clip.isLiked);

  return (
    <motion.div
      whileHover={{ y: -4 }}
      className="group cursor-pointer overflow-hidden rounded-2xl border border-white/5 bg-white/5 backdrop-blur-sm"
      onClick={onClick}
    >
      <div className={`relative aspect-[9/16] bg-gradient-to-br ${clip.thumbnailGradient}`}>
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

function ClipFullscreen({ clip, onClose, onLike, onSave, onView }: { clip: Clip; onClose: () => void; onLike?: (clipId: string) => void; onSave?: (clipId: string) => void; onView?: (clipId: string) => void }) {
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
        <div className={`absolute inset-0 bg-gradient-to-br ${clip.thumbnailGradient} opacity-80`} />
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="rounded-full bg-black/20 p-6 backdrop-blur-sm">
            <Play className="h-16 w-16 text-white/80" fill="white" />
          </div>
        </div>

        <button
          onClick={onClose}
          className="absolute left-4 top-4 z-10 rounded-full bg-black/30 px-3 py-1.5 text-sm text-white backdrop-blur-sm"
        >
          ← Back
        </button>

        <div className="absolute bottom-0 left-0 right-16 p-4">
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
            className={`mt-1 text-sm text-white/70 ${expanded ? '' : 'line-clamp-2'}`}
            onClick={() => setExpanded(!expanded)}
          >
            Learn {clip.category.toLowerCase()} with this quick tip! {clip.tags.map((t) => `#${t}`).join(' ')}
          </p>
        </div>

        <div className="absolute bottom-4 right-3 flex flex-col items-center gap-5">
          <button onClick={() => { setLiked(!liked); onLike?.(clip.id); }} className="flex flex-col items-center gap-1">
            <motion.div whileTap={{ scale: 1.3 }}>
              <Heart
                className={`h-7 w-7 ${liked ? 'text-red-500' : 'text-white'}`}
                fill={liked ? 'currentColor' : 'none'}
              />
            </motion.div>
            <span className="text-xs text-white">{formatNumber(liked ? clip.likes + 1 : clip.likes)}</span>
          </button>
          <button className="flex flex-col items-center gap-1">
            <MessageCircle className="h-7 w-7 text-white" />
            <span className="text-xs text-white">{formatNumber(clip.comments)}</span>
          </button>
          <button className="flex flex-col items-center gap-1">
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

        <div className="absolute bottom-0 left-0 right-0 h-1 bg-white/20">
          <motion.div
            className="h-full bg-white"
            initial={{ width: '0%' }}
            animate={{ width: '100%' }}
            transition={{ duration: 15, ease: 'linear' }}
          />
        </div>
      </div>
    </motion.div>
  );
}

export default function ClipsPage() {
  const [activeTab, setActiveTab] = useState('For You');
  const [viewMode, setViewMode] = useState<'grid' | 'feed'>('grid');
  const [selectedClip, setSelectedClip] = useState<Clip | null>(null);

  const { data: clipsData, isLoading, error } = useApi(() => api.clips.discover(), []);
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
          <button className="flex items-center gap-2 rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple px-4 py-2.5 text-sm font-medium text-white shadow-lg shadow-lyo-500/20 transition hover:shadow-lyo-500/40">
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
                <div className={`relative h-full rounded-2xl bg-gradient-to-br ${clip.thumbnailGradient}`}>
                  <div className="absolute inset-0 flex items-center justify-center">
                    <Play className="h-16 w-16 text-white/50" fill="white" />
                  </div>
                  <div className="absolute bottom-4 left-4 right-16">
                    <p className="text-sm font-semibold text-white">{clip.author.name}</p>
                    <p className="mt-1 text-sm text-white">{clip.title}</p>
                    <p className="mt-1 text-xs text-white/60">{clip.tags.map((t) => `#${t}`).join(' ')}</p>
                  </div>
                  <div className="absolute bottom-4 right-3 flex flex-col gap-4">
                    <button className="flex flex-col items-center gap-0.5">
                      <Heart className="h-6 w-6 text-white" />
                      <span className="text-[10px] text-white">{formatNumber(clip.likes)}</span>
                    </button>
                    <button className="flex flex-col items-center gap-0.5">
                      <MessageCircle className="h-6 w-6 text-white" />
                      <span className="text-[10px] text-white">{formatNumber(clip.comments)}</span>
                    </button>
                    <button className="flex flex-col items-center gap-0.5">
                      <Share2 className="h-6 w-6 text-white" />
                    </button>
                    <button className="flex flex-col items-center gap-0.5">
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
          <ClipFullscreen clip={selectedClip} onClose={() => setSelectedClip(null)} onLike={handleLike} onSave={handleSave} onView={handleView} />
        )}
      </AnimatePresence>
    </div>
  );
}
