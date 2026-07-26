'use client';

import { useEffect, useState } from 'react';
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
        'glass-card p-4 cursor-pointer hover:border-white/15 transition-all duration-200 hover:shadow-lg hover:shadow-lyo-500/5',
        className
      )}
    >
      {/* Header — iOS CommunityFeedPostCard: 44px letter avatar in an
          indigo tint, 15pt name over a 12pt relative timestamp. */}
      <div className="flex items-start justify-between gap-3 mb-3">
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

        {/* Post type badge */}
        {post.type !== 'post' && (
          <span
            className="flex shrink-0 items-center gap-1 rounded-xl px-2 py-1 text-[11px] font-medium"
            style={{ backgroundColor: 'rgba(99,102,241,0.1)', color: '#a78bfa' }}
          >
            <TypeIcon className="h-3 w-3" />
            {typeConfig.label}
          </span>
        )}
      </div>

      {/* Title */}
      {post.title && (
        <h3 className="text-base font-semibold text-white mb-2 leading-snug">
          {post.title}
        </h3>
      )}

      {/* Content */}
      <div className="text-sm text-white/70 leading-relaxed">
        <p className="whitespace-pre-wrap break-words">{post.content}</p>
      </div>

      {/* Images */}
      {post.images && post.images.length > 0 && (
        <div
          className={cn(
            'mt-3 gap-2 rounded-xl overflow-hidden grid',
            post.images.length === 1 ? 'grid-cols-1' : 'grid-cols-2'
          )}
        >
          {post.images.slice(0, 4).map((img, i) => (
            <div
              key={i}
              className={cn(
                'relative bg-white/5 rounded-lg overflow-hidden',
                post.images!.length === 1 ? 'h-48' : 'h-32',
                post.images!.length === 3 && i === 0 ? 'col-span-2' : ''
              )}
            >
              <img src={img} alt="" className="w-full h-full object-cover" />
              {post.images!.length > 4 && i === 3 && (
                <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
                  <span className="text-white font-bold text-lg">
                    +{post.images!.length - 4}
                  </span>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Tags */}
      {post.tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mt-3">
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

      {/* Action bar — iOS uses four equal-width cells at 15pt. Only the
          glyph takes the active tint; counts stay secondary throughout. */}
      <div className="flex items-stretch mt-4 pt-1 border-t border-white/[0.06] text-[15px]">
        {/* Like */}
        <motion.button
          whileTap={{ scale: 0.9 }}
          onClick={handleLike}
          disabled={actionBusy === 'like'}
          aria-label={isLiked ? 'Unlike post' : 'Like post'}
          className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-lg text-white/50 hover:bg-white/5 transition-colors duration-200"
        >
          <motion.span
            animate={isLiked ? { scale: [1, 1.4, 1] } : { scale: 1 }}
            transition={{ duration: 0.3 }}
            className="flex"
          >
            <Heart
              className={cn('w-[18px] h-[18px]', isLiked && 'fill-current text-red-500')}
            />
          </motion.span>
          <span>{formatNumber(likeCount)}</span>
        </motion.button>

        {/* Comment */}
        <button
          onClick={(e) => {
            e.stopPropagation();
            onClick?.();
          }}
          aria-label="View comments"
          className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-lg text-white/50 hover:bg-white/5 transition-colors duration-200"
        >
          <MessageCircle className="w-[18px] h-[18px]" />
          <span>{formatNumber(post.comments)}</span>
        </button>

        {/* Bookmark — no count on iOS */}
        <motion.button
          whileTap={{ scale: 0.9 }}
          onClick={handleBookmark}
          disabled={actionBusy === 'bookmark'}
          aria-label={isBookmarked ? 'Remove bookmark' : 'Bookmark post'}
          className={cn(
            'flex-1 flex items-center justify-center py-2 rounded-lg hover:bg-white/5 transition-colors duration-200',
            isBookmarked ? 'text-lyo-500' : 'text-white/50'
          )}
        >
          {isBookmarked ? (
            <BookmarkCheck className="w-[18px] h-[18px] fill-current" />
          ) : (
            <Bookmark className="w-[18px] h-[18px]" />
          )}
        </motion.button>

        {/* Share — no count on iOS */}
        <div className="flex-1 relative flex">
          <button
            onClick={handleShare}
            aria-label="Share post"
            className="flex-1 flex items-center justify-center py-2 rounded-lg text-white/50 hover:bg-white/5 transition-colors duration-200"
          >
            <Share2 className="w-[18px] h-[18px]" />
          </button>
          <AnimatePresence>
            {showShareToast && (
              <motion.div
                initial={{ opacity: 0, y: 4, scale: 0.9 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, scale: 0.9 }}
                className="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-2 py-1 bg-white/10 backdrop-blur-md rounded-lg text-xs text-white whitespace-nowrap border border-white/10 pointer-events-none"
              >
                Link copied!
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </motion.article>
  );
}
