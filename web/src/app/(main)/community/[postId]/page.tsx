'use client';

import { useState } from 'react';
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
} from 'lucide-react';
import { cn, formatTimeAgo, formatNumber } from '@/lib/utils';
import CommentThread from '@/components/community/CommentThread';
import type { CommunityPost, Comment, User } from '@/types';

// ============================================================
// Mock Data (mirrored from community page)
// ============================================================

const MOCK_USERS: User[] = [
  {
    id: 'u1', email: 'alex@lyo.app', displayName: 'Alex Rivera', username: 'alexrivera',
    avatar: '', bio: '', role: 'student', interests: [], learningGoals: [],
    streak: 12, xp: 4850, level: 15, coursesCompleted: 23, followersCount: 342,
    followingCount: 128, createdAt: '2024-06-01T00:00:00Z', isPremium: false,
  },
  {
    id: 'u2', email: 'sarah@lyo.app', displayName: 'Sarah Chen', username: 'sarahchen',
    avatar: '', bio: '', role: 'mentor', interests: [], learningGoals: [],
    streak: 45, xp: 18200, level: 42, coursesCompleted: 87, followersCount: 2340,
    followingCount: 89, createdAt: '2023-01-15T00:00:00Z', isPremium: true,
  },
  {
    id: 'u3', email: 'mike@lyo.app', displayName: 'Marcus Johnson', username: 'marcusj',
    avatar: '', bio: '', role: 'creator', interests: [], learningGoals: [],
    streak: 30, xp: 9100, level: 28, coursesCompleted: 41, followersCount: 1120,
    followingCount: 203, createdAt: '2023-06-20T00:00:00Z', isPremium: true,
  },
  {
    id: 'u4', email: 'priya@lyo.app', displayName: 'Priya Patel', username: 'priyap',
    avatar: '', bio: '', role: 'student', interests: [], learningGoals: [],
    streak: 8, xp: 2300, level: 9, coursesCompleted: 12, followersCount: 89,
    followingCount: 245, createdAt: '2024-03-10T00:00:00Z', isPremium: false,
  },
  {
    id: 'u5', email: 'james@lyo.app', displayName: 'James Okafor', username: 'jamesokafor',
    avatar: '', bio: '', role: 'mentor', interests: [], learningGoals: [],
    streak: 60, xp: 24500, level: 55, coursesCompleted: 130, followersCount: 5670,
    followingCount: 34, createdAt: '2022-11-01T00:00:00Z', isPremium: true,
  },
];

const MOCK_POSTS: Record<string, CommunityPost> = {
  p1: {
    id: 'p1',
    author: MOCK_USERS[1],
    type: 'post',
    title: 'How I mastered Neural Networks in 30 days',
    content: `After struggling with backpropagation for weeks, I finally cracked it! Here's my complete approach and what made everything click.

**Phase 1: Visual Understanding (Week 1)**
I started with 3Blue1Brown's "Neural Networks" series. Grant's visual explanations are unmatched — you actually *see* how information flows through the network. The key insight was visualizing gradient flow as water flowing downhill to find the lowest point.

**Phase 2: Code from Scratch (Week 2)**
I implemented a simple feedforward neural network from scratch in NumPy. No PyTorch, no TensorFlow — just numpy arrays and math. This was painful but absolutely worth it. When you write the forward pass and backprop by hand, the math becomes concrete.

Here's what my training loop looked like in pseudocode:
1. Forward pass: compute activations layer by layer
2. Compute loss (MSE or cross-entropy)
3. Backward pass: compute gradients using chain rule
4. Update weights: W -= learning_rate * gradients

**Phase 3: Modern Frameworks (Week 3-4)**
Armed with real understanding, I moved to PyTorch. Now the autograd system makes perfect sense — it's just doing what I wrote manually, but differentiably and efficiently on GPU.

I implemented: CNNs for image classification, RNNs for sequence data, and a simple Transformer. The results? I can now build and train custom architectures confidently.

**Resources that actually helped:**
- 3Blue1Brown "Essence of Neural Networks" (start here)
- Andrej Karpathy's micrograd (learn autograd from scratch)
- fast.ai Practical Deep Learning (top-down practical approach)
- Michael Nielsen's "Neural Networks and Deep Learning" (free online, rigorous)

Happy to share my Jupyter notebooks if anyone wants!`,
    images: [],
    tags: ['deeplearning', 'neuralnetworks', 'python', 'ai'],
    category: 'Artificial Intelligence',
    likes: 284,
    comments: 47,
    views: 1820,
    isLiked: false,
    isBookmarked: false,
    isPinned: true,
    createdAt: new Date(Date.now() - 2 * 3600000).toISOString(),
  },
};

const MOCK_COMMENTS: Comment[] = [
  {
    id: 'c1',
    author: MOCK_USERS[4],
    content: 'This is exactly what I needed! The tip about implementing backprop from scratch in NumPy before using PyTorch makes so much sense. I always jumped straight to frameworks and never truly understood what was happening under the hood.',
    likes: 34,
    isLiked: false,
    createdAt: new Date(Date.now() - 1.5 * 3600000).toISOString(),
    replies: [
      {
        id: 'c1r1',
        author: MOCK_USERS[1],
        content: 'Exactly! The struggle of implementing it yourself is the learning. I spent 2 full days on backprop alone and those were the most educational 2 days of my ML journey.',
        likes: 18,
        isLiked: true,
        createdAt: new Date(Date.now() - 1 * 3600000).toISOString(),
      },
      {
        id: 'c1r2',
        author: MOCK_USERS[2],
        content: "Karpathy's micrograd tutorial is also great for this — he builds a full autograd engine in ~150 lines of Python.",
        likes: 22,
        createdAt: new Date(Date.now() - 45 * 60000).toISOString(),
      },
    ],
  },
  {
    id: 'c2',
    author: MOCK_USERS[0],
    content: 'Could you share which specific episodes of 3B1B helped most? The whole series or just certain videos? Also, how much math background did you have going into this?',
    likes: 12,
    createdAt: new Date(Date.now() - 1.2 * 3600000).toISOString(),
    replies: [
      {
        id: 'c2r1',
        author: MOCK_USERS[1],
        content: 'The whole series is great, but episodes 1-4 are essential (Chapter 1: What is a neural network, and especially Chapter 4: Backpropagation calculus). Math background: I had Calc 1 and basic linear algebra. Honestly that\'s enough to start.',
        likes: 8,
        createdAt: new Date(Date.now() - 50 * 60000).toISOString(),
      },
    ],
  },
  {
    id: 'c3',
    author: MOCK_USERS[4],
    content: "Please share the Jupyter notebooks! I'm at Week 2 of my own journey and would love to compare implementations.",
    likes: 45,
    isLiked: true,
    createdAt: new Date(Date.now() - 0.8 * 3600000).toISOString(),
    replies: [],
  },
  {
    id: 'c4',
    author: MOCK_USERS[2],
    content: "Great write-up! One thing I'd add: don't skip the math completely. You don't need to derive everything, but understanding *why* the chain rule works for backprop gives you intuition that pays dividends when debugging failing training runs.",
    likes: 67,
    createdAt: new Date(Date.now() - 0.5 * 3600000).toISOString(),
  },
  {
    id: 'c5',
    author: MOCK_USERS[3],
    content: 'Saved this post! Just starting my AI learning journey and this roadmap is incredibly helpful. One question: approximately how many hours per day were you studying during those 30 days?',
    likes: 9,
    createdAt: new Date(Date.now() - 20 * 60000).toISOString(),
    replies: [
      {
        id: 'c5r1',
        author: MOCK_USERS[1],
        content: 'About 2-3 hours on weekdays, 4-5 hours on weekends. Consistency was more important than volume — missing days broke the momentum.',
        likes: 14,
        createdAt: new Date(Date.now() - 10 * 60000).toISOString(),
      },
    ],
  },
];

const RELATED_POSTS: Pick<CommunityPost, 'id' | 'title' | 'likes' | 'comments' | 'author' | 'createdAt'>[] = [
  { id: 'p8', title: 'The Feynman Technique actually works', likes: 1204, comments: 156, author: MOCK_USERS[4], createdAt: new Date(Date.now() - 48 * 3600000).toISOString() },
  { id: 'p3', title: 'Best resources for learning Transformer architecture', likes: 92, comments: 34, author: MOCK_USERS[4], createdAt: new Date(Date.now() - 8 * 3600000).toISOString() },
  { id: 'p6', title: '30-Day Linear Algebra Challenge — Week 3 Update', likes: 445, comments: 89, author: MOCK_USERS[0], createdAt: new Date(Date.now() - 20 * 3600000).toISOString() },
];

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

  // Use real data if available, otherwise fall back to p1
  const post = MOCK_POSTS[postId] ?? MOCK_POSTS['p1'];

  const [isLiked, setIsLiked] = useState(post.isLiked ?? false);
  const [likeCount, setLikeCount] = useState(post.likes);
  const [isBookmarked, setIsBookmarked] = useState(post.isBookmarked ?? false);
  const [comments, setComments] = useState<Comment[]>(MOCK_COMMENTS);

  const typeConfig = POST_TYPE_CONFIG[post.type] ?? POST_TYPE_CONFIG.post;
  const TypeIcon = typeConfig.icon;

  const initials = post.author.displayName
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  const handleAddComment = (content: string) => {
    const newComment: Comment = {
      id: `c_${Date.now()}`,
      author: {
        id: 'u1', email: 'demo@lyo.app', displayName: 'Alex Rivera', username: 'alexrivera',
        avatar: '', bio: '', role: 'student', interests: [], learningGoals: [],
        streak: 12, xp: 4850, level: 15, coursesCompleted: 23, followersCount: 342,
        followingCount: 128, createdAt: '2024-06-01T00:00:00Z', isPremium: false,
      },
      content,
      likes: 0,
      createdAt: new Date().toISOString(),
      replies: [],
    };
    setComments((prev) => [newComment, ...prev]);
  };

  const handleReply = (commentId: string, content: string) => {
    const reply: Comment = {
      id: `r_${Date.now()}`,
      author: {
        id: 'u1', email: 'demo@lyo.app', displayName: 'Alex Rivera', username: 'alexrivera',
        avatar: '', bio: '', role: 'student', interests: [], learningGoals: [],
        streak: 12, xp: 4850, level: 15, coursesCompleted: 23, followersCount: 342,
        followingCount: 128, createdAt: '2024-06-01T00:00:00Z', isPremium: false,
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
                    onClick={() => {
                      setIsLiked((v) => !v);
                      setLikeCount((c) => isLiked ? c - 1 : c + 1);
                    }}
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
                  <button className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium text-white/60 bg-white/5 hover:bg-white/10 border border-white/10 transition-all">
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
                {RELATED_POSTS.map((rp) => {
                  const init = rp.author.displayName.split(' ').map((n) => n[0]).join('').slice(0, 2);
                  return (
                    <button
                      key={rp.id}
                      onClick={() => router.push(`/community/${rp.id}`)}
                      className="w-full text-left group"
                    >
                      <div className="p-3 rounded-xl bg-white/3 hover:bg-white/6 border border-white/8 hover:border-white/15 transition-all">
                        <p className="text-sm text-white/80 group-hover:text-white transition-colors line-clamp-2 leading-snug mb-2">
                          {rp.title}
                        </p>
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-1.5">
                            <div className="w-5 h-5 rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple flex items-center justify-center text-[8px] text-white font-bold">
                              {init}
                            </div>
                            <span className="text-[10px] text-white/40 truncate max-w-[80px]">
                              {rp.author.displayName}
                            </span>
                          </div>
                          <div className="flex items-center gap-2 text-[10px] text-white/30">
                            <span className="flex items-center gap-0.5">
                              <Heart className="w-2.5 h-2.5" /> {formatNumber(rp.likes)}
                            </span>
                            <span className="flex items-center gap-0.5">
                              <MessageCircle className="w-2.5 h-2.5" /> {rp.comments}
                            </span>
                          </div>
                        </div>
                      </div>
                    </button>
                  );
                })}
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
