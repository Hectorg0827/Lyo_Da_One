'use client'

import { motion } from 'framer-motion'
import { cn, formatTimeAgo, getInitials } from '@/lib/utils'
import type { Comment } from '@/types'

function CommentItem({ comment, depth = 0 }: { comment: Comment; depth?: number }) {
  return (
    <motion.article
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      className={cn('flex gap-3', depth > 0 && 'ml-8 border-l border-white/10 pl-4')}
    >
      <div className="flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple text-xs font-bold text-white">
        {comment.author.avatar ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={comment.author.avatar} alt="" className="h-full w-full object-cover" />
        ) : getInitials(comment.author.displayName)}
      </div>
      <div className="min-w-0 flex-1">
        <div className="inline-block max-w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2">
          <div className="mb-1 flex flex-wrap items-baseline gap-2">
            <span className="text-sm font-semibold text-white">{comment.author.displayName}</span>
            <span className="text-xs text-white/40">{formatTimeAgo(comment.createdAt)}</span>
          </div>
          <p className="whitespace-pre-wrap break-words text-sm leading-relaxed text-white/80">{comment.content}</p>
        </div>
        {comment.replies && comment.replies.length > 0 && (
          <div className="mt-3 space-y-3">
            {comment.replies.map((reply) => <CommentItem key={reply.id} comment={reply} depth={depth + 1} />)}
          </div>
        )}
      </div>
    </motion.article>
  )
}

export default function CommentThread({ comments, className }: { comments: Comment[]; className?: string }) {
  return (
    <div className={cn('space-y-4 p-4', className)}>
      {comments.length === 0
        ? <p className="py-6 text-center text-sm text-white/40">No comments yet. Be the first!</p>
        : comments.map((comment) => <CommentItem key={comment.id} comment={comment} />)}
    </div>
  )
}
