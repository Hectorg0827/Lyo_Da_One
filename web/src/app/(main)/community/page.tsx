'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Bookmark,
  Bot,
  Calendar,
  ExternalLink,
  GraduationCap,
  LayoutList,
  Landmark,
  Library,
  Loader2,
  LocateFixed,
  Map as MapIcon,
  MapPin,
  MessageCircle,
  Plus,
  Search,
  Users,
  X,
} from 'lucide-react'
import { useRouter } from 'next/navigation'
import PostCard from '@/components/community/PostCard'
import CreatePostModal, { type PostFormData } from '@/components/community/CreatePostModal'
import CreateCommunityItemModal from '@/components/community/CreateCommunityItemModal'
import CommunityEventMap from '@/components/community/CommunityEventMap'
import { useApi } from '@/hooks/use-api'
import { useSyncEvents } from '@/hooks/use-sync'
import { api } from '@/lib/api'
import { cn, formatNumber } from '@/lib/utils'
import type {
  CommunityPost,
  Group,
  LearningNode,
  LearningNodeCategory,
  User,
} from '@/types'

type CommunityTab = 'Around Me' | 'My Community' | 'Activity'
type ViewMode = 'map' | 'list'

const DEFAULT_CENTER = { latitude: 40.7128, longitude: -74.006 }

const DEFAULT_ADMIN: User = {
  id: '0', email: '', displayName: 'Community host', username: 'host', avatar: '', bio: '', role: 'admin',
  interests: [], learningGoals: [], streak: 0, xp: 0, level: 1, coursesCompleted: 0,
  followersCount: 0, followingCount: 0, createdAt: new Date().toISOString(), isPremium: false,
}

const categoryMeta: Record<LearningNodeCategory, { label: string; icon: typeof Calendar; color: string }> = {
  event: { label: 'Events', icon: Calendar, color: 'text-orange-300' },
  workshop: { label: 'Workshops', icon: GraduationCap, color: 'text-amber-300' },
  class: { label: 'Classes', icon: GraduationCap, color: 'text-violet-300' },
  study_group: { label: 'Study groups', icon: Users, color: 'text-blue-300' },
  tutor: { label: 'Tutors', icon: Users, color: 'text-pink-300' },
  library: { label: 'Libraries', icon: Library, color: 'text-emerald-300' },
  museum: { label: 'Museums', icon: Landmark, color: 'text-cyan-300' },
  educational_center: { label: 'Learning centers', icon: GraduationCap, color: 'text-indigo-300' },
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
  return {
    id: String(raw.id ?? ''),
    name: (raw.name as string) || 'Study group',
    description: (raw.description as string) || '',
    coverImage: (raw.image_url as string) || '',
    icon: '👥',
    memberCount: (raw.member_count as number) ?? 0,
    category: (raw.category as string) || 'Study group',
    isJoined: (raw.is_member as boolean) ?? true,
    isPrivate: String(raw.privacy ?? '') === 'private',
    admin: DEFAULT_ADMIN,
    recentActivity: (raw.location as string) || ((raw.is_online as boolean) ? 'Online' : ''),
    createdAt: (raw.created_at as string) || new Date().toISOString(),
  }
}

function mapEvent(raw: Record<string, unknown>) {
  return {
    id: String(raw.id ?? ''),
    title: (raw.title as string) || 'Community event',
    description: (raw.description as string) || '',
    date: (raw.start_time as string) || '',
    location: (raw.location as string) || ((raw.is_online as boolean) ? 'Online' : 'Location TBA'),
    attendees: (raw.attendee_count as number) ?? 0,
    isAttending: true,
  }
}

function Loading({ label }: { label: string }) {
  return <div className="flex items-center justify-center gap-2 py-14 text-sm text-white/50"><Loader2 className="h-5 w-5 animate-spin text-lyo-400" />{label}</div>
}

function nodeWhen(node: LearningNode): string | null {
  if (!node.starts_at) return node.is_online ? 'Online' : null
  return new Date(node.starts_at).toLocaleString(undefined, {
    weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  })
}

function safeWebUrl(value?: string | null): string | null {
  if (!value) return null
  try {
    const url = new URL(value)
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.toString() : null
  } catch {
    return null
  }
}

function NodeSummary({ node, selected, onClick }: { node: LearningNode; selected?: boolean; onClick: () => void }) {
  const meta = categoryMeta[node.category]
  const Icon = meta.icon
  return (
    <button
      onClick={onClick}
      className={cn(
        'w-full rounded-2xl border p-4 text-left transition',
        selected ? 'border-lyo-500 bg-lyo-500/15' : 'border-white/10 bg-white/5 hover:border-white/20 hover:bg-white/[.07]',
      )}
    >
      <div className="flex items-start gap-3">
        <span className={cn('rounded-xl bg-white/[.07] p-2.5', meta.color)}><Icon className="h-5 w-5" /></span>
        <span className="min-w-0 flex-1">
          <span className="flex items-start justify-between gap-2">
            <span className="line-clamp-2 text-sm font-semibold text-white">{node.title}</span>
            {node.is_saved && <Bookmark className="h-4 w-4 shrink-0 fill-lyo-400 text-lyo-300" />}
          </span>
          <span className="mt-1 block text-xs text-white/45">{meta.label}{node.distance_km != null ? ` · ${node.distance_km.toFixed(1)} km` : ''}</span>
          {nodeWhen(node) && <span className="mt-1 block truncate text-xs text-white/55">{nodeWhen(node)}</span>}
          {node.location_name && <span className="mt-1 block truncate text-xs text-white/40">{node.location_name}</span>}
        </span>
      </div>
    </button>
  )
}

function NodeDrawer({
  node,
  busy,
  onClose,
  onToggleSave,
  onPrimary,
  onOpenCourse,
  onAskLyo,
}: {
  node: LearningNode
  busy: boolean
  onClose: () => void
  onToggleSave: () => void
  onPrimary: () => void
  onOpenCourse: () => void
  onAskLyo: () => void
}) {
  const meta = categoryMeta[node.category]
  const Icon = meta.icon
  const meetingUrl = safeWebUrl(node.meeting_url)
  const sourceUrl = safeWebUrl(node.source_url)
  const primaryLabel = node.kind === 'event'
    ? (node.is_attending ? 'Leave event' : 'RSVP')
    : node.kind === 'study_group'
      ? (node.is_joined ? 'Leave group' : 'Join group')
      : null
  return (
    <article className="absolute inset-x-3 bottom-3 z-[500] rounded-2xl border border-white/15 bg-[#0e173d]/95 p-4 shadow-2xl backdrop-blur-xl md:inset-x-auto md:left-4 md:w-[430px]">
      <div className="flex items-start gap-3">
        <span className={cn('rounded-xl bg-white/10 p-3', meta.color)}><Icon className="h-6 w-6" /></span>
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-3">
            <div><p className="text-xs font-medium uppercase tracking-wide text-white/40">{meta.label}</p><h2 className="mt-0.5 text-lg font-semibold text-white">{node.title}</h2></div>
            <button aria-label="Close details" onClick={onClose} className="rounded-lg p-1.5 text-white/40 hover:bg-white/10 hover:text-white"><X className="h-4 w-4" /></button>
          </div>
          <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-xs text-white/50">
            {node.distance_km != null && <span>{node.distance_km.toFixed(1)} km away</span>}
            {nodeWhen(node) && <span>{nodeWhen(node)}</span>}
            {node.host && <span>by {node.host.name}</span>}
            {node.attendee_count != null && <span>{formatNumber(node.attendee_count)} going</span>}
            {node.member_count != null && <span>{formatNumber(node.member_count)} members</span>}
          </div>
        </div>
      </div>
      {node.description && <p className="mt-3 line-clamp-3 text-sm leading-relaxed text-white/65">{node.description}</p>}
      {node.location_name && <p className="mt-2 flex items-center gap-1.5 text-xs text-white/45"><MapPin className="h-3.5 w-3.5" />{node.location_name}</p>}
      <div className="mt-4 flex flex-wrap gap-2">
        {primaryLabel && <button disabled={busy} onClick={onPrimary} className="rounded-xl bg-lyo-500 px-4 py-2 text-xs font-semibold text-white disabled:opacity-50">{busy ? 'Updating…' : primaryLabel}</button>}
        <button disabled={busy} onClick={onToggleSave} className="flex items-center gap-1.5 rounded-xl border border-white/15 px-3 py-2 text-xs font-medium text-white/75 hover:bg-white/10 disabled:opacity-50"><Bookmark className={cn('h-3.5 w-3.5', node.is_saved && 'fill-current text-lyo-300')} />{node.is_saved ? 'Saved' : 'Save'}</button>
        {meetingUrl && <a href={meetingUrl} target="_blank" rel="noreferrer" className="flex items-center gap-1.5 rounded-xl border border-white/15 px-3 py-2 text-xs font-medium text-white/75 hover:bg-white/10"><ExternalLink className="h-3.5 w-3.5" />Join online</a>}
        {node.course_id && <button onClick={onOpenCourse} className="flex items-center gap-1.5 rounded-xl border border-white/15 px-3 py-2 text-xs font-medium text-white/75 hover:bg-white/10"><GraduationCap className="h-3.5 w-3.5" />Course</button>}
        <button onClick={onAskLyo} className="flex items-center gap-1.5 rounded-xl border border-white/15 px-3 py-2 text-xs font-medium text-white/75 hover:bg-white/10"><Bot className="h-3.5 w-3.5" />Ask Lyo</button>
        {sourceUrl && <a href={sourceUrl} target="_blank" rel="noreferrer" className="flex items-center gap-1.5 rounded-xl border border-white/15 px-3 py-2 text-xs font-medium text-white/75 hover:bg-white/10"><ExternalLink className="h-3.5 w-3.5" />Details</a>}
      </div>
    </article>
  )
}

export default function CommunityPage() {
  const router = useRouter()
  const [tab, setTab] = useState<CommunityTab>('Around Me')
  const [viewMode, setViewMode] = useState<ViewMode>('map')
  const [center, setCenter] = useState(DEFAULT_CENTER)
  const [locationLabel, setLocationLabel] = useState('New York City')
  const [query, setQuery] = useState('')
  const [debouncedQuery, setDebouncedQuery] = useState('')
  const [categoryKey, setCategoryKey] = useState('')
  const [selectedKey, setSelectedKey] = useState<string | null>(null)
  const [showCreatePost, setShowCreatePost] = useState(false)
  const [showCreateItem, setShowCreateItem] = useState(false)
  const [busyKeys, setBusyKeys] = useState<Set<string>>(new Set())
  const [people, setPeople] = useState<Array<{ id: number; username: string; name: string; avatar_url: string | null }>>([])

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedQuery(query.trim()), 300)
    return () => clearTimeout(timer)
  }, [query])

  const locate = useCallback(() => {
    if (!navigator.geolocation) return
    setLocationLabel('Locating…')
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        setCenter({ latitude: coords.latitude, longitude: coords.longitude })
        setLocationLabel('Current location')
      },
      () => setLocationLabel('New York City'),
      { enableHighAccuracy: false, maximumAge: 300_000, timeout: 8_000 },
    )
  }, [])

  useEffect(() => { locate() }, [locate])

  const selectedCategories = useMemo(
    () => categoryKey ? categoryKey.split(',') as LearningNodeCategory[] : undefined,
    [categoryKey],
  )
  const nearby = useApi(
    () => api.community.nearby({
      latitude: center.latitude,
      longitude: center.longitude,
      categories: selectedCategories,
      query: debouncedQuery,
      radiusKm: 20,
      includeOnline: true,
      includeInstitutions: true,
      limit: 150,
    }),
    [center.latitude, center.longitude, categoryKey, debouncedQuery],
  )
  const myCommunity = useApi(() => api.community.me(), [])
  const feed = useApi(() => api.community.posts(1, 20), [])

  const refreshCommunity = useCallback(() => {
    nearby.refetch()
    myCommunity.refetch()
    feed.refetch()
  }, [nearby.refetch, myCommunity.refetch, feed.refetch])

  useSyncEvents(refreshCommunity, ['community_updated', 'context_updated'])
  useEffect(() => {
    const refreshOnFocus = () => { nearby.refetch(); myCommunity.refetch() }
    window.addEventListener('focus', refreshOnFocus)
    return () => window.removeEventListener('focus', refreshOnFocus)
  }, [nearby.refetch, myCommunity.refetch])

  useEffect(() => {
    const search = debouncedQuery
    if (search.length < 2) { setPeople([]); return }
    api.search.query(search, 'users', 6).then((result) => setPeople(result.users)).catch(() => setPeople([]))
  }, [debouncedQuery])

  const nodes = nearby.data?.items ?? []
  const selectedNode = selectedKey
    ? nodes.find((node) => node.key === selectedKey)
      ?? myCommunity.data?.saved_nodes.find((node) => node.key === selectedKey)
      ?? null
    : null
  const selectNode = useCallback((node: LearningNode) => setSelectedKey(node.key), [])

  const toggleCategory = (category: LearningNodeCategory) => {
    const current = new Set(selectedCategories ?? [])
    if (current.has(category)) current.delete(category)
    else current.add(category)
    setCategoryKey(Array.from(current).sort().join(','))
    setSelectedKey(null)
  }

  const withBusy = async (key: string, action: () => Promise<unknown>) => {
    if (busyKeys.has(key)) return
    setBusyKeys((current) => new Set(current).add(key))
    try {
      await action()
      nearby.refetch()
      myCommunity.refetch()
    } finally {
      setBusyKeys((current) => { const next = new Set(current); next.delete(key); return next })
    }
  }

  const toggleSave = (node: LearningNode) => withBusy(node.key, () => node.is_saved
    ? api.community.unsaveNode(node.kind, node.id)
    : api.community.saveNode(node))

  const primaryAction = (node: LearningNode) => withBusy(node.key, async () => {
    if (node.kind === 'event') {
      if (node.is_attending) await api.community.unattendEvent(node.id)
      else await api.community.attendEvent(node.id)
    } else if (node.kind === 'study_group') {
      if (node.is_joined) await api.community.leaveGroup(node.id)
      else await api.community.joinGroup(node.id)
    }
  })

  const createPost = async (data: PostFormData) => {
    await api.community.createPost({ content: data.content, tags: data.tags, post_type: data.type })
    feed.refetch()
  }

  const posts = (feed.data?.items ?? []).map(mapPost)
  const joinedGroups = (myCommunity.data?.joined_groups ?? []).map(mapGroup)
  const attendingEvents = (myCommunity.data?.attending_events ?? []).map(mapEvent)

  return (
    <div className="space-y-4">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="font-rounded text-2xl font-semibold text-white md:text-3xl">Community</h1>
          <p className="mt-1 text-sm text-white/45">Learn from the world and the people around you.</p>
        </div>
        <button onClick={() => tab === 'Activity' ? setShowCreatePost(true) : setShowCreateItem(true)} className="flex items-center gap-2 rounded-xl bg-lyo-500 px-4 py-2.5 text-sm font-semibold text-white shadow-lg shadow-lyo-500/20 hover:bg-lyo-400">
          <Plus className="h-4 w-4" />{tab === 'Activity' ? 'Create post' : 'Create learning node'}
        </button>
      </header>

      <nav aria-label="Community sections" className="grid grid-cols-3 gap-1 rounded-xl border border-white/10 bg-white/5 p-1">
        {(['Around Me', 'My Community', 'Activity'] as const).map((item) => (
          <button key={item} onClick={() => setTab(item)} className={cn('rounded-lg px-2 py-2.5 text-xs font-medium transition sm:px-4 sm:text-sm', tab === item ? 'bg-lyo-500 text-white' : 'text-white/55 hover:bg-white/10 hover:text-white')}>{item}</button>
        ))}
      </nav>

      {tab === 'Around Me' && (
        <section className="space-y-3">
          <div className="glass-card space-y-3 p-3">
            <div className="flex flex-col gap-2 lg:flex-row lg:items-center">
              <label className="relative min-w-0 flex-1"><Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/35" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search libraries, classes, tutors, events…" className="w-full rounded-xl border border-white/10 bg-white/5 py-2.5 pl-9 pr-3 text-sm text-white placeholder:text-white/30 focus:border-lyo-500 focus:outline-none" /></label>
              <button onClick={locate} className="flex items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-xs text-white/60 hover:text-white"><LocateFixed className="h-4 w-4 text-lyo-300" />{locationLabel}</button>
              <div className="grid grid-cols-2 gap-1 rounded-xl bg-white/5 p-1">
                <button onClick={() => setViewMode('map')} className={cn('flex items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-medium', viewMode === 'map' ? 'bg-white/10 text-white' : 'text-white/45')}><MapIcon className="h-4 w-4" />Map</button>
                <button onClick={() => setViewMode('list')} className={cn('flex items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-medium', viewMode === 'list' ? 'bg-white/10 text-white' : 'text-white/45')}><LayoutList className="h-4 w-4" />List</button>
              </div>
            </div>
            <div className="flex gap-2 overflow-x-auto pb-1 no-scrollbar">
              <button onClick={() => setCategoryKey('')} className={cn('shrink-0 rounded-full border px-3 py-1.5 text-xs font-medium', !categoryKey ? 'border-lyo-400 bg-lyo-500/20 text-white' : 'border-white/10 text-white/50 hover:text-white')}>All learning</button>
              {(Object.keys(categoryMeta) as LearningNodeCategory[]).map((category) => {
                const active = selectedCategories?.includes(category) ?? false
                const Icon = categoryMeta[category].icon
                return <button key={category} onClick={() => toggleCategory(category)} className={cn('flex shrink-0 items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-medium', active ? 'border-lyo-400 bg-lyo-500/20 text-white' : 'border-white/10 text-white/50 hover:text-white')}><Icon className="h-3.5 w-3.5" />{categoryMeta[category].label}</button>
              })}
            </div>
          </div>

          {nearby.isLoading && !nearby.data && <Loading label="Finding learning around you…" />}
          {nearby.error && <p className="rounded-xl border border-red-500/20 bg-red-500/10 p-4 text-sm text-red-300">{nearby.error}</p>}

          {viewMode === 'map' && nearby.data && (
            <div className="grid items-start gap-3 xl:grid-cols-[minmax(0,1.6fr)_360px]">
              <div className="relative overflow-hidden rounded-2xl border border-white/10 shadow-2xl">
                <CommunityEventMap nodes={nodes} center={center} selectedKey={selectedKey} onSelect={selectNode} />
                <div className="absolute left-3 top-3 z-[500] rounded-xl border border-white/15 bg-[#0e173d]/90 px-3 py-2 text-xs text-white/65 backdrop-blur-md"><span className="font-semibold text-white">{nodes.length}</span> learning opportunities nearby</div>
                {selectedNode && <NodeDrawer node={selectedNode} busy={busyKeys.has(selectedNode.key)} onClose={() => setSelectedKey(null)} onToggleSave={() => toggleSave(selectedNode)} onPrimary={() => primaryAction(selectedNode)} onOpenCourse={() => router.push(`/courses/${selectedNode.course_id}`)} onAskLyo={() => router.push('/chat')} />}
              </div>
              <aside className="max-h-[680px] space-y-2 overflow-y-auto pr-1">
                {nodes.map((node) => <NodeSummary key={node.key} node={node} selected={node.key === selectedKey} onClick={() => setSelectedKey(node.key)} />)}
                {!nodes.length && <p className="rounded-2xl border border-dashed border-white/15 p-10 text-center text-sm text-white/40">No matching learning nodes in this area yet.</p>}
              </aside>
            </div>
          )}

          {viewMode === 'list' && nearby.data && (
            <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">{nodes.map((node) => <NodeSummary key={node.key} node={node} onClick={() => { setSelectedKey(node.key); setViewMode('map') }} />)}</div>
          )}

          {people.length > 0 && (
            <section className="rounded-2xl border border-white/10 bg-[var(--surface)] p-4">
              <h2 className="mb-3 text-sm font-semibold text-white">People</h2>
              <div className="flex flex-wrap gap-2">{people.map((person) => <button key={person.id} onClick={() => router.push(`/profile/${person.id}`)} className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-left hover:border-lyo-500/50"><span className="grid h-8 w-8 place-items-center overflow-hidden rounded-full bg-gradient-to-br from-lyo-500 to-accent-purple text-xs font-bold text-white">{person.avatar_url ? <img src={person.avatar_url} alt="" className="h-full w-full object-cover" /> : (person.name[0] || 'M').toUpperCase()}</span><span><span className="block text-sm font-medium text-white">{person.name}</span><span className="block text-xs text-white/40">@{person.username}</span></span></button>)}</div>
            </section>
          )}
        </section>
      )}

      {tab === 'My Community' && (
        <section className="space-y-6">
          {myCommunity.isLoading && !myCommunity.data && <Loading label="Loading your Community…" />}
          {myCommunity.error && <p className="rounded-xl border border-red-500/20 bg-red-500/10 p-4 text-sm text-red-300">{myCommunity.error}</p>}
          {myCommunity.data && <>
            <section><div className="mb-3 flex items-center gap-2"><Bookmark className="h-5 w-5 text-lyo-300" /><h2 className="font-semibold text-white">Saved learning</h2><span className="text-xs text-white/35">Synced to your Lyo account</span></div><div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">{myCommunity.data.saved_nodes.map((node) => <NodeSummary key={node.key} node={node} onClick={() => { setTab('Around Me'); setSelectedKey(node.key) }} />)}{!myCommunity.data.saved_nodes.length && <p className="rounded-2xl border border-dashed border-white/15 p-8 text-sm text-white/40">Save a place or opportunity from the map and it will appear here on every device.</p>}</div></section>
            <div className="grid gap-6 xl:grid-cols-2">
              <section><div className="mb-3 flex items-center gap-2"><Users className="h-5 w-5 text-blue-300" /><h2 className="font-semibold text-white">Joined groups</h2></div><div className="space-y-3">{joinedGroups.map((group) => <article key={group.id} className="rounded-2xl border border-white/10 bg-white/5 p-4"><h3 className="font-semibold text-white">{group.name}</h3><p className="mt-1 line-clamp-2 text-sm text-white/55">{group.description}</p><p className="mt-2 text-xs text-white/40">{formatNumber(group.memberCount)} members{group.recentActivity ? ` · ${group.recentActivity}` : ''}</p></article>)}{!joinedGroups.length && <p className="text-sm text-white/40">You have not joined a study group yet.</p>}</div></section>
              <section><div className="mb-3 flex items-center gap-2"><Calendar className="h-5 w-5 text-orange-300" /><h2 className="font-semibold text-white">Your events</h2></div><div className="space-y-3">{attendingEvents.map((event) => <article key={event.id} className="rounded-2xl border border-white/10 bg-white/5 p-4"><h3 className="font-semibold text-white">{event.title}</h3><p className="mt-1 text-xs text-white/45">{event.date ? new Date(event.date).toLocaleString() : 'Time TBA'} · {event.location}</p><p className="mt-2 line-clamp-2 text-sm text-white/55">{event.description}</p></article>)}{!attendingEvents.length && <p className="text-sm text-white/40">No upcoming events on your account.</p>}</div></section>
            </div>
            <section><div className="mb-3 flex items-center gap-2"><MessageCircle className="h-5 w-5 text-emerald-300" /><h2 className="font-semibold text-white">People you follow</h2></div><div className="flex flex-wrap gap-3">{myCommunity.data.following.map((person) => <button key={person.id} onClick={() => router.push(`/profile/${person.id}`)} className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-3 py-2 hover:border-lyo-500/50"><span className="grid h-9 w-9 place-items-center overflow-hidden rounded-full bg-lyo-500 text-sm font-bold text-white">{person.avatar ? <img src={person.avatar} alt="" className="h-full w-full object-cover" /> : person.name.slice(0, 1).toUpperCase()}</span><span className="text-sm font-medium text-white">{person.name}</span></button>)}{!myCommunity.data.following.length && <p className="text-sm text-white/40">People you follow will appear here.</p>}</div></section>
          </>}
        </section>
      )}

      {tab === 'Activity' && (
        <section className="mx-auto max-w-3xl space-y-4">
          {feed.isLoading && <Loading label="Loading Community activity…" />}
          {feed.error && <p className="rounded-xl border border-red-500/20 bg-red-500/10 p-4 text-sm text-red-300">{feed.error}</p>}
          {!feed.isLoading && !feed.error && !posts.length && <button onClick={() => setShowCreatePost(true)} className="w-full rounded-2xl border border-dashed border-white/15 px-6 py-16 text-center text-sm text-white/45 hover:border-lyo-500/50 hover:text-white">No activity yet. Create the first post.</button>}
          {posts.map((post) => <PostCard key={post.id} post={post} onClick={() => router.push(`/community/${post.id}`)} />)}
        </section>
      )}

      {showCreatePost && <CreatePostModal onClose={() => setShowCreatePost(false)} onSubmit={createPost} />}
      {showCreateItem && <CreateCommunityItemModal onClose={() => setShowCreateItem(false)} onCreated={() => { nearby.refetch(); myCommunity.refetch() }} />}
    </div>
  )
}
