'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Plus, Users, TrendingUp, Calendar, BookOpen, Hash, Camera } from 'lucide-react'
import { useRouter } from 'next/navigation'
import { cn, formatNumber } from '@/lib/utils'
import StoriesRail from '@/components/community/StoriesRail'
import PostCard from '@/components/community/PostCard'
import GroupCard from '@/components/community/GroupCard'
import CreatePostModal from '@/components/community/CreatePostModal'
import type { CommunityPost, Group } from '@/types'

// ─── Mock Data ────────────────────────────────────────────────────────────────

const MOCK_AUTHOR = {
  id: 'u1',
  email: 'alex@example.com',
  displayName: 'Alex Chen',
  username: 'alexchen',
  avatar: '',
  bio: 'Full-stack dev & lifelong learner',
  role: 'student' as const,
  interests: ['JavaScript', 'Python'],
  learningGoals: [],
  streak: 42,
  xp: 8200,
  level: 12,
  coursesCompleted: 7,
  followersCount: 234,
  followingCount: 89,
  createdAt: '2023-01-01',
  isPremium: true,
}

const MOCK_POSTS: CommunityPost[] = [
  {
    id: 'p1',
    author: MOCK_AUTHOR,
    type: 'post',
    title: 'Just finished the Advanced React Patterns course — mind blown 🤯',
    content: 'After 3 weeks of deep diving into compound components, render props, and custom hooks, I finally feel like I understand React at a fundamental level. The section on context optimization alone saved 40% render time in my side project. Highly recommend to anyone who wants to level up their frontend skills!',
    tags: ['react', 'javascript', 'webdev'],
    category: 'Showcase',
    likes: 124,
    comments: 18,
    views: 892,
    isLiked: false,
    isBookmarked: true,
    createdAt: new Date(Date.now() - 2 * 3600000).toISOString(),
  },
  {
    id: 'p2',
    author: { ...MOCK_AUTHOR, id: 'u2', displayName: 'Sarah Kim', username: 'sarahk' },
    type: 'question',
    title: 'Best resources for learning machine learning from scratch in 2025?',
    content: 'I have a solid Python background and understand basic statistics, but I\'m not sure where to start with ML. Should I go with Andrew Ng\'s course, fast.ai, or dive straight into PyTorch? Looking for practical, project-focused resources rather than heavy theory.',
    tags: ['machinelearning', 'python', 'beginners'],
    category: 'Questions',
    likes: 67,
    comments: 34,
    views: 1203,
    isLiked: true,
    createdAt: new Date(Date.now() - 5 * 3600000).toISOString(),
  },
  {
    id: 'p3',
    author: { ...MOCK_AUTHOR, id: 'u3', displayName: 'Marcus J.', username: 'marcusj' },
    type: 'poll',
    title: 'What\'s your preferred way to learn new programming concepts?',
    content: 'Curious how the community approaches learning. I\'ve been debating between structured courses vs building projects from day one.',
    tags: ['learning', 'productivity'],
    category: 'General',
    likes: 89,
    comments: 22,
    views: 654,
    poll: {
      id: 'poll1',
      options: [
        { id: 'o1', text: 'Structured courses (video/reading)', votes: 142, isSelected: false },
        { id: 'o2', text: 'Build projects from day one', votes: 98, isSelected: true },
        { id: 'o3', text: 'Mix of both', votes: 201, isSelected: false },
        { id: 'o4', text: 'Pair programming / mentorship', votes: 57, isSelected: false },
      ],
      totalVotes: 498,
      endsAt: new Date(Date.now() + 2 * 86400000).toISOString(),
    },
    createdAt: new Date(Date.now() - 8 * 3600000).toISOString(),
  },
  {
    id: 'p4',
    author: { ...MOCK_AUTHOR, id: 'u4', displayName: 'Priya S.', username: 'priyas' },
    type: 'event',
    title: 'Live Coding Session: Building a REST API with FastAPI',
    content: 'Join me this Saturday for a 2-hour live coding session where we\'ll build a complete REST API with authentication, database integration, and deployment. Bring your questions! All skill levels welcome.',
    tags: ['python', 'fastapi', 'livecoding', 'backend'],
    category: 'Events',
    likes: 45,
    comments: 12,
    views: 423,
    createdAt: new Date(Date.now() - 12 * 3600000).toISOString(),
  },
  {
    id: 'p5',
    author: { ...MOCK_AUTHOR, id: 'u5', displayName: 'Jordan T.', username: 'jordant' },
    type: 'course_share',
    title: 'Course Review: "System Design Fundamentals" — 9/10 ⭐',
    content: 'Finished this course in 2 weeks and it completely changed how I think about scalability. Covers everything from load balancing to database sharding with real-world examples from Netflix, Uber, and Twitter. The interview prep section alone is worth it.',
    tags: ['systemdesign', 'architecture', 'interviews'],
    category: 'Guides',
    likes: 201,
    comments: 41,
    views: 2140,
    isBookmarked: false,
    courseId: 'course-sys-design',
    createdAt: new Date(Date.now() - 18 * 3600000).toISOString(),
  },
  {
    id: 'p6',
    author: { ...MOCK_AUTHOR, id: 'u6', displayName: 'Leila M.', username: 'leilam' },
    type: 'post',
    title: '30-day Spanish challenge: Week 4 update 🇪🇸',
    content: 'Can\'t believe I\'m already in week 4! My listening comprehension has improved dramatically. I can now watch Spanish Netflix shows without subtitles for about 70% comprehension. Using the spaced repetition deck shared here + daily 30min immersion. Who else is on a language learning streak?',
    tags: ['spanish', 'languagelearning', 'streak'],
    category: 'Showcase',
    likes: 156,
    comments: 28,
    views: 934,
    isLiked: true,
    createdAt: new Date(Date.now() - 24 * 3600000).toISOString(),
  },
  {
    id: 'p7',
    author: { ...MOCK_AUTHOR, id: 'u7', displayName: 'Ryu H.', username: 'ryuh' },
    type: 'achievement',
    title: '🏆 Just hit 100-day streak!',
    content: 'Started as a complete beginner in data science 100 days ago. Today I deployed my first ML model to production. The key was consistency — even 20 minutes a day compounds into something incredible. Thank you to this community for the motivation!',
    tags: ['milestone', 'datascience', 'motivation'],
    category: 'General',
    likes: 342,
    comments: 67,
    views: 3210,
    isLiked: false,
    createdAt: new Date(Date.now() - 30 * 3600000).toISOString(),
  },
  {
    id: 'p8',
    author: { ...MOCK_AUTHOR, id: 'u8', displayName: 'Emma W.', username: 'emmaw' },
    type: 'question',
    title: 'How do you stay focused during long study sessions?',
    content: 'I find myself losing focus after about 45 minutes no matter what I try. Have experimented with Pomodoro, ambient music, and different environments. What strategies have worked best for you? Looking for practical tips that go beyond "put your phone away."',
    tags: ['productivity', 'focus', 'studytips'],
    category: 'Questions',
    likes: 93,
    comments: 56,
    views: 1876,
    createdAt: new Date(Date.now() - 36 * 3600000).toISOString(),
  },
]

const MOCK_GROUPS: Group[] = [
  {
    id: 'g1',
    name: 'JavaScript Developers',
    description: 'A community for JS developers of all levels. Share tips, resources, projects, and get help with your code.',
    coverImage: '',
    icon: '⚡',
    memberCount: 8420,
    category: 'Technology',
    isJoined: true,
    isPrivate: false,
    admin: MOCK_AUTHOR,
    recentActivity: 'Emma posted a new tutorial 2h ago',
    createdAt: '2023-01-01',
  },
  {
    id: 'g2',
    name: 'ML & AI Study Group',
    description: 'Weekly paper readings, project collaboration, and discussions on the latest in machine learning and artificial intelligence.',
    coverImage: '',
    icon: '🤖',
    memberCount: 3201,
    category: 'Technology',
    isJoined: false,
    isPrivate: false,
    admin: { ...MOCK_AUTHOR, id: 'u2' },
    recentActivity: 'New discussion: GPT-4 vs Llama 3 for code gen',
    createdAt: '2023-03-15',
  },
  {
    id: 'g3',
    name: 'Language Learning Hub',
    description: 'Practice partners, resource sharing, and cultural exchange for language learners worldwide.',
    coverImage: '',
    icon: '🌍',
    memberCount: 5670,
    category: 'Languages',
    isJoined: true,
    isPrivate: false,
    admin: { ...MOCK_AUTHOR, id: 'u3' },
    recentActivity: '12 new members this week',
    createdAt: '2023-02-10',
  },
  {
    id: 'g4',
    name: 'Data Science & Analytics',
    description: 'Explore data science fundamentals, visualization techniques, and real-world analytics projects together.',
    coverImage: '',
    icon: '📊',
    memberCount: 4102,
    category: 'Science',
    isJoined: false,
    isPrivate: false,
    admin: { ...MOCK_AUTHOR, id: 'u4' },
    recentActivity: 'Monthly challenge: Kaggle competition',
    createdAt: '2023-04-01',
  },
  {
    id: 'g5',
    name: 'UI/UX Design Circle',
    description: 'Share design work, get feedback, discuss tools and trends, and grow your design skills with peers.',
    coverImage: '',
    icon: '🎨',
    memberCount: 2890,
    category: 'Arts',
    isJoined: false,
    isPrivate: false,
    admin: { ...MOCK_AUTHOR, id: 'u5' },
    recentActivity: 'Portfolio critique session this Friday',
    createdAt: '2023-05-20',
  },
  {
    id: 'g6',
    name: 'Startup & Entrepreneurship',
    description: 'For builders and dreamers. Share ideas, get feedback on your startup, discuss growth strategies and funding.',
    coverImage: '',
    icon: '🚀',
    memberCount: 1934,
    category: 'Business',
    isJoined: false,
    isPrivate: false,
    admin: { ...MOCK_AUTHOR, id: 'u6' },
    recentActivity: 'AMA with a YC founder next week',
    createdAt: '2023-06-01',
  },
]

const MOCK_EVENTS = [
  {
    id: 'ev1',
    title: 'React Summit 2025 — Community Watch Party',
    date: 'Sat, Dec 14 · 2:00 PM UTC',
    location: 'Online (LYO Community Room)',
    attendees: 127,
    emoji: '⚛️',
    color: 'from-blue-600 to-indigo-700',
  },
  {
    id: 'ev2',
    title: 'Python for Data Science Bootcamp',
    date: 'Mon, Dec 16 · 6:00 PM UTC',
    location: 'Online (Zoom)',
    attendees: 89,
    emoji: '🐍',
    color: 'from-emerald-600 to-teal-700',
  },
  {
    id: 'ev3',
    title: 'Open Source Contribution Sprint',
    date: 'Fri, Dec 20 · 10:00 AM UTC',
    location: 'GitHub + Discord',
    attendees: 214,
    emoji: '🔓',
    color: 'from-violet-600 to-purple-700',
  },
  {
    id: 'ev4',
    title: 'Language Exchange: Spanish ↔ English',
    date: 'Sun, Dec 22 · 4:00 PM UTC',
    location: 'Online (Community Voice)',
    attendees: 56,
    emoji: '🗣️',
    color: 'from-orange-600 to-amber-700',
  },
]

const TRENDING_TOPICS = [
  { tag: 'react', count: 342 },
  { tag: 'machinelearning', count: 289 },
  { tag: 'systemdesign', count: 201 },
  { tag: 'python', count: 178 },
  { tag: 'webdev', count: 156 },
  { tag: 'datascience', count: 134 },
  { tag: 'javascript', count: 122 },
  { tag: 'productivity', count: 98 },
]

const SUGGESTED_GROUPS = MOCK_GROUPS.filter(g => !g.isJoined).slice(0, 3)

const ACTIVE_MEMBERS = [
  { id: 'm1', name: 'Alex Chen', xp: 8200, color: 'from-blue-500 to-indigo-600' },
  { id: 'm2', name: 'Sarah Kim', xp: 7400, color: 'from-pink-500 to-rose-600' },
  { id: 'm3', name: 'Marcus J.', xp: 6900, color: 'from-emerald-500 to-teal-600' },
  { id: 'm4', name: 'Priya S.', xp: 6100, color: 'from-orange-500 to-amber-600' },
  { id: 'm5', name: 'Jordan T.', xp: 5800, color: 'from-violet-500 to-purple-600' },
]

const TABS = ['Feed', 'Groups', 'Events', 'Trending'] as const
type Tab = typeof TABS[number]

const STATS = [
  { label: 'Members', value: '12.4K', icon: Users, color: 'text-blue-400' },
  { label: 'Active Today', value: '892', icon: TrendingUp, color: 'text-emerald-400' },
  { label: 'Posts', value: '3.2K', icon: BookOpen, color: 'text-lyo-400' },
  { label: 'Courses Shared', value: '567', icon: BookOpen, color: 'text-accent-purple' },
]

// ─── Component ────────────────────────────────────────────────────────────────

export default function CommunityPage() {
  const router = useRouter()
  const [activeTab, setActiveTab] = useState<Tab>('Feed')
  const [showCreateModal, setShowCreateModal] = useState(false)

  return (
    <div className="flex gap-6">
      {/* Main Content */}
      <div className="flex-1 min-w-0 space-y-5">
        {/* Stories */}
        <section className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm px-4 py-4">
          <StoriesRail onStoryClick={() => router.push('/stories')} />
        </section>

        {/* Stats Bar */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {STATS.map(({ label, value, icon: Icon, color }) => (
            <div
              key={label}
              className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm px-4 py-3 flex items-center gap-3"
            >
              <div className={cn('p-2 rounded-xl bg-white/10', color)}>
                <Icon className="w-4 h-4" />
              </div>
              <div>
                <p className="text-lg font-bold text-white leading-none">{value}</p>
                <p className="text-xs text-white/50 mt-0.5">{label}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Tabs */}
        <div className="flex gap-1 p-1 rounded-xl bg-white/5 border border-white/10">
          {TABS.map(tab => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={cn(
                'flex-1 py-2 px-4 rounded-lg text-sm font-medium transition-all duration-200',
                activeTab === tab
                  ? 'bg-gradient-to-r from-lyo-500 to-accent-purple text-white shadow'
                  : 'text-white/60 hover:text-white hover:bg-white/10'
              )}
            >
              {tab}
            </button>
          ))}
        </div>

        {/* Tab Content */}
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.2 }}
          >
            {/* Feed Tab */}
            {activeTab === 'Feed' && (
              <div className="space-y-4 relative">
                {MOCK_POSTS.map(post => (
                  <PostCard
                    key={post.id}
                    post={post}
                    onClick={() => router.push(`/community/${post.id}`)}
                  />
                ))}
                {/* FAB */}
                <motion.button
                  whileHover={{ scale: 1.08 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => setShowCreateModal(true)}
                  className="fixed bottom-24 md:bottom-8 right-6 md:right-8 z-30 flex items-center gap-2 px-5 py-3.5 rounded-full bg-gradient-to-r from-lyo-500 to-accent-purple text-white font-semibold shadow-2xl shadow-lyo-500/40"
                >
                  <Plus className="w-5 h-5" />
                  <span className="hidden sm:inline">Create Post</span>
                </motion.button>
              </div>
            )}

            {/* Groups Tab */}
            {activeTab === 'Groups' && (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {MOCK_GROUPS.map(group => (
                  <GroupCard key={group.id} group={group} />
                ))}
              </div>
            )}

            {/* Events Tab */}
            {activeTab === 'Events' && (
              <div className="space-y-4">
                {MOCK_EVENTS.map(event => (
                  <motion.div
                    key={event.id}
                    whileHover={{ y: -2 }}
                    className="rounded-2xl border border-white/10 bg-white/5 overflow-hidden cursor-pointer hover:border-white/20 transition-colors"
                  >
                    <div className={cn('h-2 w-full bg-gradient-to-r', event.color)} />
                    <div className="p-4 flex items-start gap-4">
                      <div className="text-3xl">{event.emoji}</div>
                      <div className="flex-1 min-w-0">
                        <h3 className="font-semibold text-white mb-1">{event.title}</h3>
                        <div className="flex items-center gap-2 text-sm text-white/50 mb-1">
                          <Calendar className="w-3.5 h-3.5 flex-shrink-0" />
                          <span>{event.date}</span>
                        </div>
                        <p className="text-sm text-white/40">{event.location}</p>
                      </div>
                      <div className="flex flex-col items-end gap-2">
                        <div className="flex items-center gap-1 text-sm text-white/60">
                          <Users className="w-3.5 h-3.5" />
                          <span>{event.attendees}</span>
                        </div>
                        <button className="px-4 py-1.5 rounded-lg bg-gradient-to-r from-lyo-500 to-accent-purple text-white text-sm font-medium hover:opacity-90 transition-opacity">
                          RSVP
                        </button>
                      </div>
                    </div>
                  </motion.div>
                ))}
              </div>
            )}

            {/* Trending Tab */}
            {activeTab === 'Trending' && (
              <div className="space-y-3">
                {TRENDING_TOPICS.map(({ tag, count }, i) => (
                  <motion.div
                    key={tag}
                    initial={{ opacity: 0, x: -16 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: i * 0.05 }}
                    className="flex items-center gap-4 p-4 rounded-2xl border border-white/10 bg-white/5 hover:bg-white/10 cursor-pointer transition-colors group"
                  >
                    <span className="text-2xl font-bold text-white/10 w-8 text-center">
                      {i + 1}
                    </span>
                    <div className="flex-1">
                      <p className="font-medium text-white group-hover:text-lyo-300 transition-colors">
                        #{tag}
                      </p>
                      <p className="text-sm text-white/40">{count} posts this week</p>
                    </div>
                    <TrendingUp className="w-4 h-4 text-lyo-400 opacity-0 group-hover:opacity-100 transition-opacity" />
                  </motion.div>
                ))}
              </div>
            )}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Right Sidebar — Desktop */}
      <aside className="hidden xl:flex flex-col gap-4 w-72 flex-shrink-0">
        {/* Trending Tags */}
        <div className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm p-4">
          <h3 className="font-semibold text-white mb-3 flex items-center gap-2">
            <Hash className="w-4 h-4 text-lyo-400" />
            Trending Tags
          </h3>
          <div className="flex flex-wrap gap-2">
            {TRENDING_TOPICS.slice(0, 8).map(({ tag }) => (
              <button
                key={tag}
                className="px-3 py-1 rounded-full text-xs border border-white/10 text-white/60 hover:border-lyo-500/50 hover:text-lyo-300 hover:bg-lyo-500/10 transition-all"
              >
                #{tag}
              </button>
            ))}
          </div>
        </div>

        {/* Suggested Groups */}
        <div className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm p-4">
          <h3 className="font-semibold text-white mb-3 flex items-center gap-2">
            <Users className="w-4 h-4 text-lyo-400" />
            Suggested Groups
          </h3>
          <div className="space-y-3">
            {SUGGESTED_GROUPS.map(group => (
              <div key={group.id} className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-lyo-500 to-accent-purple flex items-center justify-center text-base flex-shrink-0">
                  {group.icon}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-white truncate">{group.name}</p>
                  <p className="text-xs text-white/40">{formatNumber(group.memberCount)} members</p>
                </div>
                <button className="text-xs px-3 py-1 rounded-lg bg-lyo-500/20 text-lyo-300 hover:bg-lyo-500/30 transition-colors font-medium">
                  Join
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Active Members */}
        <div className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm p-4">
          <h3 className="font-semibold text-white mb-3 flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-lyo-400" />
            Active Members
          </h3>
          <div className="space-y-2.5">
            {ACTIVE_MEMBERS.map(({ id, name, xp, color }, i) => (
              <div key={id} className="flex items-center gap-3">
                <span className="text-xs text-white/30 w-4 text-center">{i + 1}</span>
                <div className={cn('w-8 h-8 rounded-full bg-gradient-to-br flex items-center justify-center text-xs font-bold text-white flex-shrink-0', color)}>
                  {name.split(' ').map(n => n[0]).join('')}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-white truncate">{name}</p>
                </div>
                <span className="text-xs text-lyo-400 font-medium">{formatNumber(xp)} XP</span>
              </div>
            ))}
          </div>
        </div>
      </aside>

      {/* Create Post Modal */}
      {showCreateModal && (
        <CreatePostModal
          onClose={() => setShowCreateModal(false)}
          onSubmit={data => {
            console.log('New post:', data)
            setShowCreateModal(false)
          }}
        />
      )}
    </div>
  )
}
