'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Heart,
  MessageCircle,
  Share2,
  Bookmark,
  BookmarkCheck,
  BarChart2,
  Calendar,
  HelpCircle,
  BookOpen,
  FileText,
  Trophy,
  ChevronDown,
  ChevronUp,
  CheckCircle2,
} from 'lucide-react';
import { cn, formatTimeAgo, formatNumber } from '@/lib/utils';
import type { CommunityPost, PollOption } from '@/types';

// ---- Post type config ----
const POST_TYPE_CONFIG = {
  post: { label: 'Post', icon: FileText, color: 'bg-blue-500/20 text-blue-400 border-blue-500/30' },
  question: { label: 'Question', icon: HelpCircle, color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30' },
  event: { label: 'Event', icon: Calendar, color: 'bg-green-500/20 text-green-400 border-green-500/30' },
  poll: { label: 'Poll', icon: BarChart2, color: 'bg-purple-500/20 text-purple-400 border-purple-500/30' },
  course_share: { label: 'Course', icon: BookOpen, color: 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30' },
  achievement: { label: 'Achievement', icon: Trophy, color: 'bg-amber-500/20 text-amber-400 border-amber-500/30' },
};

const ROLE_BADGE: Record<string, string> = {
  student: 'bg-blue-500/20 text-blue-400',
  creator: 'bg-purple-500/20 text-purple-400',
  mentor: 'bg-amber-500/20 text-amber-400',
  admin: 'bg-red-500/20 text-red-400',
};

// ---- Poll Component ----
interface PollProps {
  poll: NonNullable<CommunityPost['poll']>;
  onVote?: (optionId: string) => void;
}

function PollComponent({ poll, onVote }: PollProps) {
  const [voted, setVoted] = useState<string | null>(
    poll.options.find((o) => o.isSelected)?.id ?? null
  );
  const [options, setOptions] = useState<PollOption[]>(poll.options);
  const [total, setTotal] = useState(poll.totalVotes);

  const hasVoted = voted !== null;

  const handleVote = (optionId: string) => {
    if (hasVoted) return;
    setVoted(optionId);
    setOptions((prev) =>
      prev.map((o) =>
        o.id === optionId ? { ...o, votes: o.votes + 1, isSelected: true } : o
      )
    );
    setTotal((t) => t + 1);
    onVote?.(optionId);
  };

  const getPercent = (votes: number) =>
    total > 0 ? Math.round((votes / total) * 100) : 0;

  return (
    <div className="mt-3 space-y-2">
      {options.map((option) => {
        const pct = hasVoted ? getPercent(option.votes) : 0;
        const isWinner =
          hasVoted && option.votes === Math.max(...options.map((o) => o.votes));

        return (
          <button
            key={option.id}
            onClick={() => handleVote(option.id)}
            disabled={hasVoted}
            className={cn(
              'relative w-full text-left rounded-xl border overflow-hidden transition-all duration-200',
              hasVoted
                ? 'cursor-default'
                : 'hover:border-lyo-500/50 hover:bg-white/5 cursor-pointer active:scale-[0.99]',
              option.id === voted
                ? 'border-lyo-500/60 bg-lyo-500/10'
                : 'border-white/10 bg-white/[0.03]'
            )}
          >
            {hasVoted && (
              <motion.div
                initial={{ width: 0 }}
                animate={{ width: `${pct}%` }}
                transition={{ duration: 0.6, ease: 'easeOut', delay: 0.1 }}
                className={cn(
                  'absolute inset-0 rounded-xl opacity-20',
                  isWinner ? 'bg-lyo-500' : 'bg-white/20'
                )}
              />
            )}
            <div className="relative flex items-center justify-between px-3 py-2.5">
              <div className="flex items-center gap-2">
                {option.id === voted && (
                  <CheckCircle2 className="w-4 h-4 text-lyo-400 shrink-0" />
                )}
                <span
                  className={cn(
                    'text-sm font-medium',
                    option.id === voted ? 'text-white' : 'text-white/80'
                  )}
                >
                  {option.text}
                </span>
              </div>
              {hasVoted && (
                <span
                  className={cn(
                    'text-xs font-bold ml-2 shrink-0',
                    isWinner ? 'text-lyo-400' : 'text-white/50'
                  )}
                >
                  {pct}%
                </span>
              )}
            </div>
          </button>
        );
      })}
      <p className="text-xs text-white/40 mt-1">{formatNumber(total)} votes</p>
    </div>
  );
}

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
  const [expanded, setExpanded] = useState(false);
  const [showShareToast, setShowShareToast] = useState(false);

  const typeConfig =
    POST_TYPE_CONFIG[post.type] ?? POST_TYPE_CONFIG.post;
  const TypeIcon = typeConfig.icon;

  const CONTENT_LIMIT = 200;
  const isLong = post.content.length > CONTENT_LIMIT;
  const displayContent =
    !expanded && isLong ? post.content.slice(0, CONTENT_LIMIT) + '…' : post.content;

  const handleLike = (e: React.MouseEvent) => {
    e.stopPropagation();
    setIsLiked((v) => !v);
    setLikeCount((c) => (isLiked ? c - 1 : c + 1));
  };

  const handleBookmark = (e: React.MouseEvent) => {
    e.stopPropagation();
    setIsBookmarked((v) => !v);
  };

  const handleShare = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowShareToast(true);
    setTimeout(() => setShowShareToast(false), 2000);
  };

  const initials = post.author.displayName
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

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
      {/* Pinned badge */}
      {post.isPinned && (
        <div className="flex items-center gap-1.5 text-xs text-amber-400 font-medium mb-3">
          <span className="w-1.5 h-1.5 rounded-full bg-amber-400" />
          Pinned
        </div>
      )}

      {/* Header */}
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="flex items-center gap-2.5">
          {/* Avatar */}
          <div className="relative shrink-0">
            {post.author.avatar ? (
              <img
                src={post.author.avatar}
                alt={post.author.displayName}
                className="w-10 h-10 rounded-full object-cover border border-white/10"
              />
            ) : (
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple flex items-center justify-center text-white text-sm font-bold border border-white/10">
                {initials}
              </div>
            )}
            <span className="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full bg-green-400 border-2 border-[#111118]" />
          </div>

          {/* Author info */}
          <div>
            <div className="flex items-center gap-1.5">
              <span className="text-sm font-semibold text-white leading-none">
                {post.author.displayName}
              </span>
              <span
                className={cn(
                  'px-1.5 py-0.5 rounded-full text-[10px] font-medium capitalize',
                  ROLE_BADGE[post.author.role] ?? ROLE_BADGE.student
                )}
              >
                {post.author.role}
              </span>
            </div>
            <span className="text-xs text-white/40 mt-0.5 block">
              {formatTimeAgo(post.createdAt)}
            </span>
          </div>
        </div>

        {/* Post type badge */}
        <span
          className={cn(
            'flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border shrink-0',
            typeConfig.color
          )}
        >
          <TypeIcon className="w-3 h-3" />
          {typeConfig.label}
        </span>
      </div>

      {/* Title */}
      {post.title && (
        <h3 className="text-base font-semibold text-white mb-2 leading-snug">
          {post.title}
        </h3>
      )}

      {/* Content */}
      <div className="text-sm text-white/70 leading-relaxed">
        <p>{displayContent}</p>
        {isLong && (
          <button
            onClick={(e) => {
              e.stopPropagation();
              setExpanded((v) => !v);
            }}
            className="flex items-center gap-1 text-lyo-400 text-xs font-medium mt-1 hover:text-lyo-300 transition-colors"
          >
            {expanded ? (
              <>
                Less <ChevronUp className="w-3 h-3" />
              </>
            ) : (
              <>
                Read more <ChevronDown className="w-3 h-3" />
              </>
            )}
          </button>
        )}
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

      {/* Poll */}
      {post.poll && (
        <div onClick={(e) => e.stopPropagation()}>
          <PollComponent poll={post.poll} />
        </div>
      )}

      {/* Tags */}
      {post.tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mt-3">
          {post.tags.map((tag) => (
            <span
              key={tag}
              className="px-2 py-0.5 rounded-full text-xs text-lyo-400 bg-lyo-500/10 border border-lyo-500/20 hover:bg-lyo-500/20 transition-colors cursor-pointer"
            >
              #{tag}
            </span>
          ))}
        </div>
      )}

      {/* Action bar */}
      <div className="flex items-center justify-between mt-4 pt-3 border-t border-white/[0.06]">
        <div className="flex items-center gap-1">
          {/* Like */}
          <motion.button
            whileTap={{ scale: 0.85 }}
            onClick={handleLike}
            className={cn(
              'flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-sm font-medium transition-all duration-200',
              isLiked
                ? 'text-red-400 bg-red-500/10 hover:bg-red-500/20'
                : 'text-white/50 hover:text-white/80 hover:bg-white/5'
            )}
          >
            <motion.div
              animate={isLiked ? { scale: [1, 1.4, 1] } : { scale: 1 }}
              transition={{ duration: 0.3 }}
            >
              <Heart
                className={cn('w-4 h-4 transition-all', isLiked && 'fill-current')}
              />
            </motion.div>
            <span>{formatNumber(likeCount)}</span>
          </motion.button>

          {/* Comment */}
          <button
            onClick={(e) => {
              e.stopPropagation();
              onClick?.();
            }}
            className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-sm font-medium text-white/50 hover:text-white/80 hover:bg-white/5 transition-all duration-200"
          >
            <MessageCircle className="w-4 h-4" />
            <span>{formatNumber(post.comments)}</span>
          </button>

          {/* Share */}
          <div className="relative">
            <button
              onClick={handleShare}
              className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-sm font-medium text-white/50 hover:text-white/80 hover:bg-white/5 transition-all duration-200"
            >
              <Share2 className="w-4 h-4" />
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

        {/* Bookmark */}
        <motion.button
          whileTap={{ scale: 0.85 }}
          onClick={handleBookmark}
          className={cn(
            'flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-sm font-medium transition-all duration-200',
            isBookmarked
              ? 'text-lyo-400 bg-lyo-500/10 hover:bg-lyo-500/20'
              : 'text-white/50 hover:text-white/80 hover:bg-white/5'
          )}
        >
          {isBookmarked ? (
            <BookmarkCheck className="w-4 h-4 fill-current" />
          ) : (
            <Bookmark className="w-4 h-4" />
          )}
        </motion.button>
      </div>
    </motion.article>
  );
}
