'use client';

import { useEffect, useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Heart,
  MessageCircle,
  Share2,
  Bookmark,
  BookmarkCheck,
  HelpCircle,
  FileText,
  Lightbulb,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import { cn, formatTimeAgo, formatNumber } from '@/lib/utils';
import { api } from '@/lib/api';
import type { CommunityPost } from '@/types';

// ---- Post type config ----
const POST_TYPE_CONFIG = {
  post: { label: 'Post', icon: FileText, color: 'bg-blue-500/20 text-blue-400 border-blue-500/30' },
  question: { label: 'Question', icon: HelpCircle, color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30' },
  study_tip: { label: 'Study tip', icon: Lightbulb, color: 'bg-purple-500/20 text-purple-300 border-purple-500/30' },
};

// ---- Main PostCard ----
interface PostCardProps {
  post: CommunityPost;
  onClick?: () => void;
  className?: string;
}

export default function PostCard({ post, onClick, className }: PostCardProps) {
  const [isLiked, setIsLiked] = useState(post.isLiked ?? false);
  const [likeCount, setLikeCount] = useState(post.likes);
  const [isBookmarked, setIsBookmarked] = useState(post.isBookmarked ?? false);
  const [showShareToast, setShowShareToast] = useState(false);
  const [actionBusy, setActionBusy] = useState<'like' | 'bookmark' | null>(null);
  const [photoIndex, setPhotoIndex] = useState(0);
  const touchStartX = useRef<number | null>(null);

  useEffect(() => {
    setIsLiked(post.isLiked ?? false);
    setLikeCount(post.likes);
    setIsBookmarked(post.isBookmarked ?? false);
  }, [post.isBookmarked, post.isLiked, post.likes]);

  const typeConfig = POST_TYPE_CONFIG[post.type as keyof typeof POST_TYPE_CONFIG] ?? POST_TYPE_CONFIG.post;
  const TypeIcon = typeConfig.icon;

  const handleLike = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (actionBusy) return;
    const wasLiked = isLiked;
    setActionBusy('like');
    setIsLiked(!wasLiked);
    setLikeCount((c) => (wasLiked ? c - 1 : c + 1));
    try {
      const result = await api.community.togglePostLike(post.id);
      setIsLiked(result.liked);
      setLikeCount(result.like_count);
    } catch {
      setIsLiked(wasLiked);
      setLikeCount((c) => (wasLiked ? c + 1 : c - 1));
    } finally {
      setActionBusy(null);
    }
  };

  const handleBookmark = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (actionBusy) return;
    const wasBookmarked = isBookmarked;
    setActionBusy('bookmark');
    setIsBookmarked(!wasBookmarked);
    try {
      const result = await api.community.togglePostBookmark(post.id);
      setIsBookmarked(result.bookmarked);
    } catch {
      setIsBookmarked(wasBookmarked);
    } finally {
      setActionBusy(null);
    }
  };

  const handleShare = async (e: React.MouseEvent) => {
    e.stopPropagation();
    const url = `${window.location.origin}/community/${post.id}`;
    try {
      if (navigator.share) {
        await navigator.share({ title: 'LYO Community', text: post.content, url });
      } else {
        await navigator.clipboard.writeText(url);
        setShowShareToast(true);
        setTimeout(() => setShowShareToast(false), 2000);
      }
    } catch (error) {
      if ((error as DOMException).name !== 'AbortError') console.error('Unable to share post', error);
    }
  };

  return (
    <motion.article
      layout
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, ease: 'easeOut' }}
      onClick={onClick}
      className={cn(
        'glass-card !p-0 overflow-hidden cursor-pointer hover:border-white/15 transition-colors duration-200',
        className
      )}
    >
      {/* Header — iOS CommunityFeedPostCard: 44px letter avatar in an
          indigo tint, 15pt name over a 12pt relative timestamp. */}
      <div className="flex items-start justify-between gap-3 px-4 pt-4 pb-3">
        <div className="flex items-center gap-3">
          {/* Avatar */}
          <div className="relative shrink-0">
            {post.author.avatar ? (
              <img
                src={post.author.avatar}
                alt={post.author.displayName}
                className="w-11 h-11 rounded-full object-cover"
              />
            ) : (
              <div
                className="w-11 h-11 rounded-full flex items-center justify-center text-[17px] font-semibold"
                style={{ backgroundColor: 'rgba(99,102,241,0.2)', color: '#6366f1' }}
              >
                {post.author.displayName.charAt(0).toUpperCase()}
              </div>
            )}
          </div>

          {/* Author info */}
          <div className="flex flex-col gap-[2px]">
            <span className="text-[15px] font-semibold leading-none text-white">
              {post.author.displayName}
            </span>
            <span className="text-xs text-white/50">{formatTimeAgo(post.createdAt)}</span>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {post.type !== 'post' && (
            <span className="flex shrink-0 items-center gap-1 rounded-lg bg-lyo-500/10 px-2 py-1 text-[11px] font-medium text-lyo-300">
              <TypeIcon className="h-3 w-3" />
              {typeConfig.label}
            </span>
          )}
          <button type="button" onClick={handleBookmark} disabled={actionBusy === 'bookmark'}
            aria-label={isBookmarked ? 'Remove saved post' : 'Save post'}
            className={cn('rounded-full p-2 transition-colors hover:bg-white/10', isBookmarked ? 'text-lyo-300' : 'text-white/55')}>
            {isBookmarked ? <BookmarkCheck className="h-[18px] w-[18px]" /> : <Bookmark className="h-[18px] w-[18px]" />}
          </button>
        </div>
      </div>

      {/* Title */}
      {post.title && (
        <h3 className="px-4 text-base font-semibold text-white mb-2 leading-snug">
          {post.title}
        </h3>
      )}

      {/* Content */}
      <div className="px-4 text-[15px] text-white/80 leading-relaxed">
        <p className="whitespace-pre-wrap break-words">{post.content}</p>
      </div>

      {/* Swipeable photo carousel shared by mouse, touch and keyboard users. */}
      {post.images && post.images.length > 0 && (
        <div
          className="relative mt-3 overflow-hidden bg-transparent"
          role="group"
          aria-label={`${post.images.length} post photo${post.images.length > 1 ? 's' : ''}`}
          onClick={(event) => event.stopPropagation()}
          onTouchStart={(event) => { touchStartX.current = event.touches[0]?.clientX ?? null; }}
          onTouchEnd={(event) => {
            if (touchStartX.current === null || post.images!.length < 2) return;
            const delta = (event.changedTouches[0]?.clientX ?? touchStartX.current) - touchStartX.current;
            if (Math.abs(delta) > 45) setPhotoIndex((current) => Math.max(0, Math.min(post.images!.length - 1, current + (delta < 0 ? 1 : -1))));
            touchStartX.current = null;
          }}
        >
          <img src={post.images[Math.min(photoIndex, post.images.length - 1)]} alt={`Post photo ${Math.min(photoIndex + 1, post.images.length)} of ${post.images.length}`} className="block h-auto w-full object-contain" />
          {post.images.length > 1 && <>
            <button type="button" onClick={() => setPhotoIndex((value) => Math.max(0, value - 1))} disabled={photoIndex === 0} aria-label="Previous photo" className="absolute left-2 top-1/2 -translate-y-1/2 rounded-full bg-black/60 p-2 text-white disabled:opacity-30"><ChevronLeft className="h-5 w-5" /></button>
            <button type="button" onClick={() => setPhotoIndex((value) => Math.min(post.images!.length - 1, value + 1))} disabled={photoIndex === post.images.length - 1} aria-label="Next photo" className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full bg-black/60 p-2 text-white disabled:opacity-30"><ChevronRight className="h-5 w-5" /></button>
            <span className="absolute right-3 top-3 rounded-full bg-black/65 px-2.5 py-1 text-xs text-white">{photoIndex + 1}/{post.images.length}</span>
          </>}
        </div>
      )}

      {/* Tags */}
      {post.tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mt-3 px-4">
          {post.tags.map((tag) => (
            <span
              key={tag}
              className="rounded-xl px-2 py-1 text-xs"
              style={{ backgroundColor: 'rgba(99,102,241,0.1)', color: '#6366f1' }}
            >
              #{tag}
            </span>
          ))}
        </div>
      )}

      <div className="mt-3 border-t border-white/10 px-3 pb-2 pt-1">
        <div className="flex items-center gap-1 text-[13px] font-medium text-white/65">
          <motion.button whileTap={{ scale: 0.96 }} type="button" onClick={handleLike}
            disabled={actionBusy === 'like'}
            aria-label={isLiked ? 'Unlike post' : 'Like post'}
            className={cn('flex min-w-0 flex-1 items-center justify-center gap-2 rounded-lg py-2.5 transition-colors hover:bg-white/5', isLiked && 'text-red-400')}>
            <Heart className={cn('h-[18px] w-[18px]', isLiked && 'fill-current')} />
            <span>Like{likeCount > 0 ? ` · ${formatNumber(likeCount)}` : ''}</span>
          </motion.button>
          <button type="button" onClick={(event) => { event.stopPropagation(); onClick?.(); }}
            className="flex min-w-0 flex-1 items-center justify-center gap-2 rounded-lg py-2.5 transition-colors hover:bg-white/5"
            aria-label="Open comments">
            <MessageCircle className="h-[18px] w-[18px]" />
            <span>Comment{post.comments > 0 ? ` · ${formatNumber(post.comments)}` : ''}</span>
          </button>
          <div className="relative flex min-w-0 flex-1">
            <button type="button" onClick={handleShare}
              className="flex w-full items-center justify-center gap-2 rounded-lg py-2.5 transition-colors hover:bg-white/5"
              aria-label="Share post">
              <Share2 className="h-[18px] w-[18px]" />
              <span>Share</span>
            </button>
            <AnimatePresence>
              {showShareToast && (
                <motion.span initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
                  className="pointer-events-none absolute bottom-full left-1/2 -translate-x-1/2 rounded-lg border border-white/10 bg-[#1b1b36] px-3 py-1.5 text-xs text-white whitespace-nowrap">
                  Link copied!
                </motion.span>
              )}
            </AnimatePresence>
          </div>
        </div>
      </div>
    </motion.article>
  );
}
