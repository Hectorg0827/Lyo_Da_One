'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Heart, MessageCircle, ChevronDown, Send } from 'lucide-react'
import { cn, formatTimeAgo, getInitials } from '@/lib/utils'
import type { Comment } from '@/types'

interface CommentThreadProps {
  comments: Comment[]
  className?: string
}

interface CommentItemProps {
  comment: Comment
  depth?: number
}

function CommentItem({ comment, depth = 0 }: CommentItemProps) {
  const [liked, setLiked] = useState(comment.isLiked ?? false)
  const [likeCount, setLikeCount] = useState(comment.likes)
  const [showReply, setShowReply] = useState(false)
  const [replyText, setReplyText] = useState('')
  const [showReplies, setShowReplies] = useState(false)
  const [localReplies, setLocalReplies] = useState<Comment[]>(comment.replies ?? [])

  const toggleLike = () => {
    setLiked(p => !p)
    setLikeCount(p => (liked ? p - 1 : p + 1))
  }

  const submitReply = () => {
    if (!replyText.trim()) return
    const newReply: Comment = {
      id: `r-${Date.now()}`,
      author: {
        id: 'me',
        email: '',
        displayName: 'You',
        username: 'you',
        avatar: '',
        bio: '',
        role: 'student',
        interests: [],
        learningGoals: [],
        streak: 0,
        xp: 0,
        level: 1,
        coursesCompleted: 0,
        followersCount: 0,
        followingCount: 0,
        createdAt: new Date().toISOString(),
        isPremium: false,
      },
      content: replyText,
      likes: 0,
      isLiked: false,
      createdAt: new Date().toISOString(),
      replies: [],
    }
    setLocalReplies(p => [...p, newReply])
    setReplyText('')
    setShowReply(false)
    setShowReplies(true)
  }

  const hasReplies = localReplies.length > 0
  const INITIAL_SHOW = 2
  const [showAll, setShowAll] = useState(false)
  const visibleReplies = showAll ? localReplies : localReplies.slice(0, INITIAL_SHOW)

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2 }}
      className={cn(depth > 0 && 'ml-10 pl-4 border-l border-white/10')}
    >
      <div className="flex gap-3">
        {/* Avatar */}
        <div className="flex-shrink-0 w-8 h-8 rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple flex items-center justify-center text-xs font-bold text-white">
          {comment.author.avatar ? (
            <img
              src={comment.author.avatar}
              alt={comment.author.displayName}
              className="w-full h-full rounded-full object-cover"
            />
          ) : (
            getInitials(comment.author.displayName)
          )}
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="inline-block px-3 py-2 rounded-xl bg-white/5 border border-white/10">
            <div className="flex items-baseline gap-2 mb-1">
              <span className="text-sm font-semibold text-white">{comment.author.displayName}</span>
              <span className="text-xs text-white/40">{formatTimeAgo(comment.createdAt)}</span>
            </div>
            <p className="text-sm text-white/80 leading-relaxed">{comment.content}</p>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-3 mt-1.5 px-1">
            <button
              onClick={toggleLike}
              className={cn(
                'flex items-center gap-1 text-xs font-medium transition-colors',
                liked ? 'text-red-400' : 'text-white/40 hover:text-white/70'
              )}
            >
              <Heart className={cn('w-3.5 h-3.5', liked && 'fill-current')} />
              {likeCount > 0 && <span>{likeCount}</span>}
            </button>
            <button
              onClick={() => setShowReply(p => !p)}
              className="flex items-center gap-1 text-xs font-medium text-white/40 hover:text-white/70 transition-colors"
            >
              <MessageCircle className="w-3.5 h-3.5" />
              Reply
            </button>
          </div>

          {/* Reply Input */}
          <AnimatePresence>
            {showReply && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="mt-2 flex gap-2"
              >
                <input
                  autoFocus
                  type="text"
                  placeholder="Write a reply..."
                  value={replyText}
                  onChange={e => setReplyText(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && submitReply()}
                  className="flex-1 px-3 py-2 rounded-xl bg-white/5 border border-white/10 text-sm text-white placeholder-white/30 focus:outline-none focus:border-lyo-500/50 focus:ring-1 focus:ring-lyo-500/20 transition-colors"
                />
                <button
                  onClick={submitReply}
                  className="p-2 rounded-xl bg-gradient-to-r from-lyo-500 to-accent-purple text-white hover:opacity-90 transition-opacity"
                >
                  <Send className="w-4 h-4" />
                </button>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>

      {/* Replies */}
      {hasReplies && (
        <div className="mt-2 ml-11">
          {!showReplies ? (
            <button
              onClick={() => setShowReplies(true)}
              className="flex items-center gap-1.5 text-xs text-lyo-400 hover:text-lyo-300 transition-colors mt-1"
            >
              <ChevronDown className="w-3.5 h-3.5" />
              Show {localReplies.length} {localReplies.length === 1 ? 'reply' : 'replies'}
            </button>
          ) : (
            <AnimatePresence>
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="space-y-3"
              >
                {visibleReplies.map(reply => (
                  <CommentItem key={reply.id} comment={reply} depth={depth + 1} />
                ))}
                {!showAll && localReplies.length > INITIAL_SHOW && (
                  <button
                    onClick={() => setShowAll(true)}
                    className="flex items-center gap-1.5 text-xs text-lyo-400 hover:text-lyo-300 transition-colors"
                  >
                    <ChevronDown className="w-3.5 h-3.5" />
                    Show {localReplies.length - INITIAL_SHOW} more replies
                  </button>
                )}
              </motion.div>
            </AnimatePresence>
          )}
        </div>
      )}
    </motion.div>
  )
}

export default function CommentThread({ comments, className }: CommentThreadProps) {
  return (
    <div className={cn('space-y-4', className)}>
      {comments.length === 0 ? (
        <p className="text-center text-sm text-white/40 py-6">No comments yet. Be the first!</p>
      ) : (
        comments.map(comment => (
          <CommentItem key={comment.id} comment={comment} />
        ))
      )}
    </div>
  )
}
