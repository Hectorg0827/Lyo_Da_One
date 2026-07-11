'use client'

import { useState, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Plus, Users, TrendingUp, Calendar, BookOpen, Hash, Loader2 } from 'lucide-react'
import { useRouter } from 'next/navigation'
import { cn, formatNumber } from '@/lib/utils'
import StoriesRail from '@/components/community/StoriesRail'
import PostCard from '@/components/community/PostCard'
import GroupCard from '@/components/community/GroupCard'
import CreatePostModal from '@/components/community/CreatePostModal'
import { useApi } from '@/hooks/use-api'
import { api, adaptUser } from '@/lib/api'
import type { CommunityPost, Group, User } from '@/types'

// ─── Helpers: map backend → frontend types ──────────────────────────────────

function mapBackendPost(raw: Record<string, unknown>): CommunityPost {
  const rawUser = (raw.user as Record<string, unknown>) || {}
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
      }

  return {
    id: String(raw.id ?? ''),
    author,
    type: (raw.type as CommunityPost['type']) || 'post',
    title: (raw.title as string) || (raw.content as string)?.slice(0, 80) || '',
    content: (raw.content as string) || '',
    images: (raw.media_urls as string[]) || (raw.images as string[]) || [],
    tags: (raw.tags as string[]) || [],
    category: (raw.category as string) || 'General',
    likes: (raw.like_count as number) ?? (raw.likes as number) ?? 0,
    comments: (raw.comment_count as number) ?? (raw.comments as number) ?? 0,
    views: (raw.view_count as number) ?? (raw.views as number) ?? 0,
    isLiked: (raw.is_liked as boolean) ?? false,
    isBookmarked: (raw.is_bookmarked as boolean) ?? false,
    createdAt: (raw.created_at as string) || new Date().toISOString(),
  }
}

const DEFAULT_ADMIN: User = {
  id: '0',
  email: '',
  displayName: 'Admin',
  username: 'admin',
  avatar: '',
  bio: '',
  role: 'admin',
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
}

function mapBackendGroup(raw: Record<string, unknown>): Group {
  const rawAdmin = (raw.admin as Record<string, unknown>) || {}
  return {
    id: String(raw.id ?? ''),
    name: (raw.name as string) || '',
    description: (raw.description as string) || '',
    coverImage: (raw.cover_image as string) || '',
    icon: (raw.icon as string) || '👥',
    memberCount: (raw.member_count as number) ?? 0,
    category: (raw.category as string) || 'General',
    isJoined: (raw.is_joined as boolean) ?? false,
    isPrivate: (raw.is_private as boolean) ?? false,
    admin: rawAdmin.id ? adaptUser(rawAdmin) : DEFAULT_ADMIN,
    recentActivity: (raw.recent_activity as string) || '',
    createdAt: (raw.created_at as string) || new Date().toISOString(),
  }
}

// TODO: wire to trending endpoint
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

const ACTIVE_MEMBERS = [
  { id: 'm1', name: 'Alex Chen', xp: 8200, color: 'from-blue-500 to-indigo-600' },
  { id: 'm2', name: 'Sarah Kim', xp: 7400, color: 'from-pink-500 to-rose-600' },
  { id: 'm3', name: 'Marcus J.', xp: 6900, color: 'from-emerald-500 to-teal-600' },
  { id: 'm4', name: 'Priya S.', xp: 6100, color: 'from-orange-500 to-amber-600' },
  { id: 'm5', name: 'Jordan T.', xp: 5800, color: 'from-violet-500 to-purple-600' },
]

const TABS = ['Feed', 'Groups', 'Events', 'Trending'] as const
type Tab = typeof TABS[number]

// ─── Component ────────────────────────────────────────────────────────────────

export default function CommunityPage() {
  const router = useRouter()
  const [activeTab, setActiveTab] = useState<Tab>('Feed')
  const [showCreateModal, setShowCreateModal] = useState(false)

  // ── Fetch posts ──
  const {
    data: feedData,
    isLoading: feedLoading,
    error: feedError,
    refetch: refetchFeed,
  } = useApi(
    () => api.feed.publicFeed(1, 20),
    []
  )

  const posts: CommunityPost[] = feedData?.posts?.map(mapBackendPost) ?? []
  const totalPosts = feedData?.total ?? 0

  // ── Fetch groups ──
  const {
    data: rawGroups,
    isLoading: groupsLoading,
    error: groupsError,
  } = useApi(
    () => api.community.groups(),
    []
  )

  const groups: Group[] = rawGroups?.map(mapBackendGroup) ?? []
  const suggestedGroups = groups.filter(g => !g.isJoined).slice(0, 3)

  // ── Fetch events ──
  const {
    data: rawEvents,
    isLoading: eventsLoading,
    error: eventsError,
  } = useApi(
    () => api.community.events(),
    []
  )

  const GRADIENT_COLORS = [
    'from-blue-600 to-indigo-700',
    'from-emerald-600 to-teal-700',
    'from-violet-600 to-purple-700',
    'from-orange-600 to-amber-700',
  ]

  const events = (rawEvents ?? []).map((raw: Record<string, unknown>, i: number) => ({
    id: String(raw.id ?? `ev-${i}`),
    title: (raw.title as string) || (raw.name as string) || '',
    date: (raw.date as string) || (raw.start_time as string) || '',
    location: (raw.location as string) || 'Online',
    attendees: (raw.attendee_count as number) ?? (raw.attendees as number) ?? 0,
    emoji: (raw.emoji as string) || '📅',
    color: GRADIENT_COLORS[i % GRADIENT_COLORS.length],
  }))

  // ── Derive stats from API data ──
  const STATS = [
    { label: 'Members', value: groups.length > 0 ? formatNumber(groups.reduce((sum, g) => sum + g.memberCount, 0)) : '---', icon: Users, color: 'text-blue-400' },
    { label: 'Active Today', value: '---', icon: TrendingUp, color: 'text-emerald-400' },
    { label: 'Posts', value: totalPosts > 0 ? formatNumber(totalPosts) : '---', icon: BookOpen, color: 'text-lyo-400' },
    { label: 'Courses Shared', value: '---', icon: BookOpen, color: 'text-accent-purple' },
  ]

  // ── Create post handler ──
  const handleCreatePost = useCallback(async (data: { type: string; title: string; content: string; tags: string[]; category: string; pollOptions?: string[]; image?: string | null }) => {
    try {
      await api.feed.create(data.content)
      setShowCreateModal(false)
      refetchFeed()
    } catch (err) {
      console.error('Failed to create post:', err)
    }
  }, [refetchFeed])

  // ── Loading spinner helper ──
  const LoadingSpinner = () => (
    <div className="flex items-center justify-center py-12">
      <Loader2 className="w-6 h-6 text-lyo-400 animate-spin" />
      <span className="ml-2 text-white/50 text-sm">Loading...</span>
    </div>
  )

  const ErrorMessage = ({ message }: { message: string }) => (
    <div className="flex items-center justify-center py-12">
      <p className="text-red-400 text-sm">{message}</p>
    </div>
  )

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
                {feedLoading && <LoadingSpinner />}
                {feedError && <ErrorMessage message={feedError} />}
                {!feedLoading && !feedError && posts.length === 0 && (
                  <p className="text-center text-white/40 py-12 text-sm">No posts yet. Be the first to share!</p>
                )}
                {!feedLoading && !feedError && posts.map(post => (
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
              <div>
                {groupsLoading && <LoadingSpinner />}
                {groupsError && <ErrorMessage message={groupsError} />}
                {!groupsLoading && !groupsError && (
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {groups.map(group => (
                      <GroupCard key={group.id} group={group} />
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Events Tab */}
            {activeTab === 'Events' && (
              <div className="space-y-4">
                {eventsLoading && <LoadingSpinner />}
                {eventsError && <ErrorMessage message={eventsError} />}
                {!eventsLoading && !eventsError && events.map(event => (
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
          {groupsLoading && (
            <div className="flex items-center justify-center py-4">
              <Loader2 className="w-4 h-4 text-lyo-400 animate-spin" />
            </div>
          )}
          {!groupsLoading && (
            <div className="space-y-3">
              {suggestedGroups.map(group => (
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
          )}
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
          onSubmit={handleCreatePost}
        />
      )}
    </div>
  )
}
