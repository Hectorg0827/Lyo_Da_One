'use client'

import { useCallback, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Plus, Users, TrendingUp, Calendar, BookOpen, Hash, Loader2 } from 'lucide-react'
import { useRouter } from 'next/navigation'
import { cn, formatNumber } from '@/lib/utils'
import StoriesRail from '@/components/community/StoriesRail'
import PostCard from '@/components/community/PostCard'
import GroupCard from '@/components/community/GroupCard'
import CreatePostModal from '@/components/community/CreatePostModal'
import { useApi } from '@/hooks/use-api'
import { useSyncEvents } from '@/hooks/use-sync'
import { api, adaptUser } from '@/lib/api'
import type { CommunityPost, Group, User } from '@/types'

// ─── Helpers: map backend → frontend types ──────────────────────────────────

/** Map a community PostRead (the same store iOS renders) to the view model. */
function mapCommunityPost(raw: Record<string, unknown>): CommunityPost {
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
  }

  const tags = (raw.tags as string[]) || []
  return {
    id: String(raw.id ?? ''),
    author,
    type: 'post',
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
    category: (raw.category as string) || (raw.subject as string) || 'General',
    isJoined: (raw.is_joined as boolean) ?? (raw.is_member as boolean) ?? false,
    isPrivate: (raw.is_private as boolean) ?? ((raw.privacy as string) === 'private'),
    admin: rawAdmin.id ? adaptUser(rawAdmin) : DEFAULT_ADMIN,
    recentActivity: (raw.recent_activity as string) || '',
    createdAt: (raw.created_at as string) || new Date().toISOString(),
  }
}

const TABS = ['Feed', 'Groups', 'Events', 'Trending'] as const
type Tab = typeof TABS[number]

const GRADIENT_COLORS = [
  'from-blue-600 to-indigo-700',
  'from-emerald-600 to-teal-700',
  'from-violet-600 to-purple-700',
  'from-orange-600 to-amber-700',
]

// ─── Component ────────────────────────────────────────────────────────────────

export default function CommunityPage() {
  const router = useRouter()
  const [activeTab, setActiveTab] = useState<Tab>('Feed')
  const [showCreateModal, setShowCreateModal] = useState(false)

  // ── Fetch posts (community store — identical data to iOS/Android) ──
  const {
    data: feedData,
    isLoading: feedLoading,
    error: feedError,
    refetch: refetchFeed,
  } = useApi(() => api.community.posts(1, 20), [])

  const posts: CommunityPost[] = feedData?.items?.map(mapCommunityPost) ?? []
  const totalPosts = feedData?.total_count ?? 0

  // Live updates: refresh when another device posts/comments
  useSyncEvents(
    useCallback(() => refetchFeed(), [refetchFeed]),
    ['context_updated']
  )

  // ── Fetch groups ──
  const {
    data: rawGroups,
    isLoading: groupsLoading,
    error: groupsError,
    refetch: refetchGroups,
  } = useApi(() => api.community.groups(), [])

  const groups: Group[] = rawGroups?.map(mapBackendGroup) ?? []
  const suggestedGroups = groups.filter(g => !g.isJoined).slice(0, 3)

  // ── Fetch events ──
  const {
    data: rawEvents,
    isLoading: eventsLoading,
    error: eventsError,
    refetch: refetchEvents,
  } = useApi(() => api.community.events(), [])

  const events = (rawEvents ?? []).map((raw: Record<string, unknown>, i: number) => ({
    id: String(raw.id ?? `ev-${i}`),
    title: (raw.title as string) || (raw.name as string) || '',
    date: (raw.start_time as string) || (raw.date as string) || '',
    location: (raw.location as string) || ((raw.is_online as boolean) ? 'Online' : 'TBA'),
    attendees: (raw.attendee_count as number) ?? (raw.attendees as number) ?? 0,
    // Backend reports the caller's attendance row status (going/maybe/…)
    isAttending: raw.user_attendance_status != null,
    emoji: (raw.emoji as string) || '📅',
    color: GRADIENT_COLORS[i % GRADIENT_COLORS.length],
  }))

  // ── Community stats (real /community/stats) ──
  const { data: statsData } = useApi(() => api.community.stats(), [])
  const STATS = [
    { label: 'Groups', value: formatNumber(statsData?.total_groups ?? 0), icon: Users, color: 'text-blue-400' },
    { label: 'Events', value: formatNumber(statsData?.total_events ?? 0), icon: Calendar, color: 'text-emerald-400' },
    { label: 'Posts', value: formatNumber(totalPosts), icon: BookOpen, color: 'text-lyo-400' },
    { label: 'Upcoming', value: formatNumber(statsData?.upcoming_events ?? 0), icon: TrendingUp, color: 'text-accent-purple' },
  ]

  // ── Trending topics (real /discover/trending) ──
  const { data: trendingData, isLoading: trendingLoading } = useApi(
    () => api.discover.trending(),
    []
  )
  const trendingTopics = (trendingData?.topics ?? []) as {
    name: string
    count: number
    icon: string
  }[]

  // ── Top members (real XP leaderboard) ──
  const { data: leaderboardData } = useApi(
    () => api.gamification.leaderboard('xp', 'all_time', 5),
    []
  )
  const leaderboardEntries = ((leaderboardData?.entries as Record<string, unknown>[]) ?? []) as {
    user_id: number
    score: number
    rank: number
    username?: string
    first_name?: string
    last_name?: string
    avatar_url?: string
  }[]
  const topMembers = leaderboardEntries.map((e, i) => ({
    id: String(e.user_id),
    name:
      [e.first_name, e.last_name].filter(Boolean).join(' ') ||
      e.username ||
      `Member #${e.user_id}`,
    xp: e.score,
    avatar: e.avatar_url,
    color: GRADIENT_COLORS[i % GRADIENT_COLORS.length],
  }))

  // ── Actions ──
  const [joinBusy, setJoinBusy] = useState<Set<string>>(new Set())
  const handleJoinGroup = useCallback(
    async (groupId: string) => {
      if (joinBusy.has(groupId)) return
      setJoinBusy(prev => new Set(prev).add(groupId))
      try {
        await api.community.joinGroup(groupId)
        refetchGroups()
      } catch (err) {
        console.error('Failed to join group:', err)
      } finally {
        setJoinBusy(prev => {
          const next = new Set(prev)
          next.delete(groupId)
          return next
        })
      }
    },
    [joinBusy, refetchGroups]
  )

  const [rsvpBusy, setRsvpBusy] = useState<Set<string>>(new Set())
  const handleRsvp = useCallback(
    async (eventId: string, isAttending: boolean) => {
      if (rsvpBusy.has(eventId)) return
      setRsvpBusy(prev => new Set(prev).add(eventId))
      try {
        if (isAttending) {
          await api.community.unattendEvent(eventId)
        } else {
          await api.community.attendEvent(eventId)
        }
        refetchEvents()
      } catch (err) {
        console.error('Failed to update RSVP:', err)
      } finally {
        setRsvpBusy(prev => {
          const next = new Set(prev)
          next.delete(eventId)
          return next
        })
      }
    },
    [rsvpBusy, refetchEvents]
  )

  // ── Create post: full canonical payload (same fields iOS sends) ──
  const handleCreatePost = useCallback(
    async (data: { type: string; title: string; content: string; tags: string[]; image?: string | null }) => {
      try {
        // The canonical post model has no separate title — prepend it.
        const content = data.title ? `${data.title}\n\n${data.content}` : data.content
        await api.community.createPost({
          content,
          tags: data.tags,
          media_urls: data.image ? [data.image] : undefined,
          post_type: 'text',
        })
        setShowCreateModal(false)
        refetchFeed()
      } catch (err) {
        console.error('Failed to create post:', err)
      }
    },
    [refetchFeed]
  )

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
                {!groupsLoading && !groupsError && groups.length === 0 && (
                  <p className="text-center text-white/40 py-12 text-sm">No study groups yet.</p>
                )}
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
                {!eventsLoading && !eventsError && events.length === 0 && (
                  <p className="text-center text-white/40 py-12 text-sm">No upcoming events.</p>
                )}
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
                          <span>{event.date ? new Date(event.date).toLocaleString() : 'TBA'}</span>
                        </div>
                        <p className="text-sm text-white/40">{event.location}</p>
                      </div>
                      <div className="flex flex-col items-end gap-2">
                        <div className="flex items-center gap-1 text-sm text-white/60">
                          <Users className="w-3.5 h-3.5" />
                          <span>{event.attendees}</span>
                        </div>
                        <button
                          onClick={e => {
                            e.stopPropagation()
                            handleRsvp(event.id, event.isAttending)
                          }}
                          disabled={rsvpBusy.has(event.id)}
                          className={cn(
                            'px-4 py-1.5 rounded-lg text-sm font-medium transition-opacity disabled:opacity-50',
                            event.isAttending
                              ? 'border border-accent-green/40 text-accent-green bg-accent-green/10 hover:bg-red-500/10 hover:border-red-400/40 hover:text-red-400'
                              : 'bg-gradient-to-r from-lyo-500 to-accent-purple text-white hover:opacity-90'
                          )}
                        >
                          {rsvpBusy.has(event.id) ? '…' : event.isAttending ? 'Going ✓' : 'RSVP'}
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
                {trendingLoading && <LoadingSpinner />}
                {!trendingLoading && trendingTopics.length === 0 && (
                  <p className="text-center text-white/40 py-12 text-sm">Nothing trending yet.</p>
                )}
                {trendingTopics.map(({ name, count, icon }, i) => (
                  <motion.div
                    key={name}
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
                        {icon} {name}
                      </p>
                      <p className="text-sm text-white/40">{formatNumber(count)} learners</p>
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
            Trending
          </h3>
          <div className="flex flex-wrap gap-2">
            {trendingTopics.slice(0, 8).map(({ name }) => (
              <button
                key={name}
                onClick={() => setActiveTab('Trending')}
                className="px-3 py-1 rounded-full text-xs border border-white/10 text-white/60 hover:border-lyo-500/50 hover:text-lyo-300 hover:bg-lyo-500/10 transition-all"
              >
                #{name.toLowerCase().replace(/\s+/g, '')}
              </button>
            ))}
            {trendingTopics.length === 0 && (
              <p className="text-xs text-white/30">Nothing trending yet.</p>
            )}
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
          {!groupsLoading && suggestedGroups.length === 0 && (
            <p className="text-xs text-white/30">No suggestions right now.</p>
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
                  <button
                    onClick={() => handleJoinGroup(group.id)}
                    disabled={joinBusy.has(group.id)}
                    className="text-xs px-3 py-1 rounded-lg bg-lyo-500/20 text-lyo-300 hover:bg-lyo-500/30 transition-colors font-medium disabled:opacity-50"
                  >
                    {joinBusy.has(group.id) ? '…' : 'Join'}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Top Members (real XP leaderboard) */}
        {topMembers.length > 0 && (
          <div className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm p-4">
            <h3 className="font-semibold text-white mb-3 flex items-center gap-2">
              <TrendingUp className="w-4 h-4 text-lyo-400" />
              Top Members
            </h3>
            <div className="space-y-2.5">
              {topMembers.map(({ id, name, xp, avatar, color }, i) => (
                <div key={id} className="flex items-center gap-3">
                  <span className="text-xs text-white/30 w-4 text-center">{i + 1}</span>
                  {avatar ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={avatar} alt="" className="w-8 h-8 rounded-full object-cover flex-shrink-0" />
                  ) : (
                    <div className={cn('w-8 h-8 rounded-full bg-gradient-to-br flex items-center justify-center text-xs font-bold text-white flex-shrink-0', color)}>
                      {name.split(' ').map(n => n[0]).join('').slice(0, 2)}
                    </div>
                  )}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-white truncate">{name}</p>
                  </div>
                  <span className="text-xs text-lyo-400 font-medium">{formatNumber(xp)} XP</span>
                </div>
              ))}
            </div>
          </div>
        )}
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
