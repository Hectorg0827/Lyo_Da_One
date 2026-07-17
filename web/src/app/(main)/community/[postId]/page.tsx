'use client';

import { useState, useCallback, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import {
  ArrowLeft,
  Heart,
  MessageCircle,
  Share2,
  Bookmark,
  BookmarkCheck,
  Loader2,
  Send,
} from 'lucide-react';
import { cn, formatTimeAgo, formatNumber } from '@/lib/utils';
import CommentThread from '@/components/community/CommentThread';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import { useAuthStore } from '@/stores/auth-store';
import type { CommunityPost, Comment, User } from '@/types';

// ============================================================
// Helpers: map backend → frontend types
// ============================================================

/** Map a community PostRead (the same store iOS renders) to the view model. */
function mapBackendPost(raw: Record<string, unknown>): CommunityPost {
  const author: User = {
    id: String(raw.author_id ?? ''),
    email: '',
    displayName: (raw.author_name as string) || 'Member',
    username: (raw.author_name as string) || 'member',
    avatar: (raw.author_avatar as string) || '',
    bio: '',
    role: 'student',
    interests: [],
    learningGoals: [],
    streak: 0,
    xp: 0,
    level: (raw.author_level as number) ?? 1,
    coursesCompleted: 0,
    followersCount: 0,
    followingCount: 0,
    createdAt: (raw.created_at as string) || new Date().toISOString(),
    isPremium: false,
  };

  const tags = (raw.tags as string[]) || [];
  const rawType = String(raw.post_type ?? 'text');
  const type: CommunityPost['type'] = rawType === 'question_discussion'
    ? 'question'
    : rawType === 'study_tip' ? 'study_tip' : 'post';
  return {
    id: String(raw.id ?? ''),
    author,
    type,
    title: '',
    content: (raw.content as string) || '',
    images: (raw.media_urls as string[]) || [],
    tags,
    category: tags[0] ?? 'General',
    likes: (raw.like_count as number) ?? 0,
    comments: (raw.comment_count as number) ?? 0,
    views: 0,
    isLiked: (raw.has_liked as boolean) ?? false,
    isBookmarked: (raw.has_bookmarked as boolean) ?? false,
    isPinned: (raw.is_pinned as boolean) ?? false,
    createdAt: (raw.created_at as string) || new Date().toISOString(),
  };
}

function mapBackendComment(raw: Record<string, unknown>): Comment {
  const author: User = {
    id: String(raw.author_id ?? ''),
    email: '',
    displayName: (raw.author_name as string) || 'Member',
    username: (raw.author_name as string) || 'member',
    avatar: (raw.author_avatar as string) || '',
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
  };

  const rawReplies = (raw.replies as Record<string, unknown>[]) || [];

  return {
    id: String(raw.id ?? ''),
    author,
    content: (raw.content as string) || '',
    likes: (raw.like_count as number) ?? 0,
    isLiked: (raw.has_liked as boolean) ?? false,
    createdAt: (raw.created_at as string) || new Date().toISOString(),
    replies: rawReplies.map(mapBackendComment),
  };
}

/** Apply `transform` to the comment with `id` anywhere in the thread. */
function updateCommentTree(list: Comment[], id: string, transform: (c: Comment) => Comment): Comment[] {
  return list.map((comment) => comment.id === id
    ? transform(comment)
    : { ...comment, replies: comment.replies ? updateCommentTree(comment.replies, id, transform) : comment.replies });
}

/** Remove the comment with `id` anywhere in the thread. */
function removeCommentFromTree(list: Comment[], id: string): Comment[] {
  return list
    .filter((comment) => comment.id !== id)
    .map((comment) => ({ ...comment, replies: comment.replies ? removeCommentFromTree(comment.replies, id) : comment.replies }));
}

// ============================================================
// Page
// ============================================================
export default function PostDetailPage() {
  const params = useParams();
  const router = useRouter();
  const postId = params.postId as string;
  const currentUser = useAuthStore((state) => state.user);

  // ── Fetch post from API ──
  const {
    data: rawPost,
    isLoading: postLoading,
    error: postError,
  } = useApi(
    () => api.community.post(postId),
    [postId]
  );

  const post: CommunityPost | null = rawPost ? mapBackendPost(rawPost) : null;

  // Comments come from their own endpoint (same one iOS uses)
  const { data: rawComments } = useApi(
    () => api.community.comments(postId),
    [postId]
  );
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [isBookmarked, setIsBookmarked] = useState(false);
  const [commentCount, setCommentCount] = useState(0);
  const [postActionBusy, setPostActionBusy] = useState(false);
  const [comments, setComments] = useState<Comment[]>([]);
  const [commentText, setCommentText] = useState('');
  const [sendingComment, setSendingComment] = useState(false);
  const [commentError, setCommentError] = useState<string | null>(null);

  useEffect(() => {
    if (!rawPost) return;
    const hydrated = mapBackendPost(rawPost);
    setIsLiked(hydrated.isLiked ?? false);
    setLikeCount(hydrated.likes);
    setIsBookmarked(hydrated.isBookmarked ?? false);
    setCommentCount(hydrated.comments);
  }, [rawPost]);

  useEffect(() => {
    if (rawComments) setComments((rawComments.items ?? []).map(mapBackendComment));
  }, [rawComments]);

  // ── Like handler ──
  const handleLike = useCallback(async () => {
    if (postActionBusy) return;
    const wasLiked = isLiked;
    setPostActionBusy(true);
    setIsLiked(!wasLiked);
    setLikeCount((c) => wasLiked ? c - 1 : c + 1);
    try {
      const result = await api.community.togglePostLike(postId);
      setIsLiked(result.liked);
      setLikeCount(result.like_count);
    } catch {
      // revert on failure
      setIsLiked(wasLiked);
      setLikeCount((c) => wasLiked ? c + 1 : c - 1);
    } finally {
      setPostActionBusy(false);
    }
  }, [isLiked, postActionBusy, postId]);

  const handleBookmark = useCallback(async () => {
    if (postActionBusy) return;
    const wasBookmarked = isBookmarked;
    setPostActionBusy(true);
    setIsBookmarked(!wasBookmarked);
    try {
      const result = await api.community.togglePostBookmark(postId);
      setIsBookmarked(result.bookmarked);
    } catch {
      setIsBookmarked(wasBookmarked);
    } finally {
      setPostActionBusy(false);
    }
  }, [isBookmarked, postActionBusy, postId]);

  // ── Comment like / delete (same backend contract iOS + Android use) ──
  const handleLikeComment = useCallback(async (commentId: string) => {
    const toggle = (comment: Comment): Comment => ({
      ...comment,
      isLiked: !comment.isLiked,
      likes: Math.max(0, comment.likes + (comment.isLiked ? -1 : 1)),
    });
    setComments((prev) => updateCommentTree(prev, commentId, toggle));
    try {
      const result = await api.community.likeComment(postId, commentId);
      setComments((prev) => updateCommentTree(prev, commentId, (comment) => ({
        ...comment, isLiked: result.liked, likes: result.like_count,
      })));
    } catch {
      // revert the optimistic toggle on failure
      setComments((prev) => updateCommentTree(prev, commentId, toggle));
    }
  }, [postId]);

  const handleDeleteComment = useCallback(async (commentId: string) => {
    try {
      await api.community.deleteComment(postId, commentId);
      setComments((prev) => removeCommentFromTree(prev, commentId));
      setCommentCount((count) => Math.max(0, count - 1));
    } catch (err) {
      console.error('Failed to delete comment:', err);
      setCommentError('Unable to delete the comment. Please try again.');
    }
  }, [postId]);

  // ── Comment handler ──
  const handleAddComment = useCallback(async (content: string) => {
    const tempComment: Comment = {
      id: `c_${Date.now()}`,
      author: currentUser ?? {
        id: 'me', email: '', displayName: 'You', username: 'me',
        avatar: '', bio: '', role: 'student', interests: [], learningGoals: [],
        streak: 0, xp: 0, level: 1, coursesCompleted: 0, followersCount: 0,
        followingCount: 0, createdAt: new Date().toISOString(), isPremium: false,
      },
      content,
      likes: 0,
      createdAt: new Date().toISOString(),
      replies: [],
    };
    setComments((prev) => [tempComment, ...prev]);
    setCommentCount((count) => count + 1);

    try {
      const result = await api.community.createComment(postId, content);
      // Replace temp comment with real one if result is available
      if (result && typeof result === 'object' && (result as Record<string, unknown>).id) {
        const real = mapBackendComment(result as Record<string, unknown>);
        setComments((prev) => prev.map((c) => (c.id === tempComment.id ? real : c)));
      }
      return true;
    } catch (err) {
      console.error('Failed to post comment:', err);
      setComments((prev) => prev.filter((comment) => comment.id !== tempComment.id));
      setCommentCount((count) => Math.max(0, count - 1));
      return false;
    }
  }, [postId, currentUser]);

  const submitComment = useCallback(async () => {
    const content = commentText.trim();
    if (!content || sendingComment) return;
    setSendingComment(true);
    setCommentError(null);
    const created = await handleAddComment(content);
    if (created) setCommentText('');
    else setCommentError('Unable to post your comment. Please try again.');
    setSendingComment(false);
  }, [commentText, handleAddComment, sendingComment]);

  const handleShare = useCallback(async () => {
    const url = window.location.href;
    if (navigator.share) await navigator.share({ title: 'LYO Community', text: post?.content, url });
    else await navigator.clipboard.writeText(url);
  }, [post?.content]);

  // Render rich content (bold, bullet-point style)
  const renderContent = (text: string) => {
    return text.split('\n').map((line, i) => {
      if (line.startsWith('**') && line.endsWith('**')) {
        return (
          <p key={i} className="font-semibold text-white mt-4 mb-1 first:mt-0">
            {line.replace(/\*\*/g, '')}
          </p>
        );
      }
      if (line.startsWith('- ')) {
        return (
          <li key={i} className="text-white/70 ml-4 list-disc">
            {line.slice(2)}
          </li>
        );
      }
      if (line.trim() === '') {
        return <br key={i} />;
      }
      return (
        <p key={i} className="text-white/70">
          {line}
        </p>
      );
    });
  };

  // ── Loading state ──
  if (postLoading) {
    return (
      <div className="min-h-screen bg-[#0a0a0f] flex items-center justify-center">
        <Loader2 className="w-8 h-8 text-lyo-400 animate-spin" />
        <span className="ml-3 text-white/50">Loading post...</span>
      </div>
    );
  }

  // ── Error state ──
  if (postError || !post) {
    return (
      <div className="min-h-screen bg-[#0a0a0f] flex flex-col items-center justify-center gap-4">
        <p className="text-red-400">{postError || 'Post not found'}</p>
        <button
          onClick={() => router.back()}
          className="text-sm text-white/60 hover:text-white flex items-center gap-2"
        >
          <ArrowLeft className="w-4 h-4" /> Go back
        </button>
      </div>
    );
  }

  const initials = post.author.displayName
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  return (
    <div className="min-h-screen bg-[#0a0a0f]">
      <div className="max-w-4xl mx-auto px-4 py-6">
        {/* Back button */}
        <motion.button
          initial={{ opacity: 0, x: -8 }}
          animate={{ opacity: 1, x: 0 }}
          onClick={() => router.back()}
          className="flex items-center gap-2 text-sm text-white/60 hover:text-white mb-6 transition-colors group"
        >
          <ArrowLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
          Back to Community
        </motion.button>

        <div className="flex gap-6">
          {/* Main post */}
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3 }}
            className="flex-1 min-w-0"
          >
            {/* Post card */}
            <article className="glass-card p-5 mb-4">
              {/* Header */}
              <div className="flex items-start justify-between gap-3 mb-4">
                <div className="flex items-center gap-3">
                  <div className="relative shrink-0">
                    {post.author.avatar ? (
                      <img
                        src={post.author.avatar}
                        alt={post.author.displayName}
                        className="w-12 h-12 rounded-full object-cover border border-white/10"
                      />
                    ) : (
                      <div className="w-12 h-12 rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple flex items-center justify-center text-white font-bold border border-white/10">
                        {initials}
                      </div>
                    )}
                  </div>
                  <div>
                    <span className="font-semibold text-white">{post.author.displayName}</span>
                    <div className="mt-0.5 text-xs text-white/40">{formatTimeAgo(post.createdAt)}</div>
                  </div>
                </div>
                {post.type !== 'post' && (
                  <span className="shrink-0 rounded-full border border-lyo-500/30 bg-lyo-500/10 px-2.5 py-1 text-xs font-medium text-lyo-300">
                    {post.type === 'question' ? 'Question' : 'Study tip'}
                  </span>
                )}
              </div>

              {/* Title */}
              {post.title && (
                <h1 className="text-xl font-bold text-white mb-4 leading-snug">
                  {post.title}
                </h1>
              )}

              {/* Content */}
              <div className="text-sm leading-relaxed space-y-1 mb-4">
                {renderContent(post.content)}
              </div>

              {/* Images */}
              {post.images && post.images.length > 0 && (
                <div className={cn(
                  'mt-4 gap-3 rounded-xl overflow-hidden grid',
                  post.images.length === 1 ? 'grid-cols-1' : 'grid-cols-2'
                )}>
                  {post.images.map((img, i) => (
                    <div key={i} className={cn(
                      'relative bg-white/5 rounded-xl overflow-hidden',
                      post.images!.length === 1 ? 'max-h-96' : 'h-48'
                    )}>
                      <img src={img} alt="" className="w-full h-full object-cover" />
                    </div>
                  ))}
                </div>
              )}

              {/* Tags */}
              {post.tags.length > 0 && (
                <div className="flex flex-wrap gap-2 mt-4">
                  {post.tags.map((tag) => (
                    <span
                      key={tag}
                      className="rounded-full border border-lyo-500/20 bg-lyo-500/10 px-2.5 py-1 text-xs text-lyo-400"
                    >
                      #{tag}
                    </span>
                  ))}
                </div>
              )}

              {/* Action bar */}
              <div className="mt-5 flex flex-wrap items-center justify-between gap-2 border-t border-white/8 pt-4">
                <div className="flex flex-wrap items-center gap-2">
                  {/* Like */}
                  <motion.button
                    whileTap={{ scale: 0.85 }}
                    onClick={handleLike}
                    disabled={postActionBusy}
                    className={cn(
                      'flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all duration-200',
                      isLiked
                        ? 'text-red-400 bg-red-500/10 hover:bg-red-500/20 border border-red-500/20'
                        : 'text-white/60 bg-white/5 hover:bg-white/10 border border-white/10'
                    )}
                  >
                    <motion.div animate={isLiked ? { scale: [1, 1.4, 1] } : { scale: 1 }}>
                      <Heart className={cn('w-4 h-4', isLiked && 'fill-current')} />
                    </motion.div>
                    <span>{formatNumber(likeCount)}</span>
                  </motion.button>

                  {/* Comment count */}
                  <div className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium text-white/60 bg-white/5 border border-white/10">
                    <MessageCircle className="w-4 h-4" />
                    <span>{commentCount}</span>
                  </div>

                  {/* Share */}
                  <button
                    onClick={() => { handleShare().catch((error) => { if ((error as DOMException).name !== 'AbortError') console.error(error); }); }}
                    className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium text-white/60 bg-white/5 hover:bg-white/10 border border-white/10 transition-all"
                  >
                    <Share2 className="w-4 h-4" />
                    Share
                  </button>
                </div>

                {/* Bookmark */}
                <motion.button
                  whileTap={{ scale: 0.85 }}
                  onClick={handleBookmark}
                  disabled={postActionBusy}
                  className={cn(
                    'flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all border',
                    isBookmarked
                      ? 'text-lyo-400 bg-lyo-500/10 border-lyo-500/20'
                      : 'text-white/60 bg-white/5 border-white/10 hover:bg-white/10'
                  )}
                >
                  {isBookmarked ? <BookmarkCheck className="w-4 h-4 fill-current" /> : <Bookmark className="w-4 h-4" />}
                  {isBookmarked ? 'Saved' : 'Save'}
                </motion.button>
              </div>
            </article>

            {/* Comment Thread */}
            <div className="glass-card overflow-hidden">
              <CommentThread
                comments={comments}
                currentUserId={currentUser?.id}
                onLike={handleLikeComment}
                onDelete={handleDeleteComment}
              />
              <div className="border-t border-white/5 p-4">
                <form className="flex gap-3" onSubmit={(event) => { event.preventDefault(); submitComment(); }}>
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple text-xs font-bold text-white">You</div>
                  <input value={commentText} onChange={(event) => setCommentText(event.target.value)} disabled={sendingComment} type="text" placeholder="Write a comment..." className="min-w-0 flex-1 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-gray-500 outline-none focus:border-lyo-500/50" />
                  <button type="submit" disabled={!commentText.trim() || sendingComment} aria-label="Post comment" className="rounded-xl bg-lyo-500 p-2.5 text-white disabled:opacity-40">
                    {sendingComment ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                  </button>
                </form>
                {commentError && <p role="alert" className="mt-2 text-sm text-red-400">{commentError}</p>}
              </div>
            </div>
          </motion.div>

        </div>
      </div>
    </div>
  );
}
