'use client';

import { useState, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import {
  ArrowLeft,
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
  Eye,
  ExternalLink,
  Loader2,
} from 'lucide-react';
import { cn, formatTimeAgo, formatNumber } from '@/lib/utils';
import CommentThread from '@/components/community/CommentThread';
import { useApi } from '@/hooks/use-api';
import { api, adaptUser } from '@/lib/api';
import type { CommunityPost, Comment, User } from '@/types';

// ============================================================
// Helpers: map backend → frontend types
// ============================================================

function mapBackendPost(raw: Record<string, unknown>): CommunityPost {
  const rawUser = (raw.user as Record<string, unknown>) || {};
  const author: User = rawUser.id
    ? adaptUser(rawUser)
    : {
        id: String(raw.user_id ?? ''),
        email: '',
        displayName: 'Unknown User',
        username: 'unknown',
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
        createdAt: (raw.created_at as string) || new Date().toISOString(),
        isPremium: false,
      };

  return {
    id: String(raw.id ?? ''),
    author,
    type: (raw.type as CommunityPost['type']) || 'post',
    title: (raw.title as string) || '',
    content: (raw.content as string) || '',
    images: (raw.media_urls as string[]) || (raw.images as string[]) || [],
    tags: (raw.tags as string[]) || [],
    category: (raw.category as string) || 'General',
    likes: (raw.like_count as number) ?? (raw.likes as number) ?? 0,
    comments: (raw.comment_count as number) ?? (raw.comments as number) ?? 0,
    views: (raw.view_count as number) ?? (raw.views as number) ?? 0,
    isLiked: (raw.is_liked as boolean) ?? false,
    isBookmarked: (raw.is_bookmarked as boolean) ?? false,
    isPinned: (raw.is_pinned as boolean) ?? false,
    createdAt: (raw.created_at as string) || new Date().toISOString(),
  };
}

function mapBackendComment(raw: Record<string, unknown>): Comment {
  const rawUser = (raw.user as Record<string, unknown>) || {};
  const author: User = rawUser.id
    ? adaptUser(rawUser)
    : {
        id: String(raw.user_id ?? ''),
        email: '',
        displayName: 'Unknown',
        username: 'unknown',
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
      };

  const rawReplies = (raw.replies as Record<string, unknown>[]) || [];

  return {
    id: String(raw.id ?? ''),
    author,
    content: (raw.content as string) || '',
    likes: (raw.like_count as number) ?? (raw.likes as number) ?? 0,
    isLiked: (raw.is_liked as boolean) ?? false,
    createdAt: (raw.created_at as string) || new Date().toISOString(),
    replies: rawReplies.map(mapBackendComment),
  };
}

// ============================================================
// Post type config
// ============================================================
const POST_TYPE_CONFIG = {
  post: { label: 'Post', icon: FileText, color: 'bg-blue-500/20 text-blue-400' },
  question: { label: 'Question', icon: HelpCircle, color: 'bg-yellow-500/20 text-yellow-400' },
  event: { label: 'Event', icon: Calendar, color: 'bg-green-500/20 text-green-400' },
  poll: { label: 'Poll', icon: BarChart2, color: 'bg-purple-500/20 text-purple-400' },
  course_share: { label: 'Course', icon: BookOpen, color: 'bg-cyan-500/20 text-cyan-400' },
  achievement: { label: 'Achievement', icon: Trophy, color: 'bg-amber-500/20 text-amber-400' },
};

const ROLE_BADGE: Record<string, string> = {
  student: 'bg-blue-500/20 text-blue-400',
  creator: 'bg-purple-500/20 text-purple-400',
  mentor: 'bg-amber-500/20 text-amber-400',
  admin: 'bg-red-500/20 text-red-400',
};

// ============================================================
// Page
// ============================================================
export default function PostDetailPage() {
  const params = useParams();
  const router = useRouter();
  const postId = params.postId as string;

  // ── Fetch post from API ──
  const {
    data: rawPost,
    isLoading: postLoading,
    error: postError,
  } = useApi(
    () => api.feed.get(postId),
    [postId]
  );

  const post: CommunityPost | null = rawPost ? mapBackendPost(rawPost) : null;

  // Extract comments from the backend response (may be nested in the post response)
  const backendComments = rawPost
    ? ((rawPost.comments_list as Record<string, unknown>[]) || (rawPost.comments_data as Record<string, unknown>[]) || [])
    : [];
  const mappedComments: Comment[] = backendComments.map(mapBackendComment);

  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [isBookmarked, setIsBookmarked] = useState(false);
  const [comments, setComments] = useState<Comment[]>([]);
  const [initialized, setInitialized] = useState(false);

  // Sync state from API response when loaded
  if (post && !initialized) {
    setIsLiked(post.isLiked ?? false);
    setLikeCount(post.likes);
    setIsBookmarked(post.isBookmarked ?? false);
    setComments(mappedComments);
    setInitialized(true);
  }

  // ── Like handler ──
  const handleLike = useCallback(async () => {
    const wasLiked = isLiked;
    setIsLiked(!wasLiked);
    setLikeCount((c) => wasLiked ? c - 1 : c + 1);
    try {
      if (wasLiked) {
        await api.feed.unlike(postId);
      } else {
        await api.feed.like(postId);
      }
    } catch {
      // revert on failure
      setIsLiked(wasLiked);
      setLikeCount((c) => wasLiked ? c + 1 : c - 1);
    }
  }, [isLiked, postId]);

  // ── Comment handler ──
  const handleAddComment = useCallback(async (content: string) => {
    const tempComment: Comment = {
      id: `c_${Date.now()}`,
      author: {
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

    try {
      const result = await api.feed.comment(postId, content);
      // Replace temp comment with real one if result is available
      if (result && typeof result === 'object' && (result as Record<string, unknown>).id) {
        const real = mapBackendComment(result as Record<string, unknown>);
        setComments((prev) => prev.map((c) => (c.id === tempComment.id ? real : c)));
      }
    } catch (err) {
      console.error('Failed to post comment:', err);
    }
  }, [postId]);

  const handleReply = (commentId: string, content: string) => {
    const reply: Comment = {
      id: `r_${Date.now()}`,
      author: {
        id: 'me', email: '', displayName: 'You', username: 'me',
        avatar: '', bio: '', role: 'student', interests: [], learningGoals: [],
        streak: 0, xp: 0, level: 1, coursesCompleted: 0, followersCount: 0,
        followingCount: 0, createdAt: new Date().toISOString(), isPremium: false,
      },
      content,
      likes: 0,
      createdAt: new Date().toISOString(),
    };
    setComments((prev) =>
      prev.map((c) =>
        c.id === commentId
          ? { ...c, replies: [...(c.replies ?? []), reply] }
          : c
      )
    );
  };

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

  const typeConfig = POST_TYPE_CONFIG[post.type] ?? POST_TYPE_CONFIG.post;
  const TypeIcon = typeConfig.icon;

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
              {/* Pinned */}
              {post.isPinned && (
                <div className="flex items-center gap-1.5 text-xs text-amber-400 font-medium mb-3">
                  <span className="w-1.5 h-1.5 rounded-full bg-amber-400" />
                  Pinned Post
                </div>
              )}

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
                    <span className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full bg-green-400 border-2 border-[#111118]" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-white">{post.author.displayName}</span>
                      <span className={cn('px-2 py-0.5 rounded-full text-[10px] font-medium capitalize', ROLE_BADGE[post.author.role])}>
                        {post.author.role}
                      </span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-white/40 mt-0.5">
                      <span>{formatTimeAgo(post.createdAt)}</span>
                      <span>·</span>
                      <span className="flex items-center gap-1">
                        <Eye className="w-3 h-3" />
                        {formatNumber(post.views)} views
                      </span>
                    </div>
                  </div>
                </div>

                <span className={cn('flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium shrink-0', typeConfig.color)}>
                  <TypeIcon className="w-3 h-3" />
                  {typeConfig.label}
                </span>
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
                      className="px-2.5 py-1 rounded-full text-xs text-lyo-400 bg-lyo-500/10 border border-lyo-500/20 hover:bg-lyo-500/20 transition-colors cursor-pointer"
                    >
                      #{tag}
                    </span>
                  ))}
                </div>
              )}

              {/* Action bar */}
              <div className="flex items-center justify-between mt-5 pt-4 border-t border-white/8">
                <div className="flex items-center gap-2">
                  {/* Like */}
                  <motion.button
                    whileTap={{ scale: 0.85 }}
                    onClick={handleLike}
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
                    <span>{comments.length}</span>
                  </div>

                  {/* Share */}
                  <button
                    onClick={() => { navigator.clipboard.writeText(window.location.href); alert('Link copied!'); }}
                    className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium text-white/60 bg-white/5 hover:bg-white/10 border border-white/10 transition-all"
                  >
                    <Share2 className="w-4 h-4" />
                    Share
                  </button>
                </div>

                {/* Bookmark */}
                <motion.button
                  whileTap={{ scale: 0.85 }}
                  onClick={() => setIsBookmarked((v) => !v)}
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
              />
              <div className="border-t border-white/5 p-4">
                <div className="flex gap-3">
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple text-xs font-bold text-white">A</div>
                  <input type="text" placeholder="Write a comment..." className="flex-1 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-gray-500 outline-none focus:border-lyo-500/50" onKeyDown={(e) => { if (e.key === 'Enter' && e.currentTarget.value.trim()) { handleAddComment(e.currentTarget.value); e.currentTarget.value = ''; }}} />
                </div>
              </div>
            </div>
          </motion.div>

          {/* Related posts sidebar */}
          <aside className="hidden lg:block w-64 shrink-0">
            <motion.div
              initial={{ opacity: 0, x: 12 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.2 }}
              className="glass-card p-4 sticky top-6"
            >
              <h3 className="text-sm font-semibold text-white/60 uppercase tracking-wider mb-3">
                Related Posts
              </h3>
              <div className="space-y-3">
                <p className="text-xs text-white/30">Related posts coming soon</p>
              </div>

              <button
                onClick={() => router.push('/community')}
                className="flex items-center justify-center gap-2 w-full mt-3 py-2 rounded-xl text-xs text-lyo-400 hover:text-lyo-300 hover:bg-lyo-500/10 transition-all border border-lyo-500/20"
              >
                <ExternalLink className="w-3 h-3" />
                View all posts
              </button>
            </motion.div>
          </aside>
        </div>
      </div>
    </div>
  );
}
