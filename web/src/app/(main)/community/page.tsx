'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Calendar, LayoutList, Loader2, Map, Plus, Search, Users } from 'lucide-react'
import { useRouter } from 'next/navigation'
import PostCard from '@/components/community/PostCard'
import GroupCard from '@/components/community/GroupCard'
import CreatePostModal, { type PostFormData } from '@/components/community/CreatePostModal'
import CreateCommunityItemModal from '@/components/community/CreateCommunityItemModal'
import CommunityEventMap from '@/components/community/CommunityEventMap'
import { useApi } from '@/hooks/use-api'
import { useSyncEvents } from '@/hooks/use-sync'
import { api, adaptUser } from '@/lib/api'
import { cn, formatNumber } from '@/lib/utils'
import type { CommunityPost, Group, User } from '@/types'

type CommunityTab = 'Posts' | 'Events'
type EventFilter = 'all' | 'event' | 'group'
type ViewMode = 'list' | 'map'

interface EventItem {
  id: string
  title: string
  description: string
  date: string
  location: string
  attendees: number
  isAttending: boolean
  latitude?: number
  longitude?: number
}

const DEFAULT_ADMIN: User = {
  id: '0', email: '', displayName: 'Community host', username: 'host', avatar: '', bio: '', role: 'admin',
  interests: [], learningGoals: [], streak: 0, xp: 0, level: 1, coursesCompleted: 0,
  followersCount: 0, followingCount: 0, createdAt: new Date().toISOString(), isPremium: false,
}

function mapPost(raw: Record<string, unknown>): CommunityPost {
  const postType = String(raw.post_type ?? 'text')
  const type: CommunityPost['type'] = postType === 'question_discussion'
    ? 'question'
    : postType === 'study_tip' ? 'study_tip' : 'post'
  const author: User = {
    ...DEFAULT_ADMIN,
    id: String(raw.author_id ?? ''),
    displayName: (raw.author_name as string) || 'Member',
    username: (raw.author_name as string) || 'member',
    avatar: (raw.author_avatar as string) || '',
    level: (raw.author_level as number) ?? 1,
    role: 'student',
    createdAt: (raw.created_at as string) || new Date().toISOString(),
  }
  const tags = (raw.tags as string[]) || []
  return {
    id: String(raw.id ?? ''), author, type, title: '', content: (raw.content as string) || '',
    images: (raw.media_urls as string[]) || [], tags, category: tags[0] ?? 'General',
    likes: (raw.like_count as number) ?? 0, comments: (raw.comment_count as number) ?? 0, views: 0,
    isLiked: (raw.has_liked as boolean) ?? false, isBookmarked: (raw.has_bookmarked as boolean) ?? false,
    isPinned: (raw.is_pinned as boolean) ?? false, createdAt: (raw.created_at as string) || new Date().toISOString(),
  }
}

function mapGroup(raw: Record<string, unknown>): Group {
  const rawAdmin = (raw.host as Record<string, unknown>) || (raw.admin as Record<string, unknown>) || {}
  return {
    id: String(raw.id ?? ''), name: (raw.name as string) || 'Study group',
    description: (raw.description as string) || '', coverImage: '', icon: '👥',
    memberCount: (raw.member_count as number) ?? 0,
    category: (raw.category as string) || (raw.subject as string) || 'General',
    isJoined: (raw.is_member as boolean) ?? (raw.is_joined as boolean) ?? false,
    isPrivate: String(raw.privacy ?? '') === 'private',
    admin: rawAdmin.id ? adaptUser(rawAdmin) : DEFAULT_ADMIN,
    recentActivity: '', createdAt: (raw.created_at as string) || new Date().toISOString(),
  }
}

function mapEvent(raw: Record<string, unknown>, index: number): EventItem {
  return {
    id: String(raw.id ?? `event-${index}`), title: (raw.title as string) || 'Community event',
    description: (raw.description as string) || '', date: (raw.start_time as string) || '',
    location: (raw.location as string) || ((raw.meeting_url as string) ? 'Online' : 'Location TBA'),
    attendees: (raw.attendee_count as number) ?? 0, isAttending: raw.user_attendance_status != null,
    latitude: Number.isFinite(Number(raw.latitude ?? raw.lat)) ? Number(raw.latitude ?? raw.lat) : undefined,
    longitude: Number.isFinite(Number(raw.longitude ?? raw.lng)) ? Number(raw.longitude ?? raw.lng) : undefined,
  }
}

function Loading({ label }: { label: string }) {
  return <div className="flex items-center justify-center gap-2 py-14 text-sm text-white/50"><Loader2 className="h-5 w-5 animate-spin text-lyo-400" />{label}</div>
}

export default function CommunityPage() {
  const router = useRouter()
  const [tab, setTab] = useState<CommunityTab>('Posts')
  const [eventFilter, setEventFilter] = useState<EventFilter>('all')
  const [viewMode, setViewMode] = useState<ViewMode>('map')
  const [query, setQuery] = useState('')
  const [showCreatePost, setShowCreatePost] = useState(false)
  const [showCreateItem, setShowCreateItem] = useState(false)
  const [rsvpBusy, setRsvpBusy] = useState<Set<string>>(new Set())

  const feed = useApi(() => api.community.posts(1, 20), [])
  const groupRequest = useApi(() => api.community.groups(), [])
  const eventRequest = useApi(() => api.community.events(), [])
  const posts = (feed.data?.items ?? []).map(mapPost)
  const groups = (groupRequest.data ?? []).map(mapGroup)
  const events = (eventRequest.data ?? []).map(mapEvent)

  useSyncEvents(
    useCallback(() => { feed.refetch(); groupRequest.refetch(); eventRequest.refetch() }, [feed.refetch, groupRequest.refetch, eventRequest.refetch]),
    ['context_updated'],
  )

  // People search goes to the backend (/api/v1/search) — other users are not
  // in the locally loaded events/groups data.
  const [people, setPeople] = useState<Array<{ id: number; username: string; name: string; avatar_url: string | null }>>([])
  useEffect(() => {
    const q = query.trim()
    if (q.length < 2) { setPeople([]); return }
    const timer = setTimeout(() => {
      api.search.query(q, 'users', 6).then((result) => setPeople(result.users)).catch(() => setPeople([]))
    }, 250)
    return () => clearTimeout(timer)
  }, [query])

  const normalizedQuery = query.trim().toLowerCase()
  const filteredGroups = useMemo(
    () => groups.filter((group) => !normalizedQuery || `${group.name} ${group.description}`.toLowerCase().includes(normalizedQuery)),
    [groups, normalizedQuery],
  )
  const filteredEvents = useMemo(
    () => events.filter((event) => !normalizedQuery || `${event.title} ${event.description} ${event.location}`.toLowerCase().includes(normalizedQuery)),
    [events, normalizedQuery],
  )

  const createPost = async (data: PostFormData) => {
    await api.community.createPost({ content: data.content, tags: data.tags, post_type: data.type })
    await feed.refetch()
  }

  const toggleRsvp = async (event: EventItem) => {
    if (rsvpBusy.has(event.id)) return
    setRsvpBusy((current) => new Set(current).add(event.id))
    try {
      if (event.isAttending) await api.community.unattendEvent(event.id)
      else await api.community.attendEvent(event.id)
      await eventRequest.refetch()
    } finally {
      setRsvpBusy((current) => { const next = new Set(current); next.delete(event.id); return next })
    }
  }

  const eventCard = (event: EventItem, compact = false) => (
    <article key={event.id} className="rounded-2xl border border-white/10 bg-white/5 p-4 transition hover:border-white/20">
      <div className="flex items-start gap-3">
        <div className="rounded-xl bg-lyo-500/15 p-2.5 text-lyo-300"><Calendar className="h-5 w-5" /></div>
        <div className="min-w-0 flex-1">
          <h3 className="truncate font-semibold text-white">{event.title}</h3>
          <p className="mt-1 text-xs text-white/45">{event.date ? new Date(event.date).toLocaleString() : 'Time TBA'}</p>
          <p className="mt-1 truncate text-xs text-white/45">{event.location}</p>
          {!compact && event.description && <p className="mt-2 line-clamp-2 text-sm text-white/60">{event.description}</p>}
        </div>
      </div>
      <div className="mt-3 flex items-center justify-between border-t border-white/5 pt-3">
        <span className="flex items-center gap-1.5 text-xs text-white/45"><Users className="h-3.5 w-3.5" />{formatNumber(event.attendees)} going</span>
        <button onClick={() => toggleRsvp(event)} disabled={rsvpBusy.has(event.id)} className={cn('rounded-lg px-3 py-1.5 text-xs font-semibold transition disabled:opacity-50', event.isAttending ? 'border border-emerald-500/30 bg-emerald-500/10 text-emerald-300' : 'bg-lyo-500 text-white')}>
          {rsvpBusy.has(event.id) ? 'Updating…' : event.isAttending ? 'Going ✓' : 'RSVP'}
        </button>
      </div>
    </article>
  )

  return (
    <div className="space-y-5">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div><h1 className="text-2xl font-semibold text-white md:text-3xl">Community</h1><p className="mt-1 text-sm text-white/45">One shared community on every device.</p></div>
        <button onClick={() => tab === 'Posts' ? setShowCreatePost(true) : setShowCreateItem(true)} className="flex items-center gap-2 rounded-xl bg-lyo-500 px-4 py-2.5 text-sm font-semibold text-white shadow-lg shadow-lyo-500/20 hover:bg-lyo-400">
          <Plus className="h-4 w-4" />{tab === 'Posts' ? 'Create post' : 'Create event or group'}
        </button>
      </header>

      <nav aria-label="Community sections" className="grid grid-cols-2 gap-1 rounded-xl border border-white/10 bg-white/5 p-1">
        {(['Posts', 'Events'] as const).map((item) => <button key={item} onClick={() => setTab(item)} className={cn('rounded-lg px-4 py-2.5 text-sm font-medium transition', tab === item ? 'bg-lyo-500 text-white' : 'text-white/55 hover:bg-white/10 hover:text-white')}>{item}</button>)}
      </nav>

      {tab === 'Posts' ? (
        <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,820px)_minmax(280px,1fr)]">
          <main className="min-w-0 space-y-4">
            {feed.isLoading && <Loading label="Loading posts…" />}
            {feed.error && <p className="rounded-xl border border-red-500/20 bg-red-500/10 p-4 text-sm text-red-300">{feed.error}</p>}
            {!feed.isLoading && !feed.error && posts.length === 0 && <button onClick={() => setShowCreatePost(true)} className="w-full rounded-2xl border border-dashed border-white/15 px-6 py-16 text-center text-sm text-white/45 hover:border-lyo-500/50 hover:text-white">No posts yet. Create the first one.</button>}
            {posts.map((post) => <PostCard key={post.id} post={post} onClick={() => router.push(`/community/${post.id}`)} />)}
          </main>

          <aside className="space-y-4 xl:sticky xl:top-2">
            <section className="rounded-2xl border border-white/10 bg-[var(--surface)] p-4">
              <div className="mb-3 flex items-center justify-between"><h2 className="font-semibold text-white">Upcoming events</h2><button onClick={() => setTab('Events')} className="text-xs text-lyo-300 hover:text-white">View all</button></div>
              <div className="space-y-3">{events.slice(0, 3).map((event) => eventCard(event, true))}{!eventRequest.isLoading && events.length === 0 && <p className="py-5 text-center text-sm text-white/35">No upcoming events.</p>}</div>
            </section>
            <section className="rounded-2xl border border-white/10 bg-[var(--surface)] p-4">
              <div className="mb-3 flex items-center justify-between"><h2 className="font-semibold text-white">Study groups</h2><button onClick={() => { setTab('Events'); setEventFilter('group'); setViewMode('list') }} className="text-xs text-lyo-300 hover:text-white">View all</button></div>
              <div className="space-y-2">{groups.slice(0, 4).map((group) => <div key={group.id} className="flex items-center gap-3 rounded-xl border border-white/5 bg-white/5 p-3"><span className="text-lg">{group.icon}</span><div className="min-w-0 flex-1"><p className="truncate text-sm font-medium text-white">{group.name}</p><p className="text-xs text-white/40">{formatNumber(group.memberCount)} members</p></div></div>)}{!groupRequest.isLoading && groups.length === 0 && <p className="py-5 text-center text-sm text-white/35">No study groups yet.</p>}</div>
            </section>
          </aside>
        </div>
      ) : (
        <section className="space-y-4">
          <div className="flex flex-col gap-3 rounded-2xl border border-white/10 bg-[var(--surface)] p-3 lg:flex-row lg:items-center">
            <label className="relative min-w-0 flex-1"><Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/35" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search events and groups" className="w-full rounded-xl border border-white/10 bg-white/5 py-2.5 pl-9 pr-3 text-sm text-white placeholder:text-white/30 focus:border-lyo-500 focus:outline-none" /></label>
            <div className="grid grid-cols-3 gap-1 rounded-xl bg-white/5 p-1">{(['all', 'event', 'group'] as const).map((filter) => <button key={filter} onClick={() => { setEventFilter(filter); if (filter === 'group') setViewMode('list') }} className={cn('rounded-lg px-3 py-2 text-xs font-medium capitalize transition', eventFilter === filter ? 'bg-lyo-500 text-white' : 'text-white/50 hover:text-white')}>{filter === 'all' ? 'All' : filter === 'event' ? 'Events' : 'Groups'}</button>)}</div>
            <div className="grid grid-cols-2 gap-1 rounded-xl bg-white/5 p-1">
              <button onClick={() => setViewMode('list')} className={cn('flex items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-medium', viewMode === 'list' ? 'bg-white/10 text-white' : 'text-white/45')}><LayoutList className="h-4 w-4" />List</button>
              <button onClick={() => setViewMode('map')} disabled={eventFilter === 'group'} title={eventFilter === 'group' ? 'Groups do not have map coordinates' : undefined} className={cn('flex items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-medium disabled:cursor-not-allowed disabled:opacity-30', viewMode === 'map' ? 'bg-white/10 text-white' : 'text-white/45')}><Map className="h-4 w-4" />Map</button>
            </div>
          </div>

          {people.length > 0 && (
            <section aria-label="People" className="rounded-2xl border border-white/10 bg-[var(--surface)] p-4">
              <h2 className="mb-3 text-sm font-semibold text-white">People</h2>
              <div className="flex flex-wrap gap-2">
                {people.map((person) => (
                  <button key={person.id} onClick={() => router.push(`/profile/${person.id}`)} className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-left transition hover:border-lyo-500/50">
                    <span className="flex h-8 w-8 items-center justify-center overflow-hidden rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple text-xs font-bold text-white">
                      {person.avatar_url
                        // eslint-disable-next-line @next/next/no-img-element
                        ? <img src={person.avatar_url} alt="" className="h-full w-full object-cover" />
                        : (person.name[0] || 'M').toUpperCase()}
                    </span>
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-medium text-white">{person.name}</span>
                      <span className="block truncate text-xs text-white/40">@{person.username}</span>
                    </span>
                  </button>
                ))}
              </div>
            </section>
          )}

          {(eventRequest.isLoading || groupRequest.isLoading) && <Loading label="Loading Community…" />}
          {(eventRequest.error || groupRequest.error) && <p className="rounded-xl border border-red-500/20 bg-red-500/10 p-4 text-sm text-red-300">{eventRequest.error || groupRequest.error}</p>}

          {!eventRequest.isLoading && !groupRequest.isLoading && viewMode === 'map' && eventFilter !== 'group' && (
            <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1.45fr)_minmax(340px,.55fr)]">
              <CommunityEventMap events={filteredEvents} />
              <div className="max-h-[640px] space-y-3 overflow-y-auto pr-1">{filteredEvents.map((event) => eventCard(event))}</div>
            </div>
          )}

          {!eventRequest.isLoading && !groupRequest.isLoading && viewMode === 'list' && (
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
              {eventFilter !== 'group' && filteredEvents.map((event) => eventCard(event))}
              {eventFilter !== 'event' && filteredGroups.map((group) => <GroupCard key={group.id} group={group} />)}
            </div>
          )}

          {!eventRequest.isLoading && !groupRequest.isLoading && (
            (eventFilter === 'event' && filteredEvents.length === 0)
            || (eventFilter === 'group' && filteredGroups.length === 0)
            || (eventFilter === 'all' && filteredEvents.length === 0 && filteredGroups.length === 0)
          ) && <p className="rounded-2xl border border-dashed border-white/15 py-16 text-center text-sm text-white/40">No matching Community items.</p>}
        </section>
      )}

      {showCreatePost && <CreatePostModal onClose={() => setShowCreatePost(false)} onSubmit={createPost} />}
      {showCreateItem && <CreateCommunityItemModal onClose={() => setShowCreateItem(false)} onCreated={(type) => { if (type === 'event') eventRequest.refetch(); else groupRequest.refetch() }} />}
    </div>
  )
}
