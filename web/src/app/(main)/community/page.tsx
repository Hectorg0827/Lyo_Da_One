'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import {
  Bookmark,
  Calendar,
  ChevronRight,
  GraduationCap,
  Link2,
  Loader2,
  LocateFixed,
  MailOpen,
  MapPin,
  MessageCircle,
  Plus,
  RotateCw,
  Search,
  Star,
  Ticket,
  Users,
  X,
} from 'lucide-react'
import PostCard from '@/components/community/PostCard'
import CreatePostModal, { type PostFormData } from '@/components/community/CreatePostModal'
import CreateCommunityItemModal from '@/components/community/CreateCommunityItemModal'
import CommunityEventMap, { markerColors, type MapView } from '@/components/community/CommunityEventMap'
import CommunityResults, { NodeRow, ResultSkeleton, StateMessage } from '@/components/community/CommunityResults'
import NodePreview from '@/components/community/NodePreview'
import { BottomSheet, CommunitySearchBar, FilterChips, type SheetState } from '@/components/community/CommunityControls'
import { useApi } from '@/hooks/use-api'
import { useSyncEvents } from '@/hooks/use-sync'
import { useCommunityActions } from '@/hooks/use-community-actions'
import { api } from '@/lib/api'
import { FRESH_MS, nearbyCacheKey, readNearby, writeNearby } from '@/lib/community-cache'
import {
  CATEGORY_LABELS,
  DEFAULT_CENTER,
  DEFAULT_RADIUS_KM,
  NEARBY_RADIUS_KM,
  detailPath,
  inviteTokenFromText,
  invitePath,
  filtersToQuery,
  friendlyError,
  shouldOfferAreaSearch,
  toggleFilter,
  type FilterId,
  type FriendlyError,
  type SearchArea,
} from '@/lib/community-contract.mjs'
import { cn } from '@/lib/utils'
import type { CommunityPost, LearningNode, LearningNodeCategory, NearbyLearningResponse, User } from '@/types'

type CommunityTab = 'Around Me' | 'My Community' | 'Activity'
type LocationState = 'locating' | 'granted' | 'denied' | 'unavailable'
type Area = SearchArea & { label: string }

const TABS: CommunityTab[] = ['Around Me', 'My Community', 'Activity']

// The map key, in marker order. Every category the backend can return.
const MAP_KEY: LearningNodeCategory[] = [
  'event',
  'workshop',
  'class',
  'study_group',
  'tutor',
  'library',
  'museum',
  'educational_center',
]

const DEFAULT_AREA: Area = {
  latitude: DEFAULT_CENTER.latitude,
  longitude: DEFAULT_CENTER.longitude,
  radiusKm: DEFAULT_RADIUS_KM,
  label: DEFAULT_CENTER.label,
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

function useIsDesktop(): boolean {
  const [desktop, setDesktop] = useState(false)
  useEffect(() => {
    const query = window.matchMedia('(min-width: 1024px)')
    const update = () => setDesktop(query.matches)
    update()
    query.addEventListener('change', update)
    return () => query.removeEventListener('change', update)
  }, [])
  return desktop
}

function TabSwitch({ tab, onChange }: { tab: CommunityTab; onChange: (tab: CommunityTab) => void }) {
  return (
    <nav aria-label="Community sections" className="grid flex-1 grid-cols-3 gap-1 rounded-2xl border border-white/10 bg-white/[0.04] p-1">
      {TABS.map((item) => (
        <button
          key={item}
          type="button"
          onClick={() => onChange(item)}
          aria-current={tab === item ? 'page' : undefined}
          className={cn(
            'min-h-[36px] whitespace-nowrap rounded-xl px-1.5 text-[13px] font-medium transition',
            tab === item ? 'bg-lyo-500 text-white shadow-sm' : 'text-white/60 hover:bg-white/10 hover:text-white',
          )}
        >
          {item}
        </button>
      ))}
    </nav>
  )
}

function CreateMenu({ onCreateGroup, onCreateTutor, onCreatePost, tab, compact = false }: {
  onCreateGroup: () => void
  onCreateTutor: () => void
  onCreatePost: () => void
  tab: CommunityTab
  compact?: boolean
}) {
  const router = useRouter()
  const [open, setOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement | null>(null)
  useEffect(() => {
    if (!open) return
    const close = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) setOpen(false)
    }
    const escape = (event: KeyboardEvent) => event.key === 'Escape' && setOpen(false)
    document.addEventListener('mousedown', close)
    document.addEventListener('keydown', escape)
    return () => {
      document.removeEventListener('mousedown', close)
      document.removeEventListener('keydown', escape)
    }
  }, [open])
  if (tab === 'Activity') {
    return (
      <button type="button" onClick={onCreatePost} className="flex h-11 shrink-0 items-center gap-1.5 rounded-2xl bg-lyo-500 px-3.5 text-sm font-semibold text-white hover:bg-lyo-400">
        <Plus className="h-4 w-4" aria-hidden="true" />
        <span>Post</span>
      </button>
    )
  }
  const items = [
    { label: 'Event or class', hint: 'Workshops, lectures, meetups', icon: Calendar, action: () => router.push('/community/events/new') },
    { label: 'Study group', hint: 'Learn together regularly', icon: Users, action: onCreateGroup },
    { label: 'Tutoring', hint: 'Offer one-to-one help', icon: GraduationCap, action: onCreateTutor },
  ]
  return (
    <div ref={menuRef} className="relative shrink-0">
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-expanded={open}
        aria-haspopup="menu"
        aria-label="Create"
        title="Create"
        className={cn(
          'flex h-11 items-center justify-center gap-1.5 rounded-2xl bg-lyo-500 text-sm font-semibold text-white shadow-lg shadow-lyo-500/20 hover:bg-lyo-400',
          compact ? 'w-11' : 'px-3.5',
        )}
      >
        <Plus className={compact ? 'h-5 w-5' : 'h-4 w-4'} aria-hidden="true" />
        {!compact && <span>Create</span>}
      </button>
      {open && (
        <div role="menu" className="absolute right-0 top-12 z-40 w-64 rounded-2xl border border-white/10 bg-[#0e173d] p-1.5 shadow-2xl">
          {items.map(({ label, hint, icon: Icon, action }) => (
            <button
              key={label}
              type="button"
              role="menuitem"
              onClick={() => {
                setOpen(false)
                action()
              }}
              className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left hover:bg-white/[0.06]"
            >
              <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/[0.06] text-lyo-300">
                <Icon className="h-5 w-5" aria-hidden="true" />
              </span>
              <span>
                <span className="block text-sm font-medium text-white">{label}</span>
                <span className="block text-xs text-white/45">{hint}</span>
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

function MapKey() {
  const [open, setOpen] = useState(false)
  return (
    <div className="pointer-events-auto">
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-expanded={open}
        className="flex h-11 items-center gap-2 rounded-2xl border border-white/10 bg-[#0e173d]/90 px-3 text-xs font-medium text-white/70 shadow-lg backdrop-blur-md hover:text-white"
      >
        <span className="flex -space-x-1" aria-hidden="true">
          {MAP_KEY.slice(0, 4).map((category) => (
            <span key={category} className="h-3 w-3 rounded-full ring-2 ring-[#0e173d]" style={{ background: markerColors[category] }} />
          ))}
        </span>
        Map key
      </button>
      {open && (
        <ul className="mt-2 grid grid-cols-2 gap-x-4 gap-y-1.5 rounded-2xl border border-white/10 bg-[#0e173d]/95 p-3 text-xs text-white/75 shadow-xl backdrop-blur-md">
          {MAP_KEY.map((category) => (
            <li key={category} className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full" style={{ background: markerColors[category] }} aria-hidden="true" />
              {CATEGORY_LABELS[category]}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export default function CommunityPage() {
  const router = useRouter()
  const isDesktop = useIsDesktop()
  const [tab, setTab] = useState<CommunityTab>('Around Me')

  // ── Where we are looking ───────────────────────────────────────────────
  const [locationState, setLocationState] = useState<LocationState>('locating')
  const [userLocation, setUserLocation] = useState<{ latitude: number; longitude: number } | null>(null)
  const [ready, setReady] = useState(false)
  const [area, setArea] = useState<Area>(DEFAULT_AREA)
  const [mapView, setMapView] = useState<MapView>({ ...DEFAULT_AREA, token: 0 })
  const [visibleArea, setVisibleArea] = useState<SearchArea | null>(null)
  const [locationNoticeDismissed, setLocationNoticeDismissed] = useState(false)

  const moveTo = useCallback((next: Area) => {
    setArea(next)
    setMapView((current) => ({ ...next, token: current.token + 1 }))
    setVisibleArea(null)
  }, [])

  const locate = useCallback((explicit: boolean) => {
    if (!navigator.geolocation) {
      setLocationState('unavailable')
      setReady(true)
      return
    }
    if (explicit) setLocationState('locating')
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        const here = { latitude: coords.latitude, longitude: coords.longitude }
        setUserLocation(here)
        setLocationState('granted')
        moveTo({ ...here, radiusKm: DEFAULT_RADIUS_KM, label: 'Near you' })
        setReady(true)
      },
      (error) => {
        const denied = error.code === error.PERMISSION_DENIED
        setLocationState(denied ? 'denied' : 'unavailable')
        if (denied) api.community.track('community_location_permission_denied')
        setReady(true)
      },
      { enableHighAccuracy: false, maximumAge: 300_000, timeout: 10_000 },
    )
  }, [moveTo])

  useEffect(() => {
    api.community.track('community_opened', { surface: window.innerWidth >= 1024 ? 'desktop' : 'mobile' })
    locate(false)
    // Never hold the map hostage to a permission prompt: show the fallback
    // area after a moment and move when (if) a location arrives.
    const timer = setTimeout(() => setReady(true), 1500)
    return () => clearTimeout(timer)
  }, [locate])

  // ── What we are looking for ────────────────────────────────────────────
  const [queryText, setQueryText] = useState('')
  const [activeQuery, setActiveQuery] = useState('')
  const [resolving, setResolving] = useState(false)
  const [filters, setFilters] = useState<Set<FilterId>>(new Set())
  const filterQuery = useMemo(() => filtersToQuery(filters), [filters])
  const filterKey = useMemo(() => Array.from(filters).sort().join(','), [filters])

  // ── Results ───────────────────────────────────────────────────────────
  const [nearby, setNearby] = useState<NearbyLearningResponse | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<FriendlyError | null>(null)
  const [staleSince, setStaleSince] = useState<number | null>(null)
  const [reloadTick, setReloadTick] = useState(0)
  const requestRef = useRef<AbortController | null>(null)

  // Account state waits for the location decision so it is read once, and
  // the Activity feed loads only when someone opens that tab.
  const myCommunity = useApi(ready ? () => api.community.me(userLocation) : null, [ready, userLocation?.latitude, userLocation?.longitude])
  const [feedWanted, setFeedWanted] = useState(false)
  useEffect(() => {
    if (tab === 'Activity') setFeedWanted(true)
  }, [tab])
  const feed = useApi(feedWanted ? () => api.community.posts(1, 20) : null, [feedWanted])
  const refreshAccount = myCommunity.refetch
  const actions = useCommunityActions(refreshAccount)
  const { clearSettled, withOverride } = actions

  const radiusKm = filterQuery.nearby ? Math.min(area.radiusKm, NEARBY_RADIUS_KM) : area.radiusKm

  useEffect(() => {
    if (!ready) return
    const key = nearbyCacheKey({ latitude: area.latitude, longitude: area.longitude, radiusKm, filters: filterKey, query: activeQuery })
    const cached = readNearby(key)
    if (cached) {
      setNearby(cached.response)
      if (Date.now() - cached.savedAt < FRESH_MS && reloadTick === 0) {
        // Fresh answer for this exact area: nothing to fetch, and any error
        // from a different area or filter no longer applies.
        setError(null)
        setStaleSince(null)
        setLoading(false)
        return
      }
    }
    requestRef.current?.abort()
    const controller = new AbortController()
    requestRef.current = controller
    setLoading(true)
    setError(null)
    api.community
      .nearby({
        latitude: area.latitude,
        longitude: area.longitude,
        radiusKm,
        categories: filterQuery.categories,
        placeTypes: filterQuery.placeTypes,
        when: filterQuery.when,
        freeOnly: filterQuery.freeOnly,
        query: activeQuery,
        includeOnline: true,
        includeInstitutions: true,
        limit: 200,
        signal: controller.signal,
      })
      .then((response) => {
        if (controller.signal.aborted) return
        writeNearby(key, response)
        setNearby(response)
        setStaleSince(null)
        clearSettled()
      })
      .catch((reason) => {
        if (controller.signal.aborted) return
        console.error('Community nearby request failed', reason)
        api.community.track('community_load_failed', { status: typeof reason?.status === 'number' ? reason.status : 0 })
        setError(friendlyError(reason))
        if (cached) setStaleSince(cached.savedAt)
        else setNearby(null)
      })
      .finally(() => {
        if (requestRef.current === controller) setLoading(false)
      })
    return () => controller.abort()
  }, [ready, area.latitude, area.longitude, radiusKm, filterKey, activeQuery, filterQuery, reloadTick, clearSettled])

  const retry = useCallback(() => setReloadTick((tick) => tick + 1), [])
  const refreshAll = useCallback(() => {
    retry()
    myCommunity.refetch()
    feed.refetch()
  }, [retry, myCommunity.refetch, feed.refetch])

  // Another device changed something: re-read the account-owned state.
  useSyncEvents(refreshAll, ['community_updated', 'context_updated'])
  useEffect(() => {
    const onFocus = () => {
      retry()
      myCommunity.refetch()
    }
    window.addEventListener('focus', onFocus)
    return () => window.removeEventListener('focus', onFocus)
  }, [retry, myCommunity.refetch])
  useEffect(() => {
    if (myCommunity.data) clearSettled()
  }, [myCommunity.data, clearSettled])

  // ── Selection ──────────────────────────────────────────────────────────
  const [selectedKey, setSelectedKey] = useState<string | null>(null)
  const [clusterKeys, setClusterKeys] = useState<string[] | null>(null)
  const [sheet, setSheet] = useState<SheetState>('collapsed')
  const [sheetHeight, setSheetHeight] = useState(84)

  const nodes = useMemo(
    () => (nearby?.items ?? []).map((node) => withOverride(node)),
    [nearby, withOverride],
  )
  const mapNodes = useMemo(
    () => nodes.filter((node) => Number.isFinite(node.latitude) && Number.isFinite(node.longitude)),
    [nodes],
  )
  const listNodes = useMemo(
    () => (clusterKeys ? nodes.filter((node) => clusterKeys.includes(node.key)) : nodes),
    [nodes, clusterKeys],
  )
  const accountNodes = useMemo(() => {
    const data = myCommunity.data
    return [...(data?.saved_nodes ?? []), ...(data?.hosting ?? []), ...(data?.going ?? []), ...(data?.interested ?? [])]
  }, [myCommunity.data])
  const selectedNode = selectedKey
    ? withOverride(nodes.find((node) => node.key === selectedKey) ?? accountNodes.find((node) => node.key === selectedKey) ?? null)
    : null

  const selectNode = useCallback((node: LearningNode) => {
    setSelectedKey(node.key)
    setSheet('medium')
    api.community.track('community_marker_opened', { kind: node.kind, category: node.category })
    requestAnimationFrame(() => document.getElementById('community-preview-title')?.focus({ preventScroll: true }))
  }, [])
  const closePreview = useCallback(() => setSelectedKey(null), [])
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setSelectedKey(null)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  // ── Search, filters, and area ──────────────────────────────────────────
  const submitSearch = useCallback(
    async (text: string) => {
      setResolving(true)
      setSelectedKey(null)
      setClusterKeys(null)
      api.community.track('community_search', { length: text.length })
      try {
        const resolution = await api.community.resolveSearch(text, area)
        if (resolution.place && (resolution.intent === 'place' || resolution.intent === 'mixed')) {
          const radius = Math.min(30, Math.max(2, resolution.place.radius_km))
          moveTo({ latitude: resolution.place.latitude, longitude: resolution.place.longitude, radiusKm: radius, label: resolution.place.name })
          setActiveQuery(resolution.intent === 'mixed' ? resolution.topic ?? '' : '')
        } else {
          setActiveQuery(resolution.topic || text)
        }
      } catch {
        // Resolution is a convenience; a plain topic search always works.
        setActiveQuery(text)
      } finally {
        setResolving(false)
        setSheet('medium')
      }
    },
    [area, moveTo],
  )

  const clearSearch = useCallback(() => {
    setQueryText('')
    setActiveQuery('')
  }, [])

  const onToggleFilter = useCallback(
    (id: FilterId) => {
      const turningOn = !filters.has(id)
      setFilters((current) => toggleFilter(current, id))
      setSelectedKey(null)
      setClusterKeys(null)
      if (turningOn) api.community.track('community_filter_selected', { filter: id })
      if (id === 'nearby' && turningOn && userLocation) {
        moveTo({ ...userLocation, radiusKm: NEARBY_RADIUS_KM, label: 'Near you' })
      }
    },
    [filters, moveTo, userLocation],
  )
  const clearFilters = useCallback(() => {
    setFilters(new Set())
    setClusterKeys(null)
  }, [])

  const showAreaButton = shouldOfferAreaSearch({ ...area, radiusKm }, visibleArea)
  const searchThisArea = () => {
    if (!visibleArea) return
    api.community.track('community_search_area', { radius_km: Math.round(visibleArea.radiusKm) })
    setArea({ ...visibleArea, label: 'This area' })
    setVisibleArea(null)
    setSelectedKey(null)
    setClusterKeys(null)
  }

  const onLocate = () => {
    if (userLocation) moveTo({ ...userLocation, radiusKm: DEFAULT_RADIUS_KM, label: 'Near you' })
    else locate(true)
  }

  // ── Creation ───────────────────────────────────────────────────────────
  const [showCreatePost, setShowCreatePost] = useState(false)
  const [createItem, setCreateItem] = useState<'group' | 'tutor' | null>(null)
  const createPost = async (data: PostFormData) => {
    await api.community.createPost({ content: data.content, tags: data.tags, post_type: data.type })
    feed.refetch()
  }
  const posts = (feed.data?.items ?? []).map(mapPost)

  const resultsTitle = (() => {
    const where = area.label === 'Near you' ? 'near you' : area.label === 'This area' ? 'in this area' : `around ${area.label}`
    if (loading && !nodes.length) return `Finding learning ${where}…`
    if (clusterKeys) return `${listNodes.length} here`
    if (error && !nodes.length) return 'Learning opportunities'
    const count = nodes.length
    return `${count} learning ${count === 1 ? 'opportunity' : 'opportunities'} ${where}`
  })()

  const locationNotice =
    !locationNoticeDismissed && (locationState === 'denied' || locationState === 'unavailable') ? (
      <div className="flex items-start gap-2 rounded-2xl border border-white/10 bg-[#0e173d]/90 px-3 py-2.5 text-xs text-white/70 shadow-lg backdrop-blur-md" role="status">
        <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-lyo-300" aria-hidden="true" />
        <p className="flex-1">
          {locationState === 'denied' ? 'Location is off — showing ' : 'Couldn’t find your location — showing '}
          <span className="font-medium text-white">{area.label}</span>. Search a city or ZIP, or allow location.
        </p>
        <button type="button" onClick={() => setLocationNoticeDismissed(true)} aria-label="Dismiss" className="-m-1 flex h-8 w-8 items-center justify-center rounded-lg text-white/50 hover:bg-white/10 hover:text-white">
          <X className="h-4 w-4" aria-hidden="true" />
        </button>
      </div>
    ) : null

  const results = (
    <>
      {clusterKeys && (
        <button type="button" onClick={() => setClusterKeys(null)} className="mx-1 mb-2 flex min-h-[36px] items-center gap-1 rounded-full border border-white/10 px-3 text-xs text-white/70 hover:text-white">
          <X className="h-3.5 w-3.5" aria-hidden="true" /> Show everything in this area
        </button>
      )}
      <CommunityResults
        nodes={listNodes}
        loading={loading}
        error={error}
        staleSince={staleSince}
        degradedSources={nearby?.degraded_sources ?? []}
        selectedKey={selectedKey}
        hasFilters={filters.size > 0 || Boolean(activeQuery)}
        onSelect={selectNode}
        onRetry={retry}
        onClearFilters={() => {
          clearFilters()
          clearSearch()
        }}
      />
    </>
  )

  const preview = selectedNode ? (
    <NodePreview
      node={selectedNode}
      busy={actions.busy.has(selectedNode.key)}
      onClose={closePreview}
      onToggleSave={() => void actions.toggleSave(selectedNode)}
      onRsvp={(status) => void actions.setRsvp(selectedNode, status)}
      onToggleMembership={() => void actions.toggleMembership(selectedNode)}
    />
  ) : null

  const searchBar = (
    <CommunitySearchBar
      value={queryText}
      onChange={(value) => {
        setQueryText(value)
        if (!value) setActiveQuery('')
      }}
      onSubmit={(value) => void submitSearch(value)}
      onClear={clearSearch}
      busy={resolving}
    />
  )

  const locateButton = (
    <div className="pointer-events-auto flex shrink-0 flex-col gap-2">
      <button
        type="button"
        onClick={onLocate}
        aria-label={userLocation ? 'Center on my location' : 'Use my location'}
        className="flex h-12 w-12 items-center justify-center rounded-2xl border border-white/10 bg-[#0e173d]/95 text-white shadow-xl backdrop-blur-md hover:bg-lyo-500/30"
      >
        {locationState === 'locating' ? <Loader2 className="h-5 w-5 animate-spin" aria-hidden="true" /> : <LocateFixed className={cn('h-5 w-5', userLocation && 'text-lyo-300')} aria-hidden="true" />}
      </button>
      {error && nodes.length > 0 && (
        <button type="button" onClick={retry} aria-label="Reload map" className="flex h-12 w-12 items-center justify-center rounded-2xl border border-white/10 bg-[#0e173d]/95 text-white shadow-xl">
          <RotateCw className="h-5 w-5" aria-hidden="true" />
        </button>
      )}
    </div>
  )

  const mobileSheetInset = 'calc(80px + env(safe-area-inset-bottom))'
  // The sheet reports its real height (it scales with the screen), so pins,
  // attribution, and controls always stay above it.
  const sheetPx = sheetHeight

  if (tab !== 'Around Me') {
    return (
      <div className="h-full overflow-y-auto px-4 pb-28 pt-4 md:px-6 md:pb-8">
        <div className="mx-auto max-w-5xl space-y-5">
          <div className="flex items-center gap-3">
            <h1 className="sr-only">Community</h1>
            <TabSwitch tab={tab} onChange={setTab} />
            <CreateMenu tab={tab} onCreateGroup={() => setCreateItem('group')} onCreateTutor={() => setCreateItem('tutor')} onCreatePost={() => setShowCreatePost(true)} />
          </div>
          {tab === 'My Community' ? (
            <MyCommunitySection
              loading={myCommunity.isLoading && !myCommunity.data}
              error={myCommunity.error}
              data={myCommunity.data}
              withOverride={withOverride}
              onRetry={myCommunity.refetch}
              onOpen={(node) => router.push(detailPath(node))}
            />
          ) : (
            <section className="mx-auto max-w-3xl space-y-4">
              {!feed.data && !feed.error && <ResultSkeleton rows={3} />}
              {feed.error && (
                <StateMessage icon={MessageCircle} title="We couldn't load Community activity." body="Please try again in a moment." tone="warning" action={{ label: 'Try again', onClick: feed.refetch }} />
              )}
              {feed.data && !feed.isLoading && !feed.error && !posts.length && (
                <button type="button" onClick={() => setShowCreatePost(true)} className="w-full rounded-2xl border border-dashed border-white/15 px-6 py-16 text-center text-sm text-white/55 hover:border-lyo-500/50 hover:text-white">
                  No activity yet. Share the first study tip or question.
                </button>
              )}
              {posts.map((post) => <PostCard key={post.id} post={post} onClick={() => router.push(`/community/${post.id}`)} />)}
            </section>
          )}
        </div>
        {showCreatePost && <CreatePostModal onClose={() => setShowCreatePost(false)} onSubmit={createPost} />}
        {createItem && <CreateCommunityItemModal initialType={createItem} onClose={() => setCreateItem(null)} onCreated={() => { retry(); myCommunity.refetch() }} />}
      </div>
    )
  }

  return (
    <div className="flex h-full min-h-0 flex-col lg:flex-row">
      <h1 className="sr-only">Community — learning around you</h1>

      {/* Desktop: search and results panel */}
      {isDesktop && (
        <aside className="flex w-[400px] shrink-0 flex-col border-r border-white/[0.06] bg-[#0b1230]/70 xl:w-[430px]">
          <div className="space-y-3 border-b border-white/[0.06] p-4">
            <div className="flex items-center gap-2">
              <TabSwitch tab={tab} onChange={setTab} />
              <CreateMenu compact tab={tab} onCreateGroup={() => setCreateItem('group')} onCreateTutor={() => setCreateItem('tutor')} onCreatePost={() => setShowCreatePost(true)} />
            </div>
            {searchBar}
            <FilterChips active={filters} onToggle={onToggleFilter} onClear={clearFilters} className="-mx-4 px-4 pb-0.5" />
          </div>
          <div className="flex items-center justify-between px-5 pb-1 pt-3">
            <p className="text-sm font-medium text-white/80" aria-live="polite">{resultsTitle}</p>
            {loading && nearby && <Loader2 className="h-4 w-4 animate-spin text-lyo-300" aria-label="Updating" />}
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto px-2 pb-4">{results}</div>
        </aside>
      )}

      {/* Mobile: tabs above the map */}
      {!isDesktop && (
        <div className="flex items-center gap-2 px-3 pb-2 pt-2">
          <TabSwitch tab={tab} onChange={setTab} />
          <CreateMenu compact tab={tab} onCreateGroup={() => setCreateItem('group')} onCreateTutor={() => setCreateItem('tutor')} onCreatePost={() => setShowCreatePost(true)} />
        </div>
      )}

      <div
        className="relative min-h-0 flex-1 overflow-hidden"
        style={{ ['--lyo-map-bottom-inset' as string]: isDesktop ? '0px' : `calc(${sheetPx}px + 80px + env(safe-area-inset-bottom))` }}
      >
        <div className="absolute inset-0 isolate">
          <CommunityEventMap
            nodes={mapNodes}
            view={mapView}
            selectedKey={selectedKey}
            userLocation={userLocation}
            onSelect={selectNode}
            onClusterSelect={(members) => {
              setClusterKeys(members.map((node) => node.key))
              setSelectedKey(null)
              setSheet('medium')
            }}
            onViewportChange={setVisibleArea}
            padding={isDesktop ? { top: 72, bottom: selectedNode ? 340 : 24, left: 24, right: 72 } : { top: 150, bottom: sheetPx + 96, left: 16, right: 16 }}
          />
        </div>

        {/* Overlays: search and filters (mobile), status, area search, locate */}
        <div className="pointer-events-none absolute inset-x-0 top-0 z-10 space-y-2 p-3">
          {!isDesktop && (
            <div className="pointer-events-auto space-y-2">
              {searchBar}
              <FilterChips active={filters} onToggle={onToggleFilter} onClear={clearFilters} className="-mx-3 px-3" />
            </div>
          )}
          <div className="flex items-start justify-between gap-2">
            <div className="pointer-events-auto max-w-md flex-1">{locationNotice}</div>
            {isDesktop ? <MapKey /> : locateButton}
          </div>
          {showAreaButton && (
            <div className="flex justify-center">
              <button
                type="button"
                onClick={searchThisArea}
                className="pointer-events-auto flex min-h-[44px] items-center gap-2 rounded-full border border-white/15 bg-[#0e173d]/95 px-4 text-sm font-semibold text-white shadow-xl backdrop-blur-md hover:bg-lyo-500/30"
              >
                <Search className="h-4 w-4" aria-hidden="true" />
                Search this area
              </button>
            </div>
          )}
        </div>

        {isDesktop && (
          <div className="absolute bottom-[120px] right-3 z-10 flex flex-col gap-2">
            {locateButton}
          </div>
        )}

        {/* Desktop preview floats over the map, which stays visible behind it */}
        {isDesktop && preview && (
          <div className="absolute bottom-5 left-5 z-20 w-[400px] max-w-[calc(100%-2.5rem)] rounded-3xl border border-white/10 bg-[#0e173d]/[0.97] p-4 shadow-[0_24px_60px_rgba(3,7,18,0.6)] backdrop-blur-2xl">
            {preview}
          </div>
        )}

        {!isDesktop && (
          <BottomSheet
            state={sheet}
            onStateChange={setSheet}
            bottomInset={mobileSheetInset}
            contentKey={selectedKey ?? 'results'}
            onHeightChange={setSheetHeight}
            title={
              selectedNode ? (
                <span className="text-sm font-medium text-white/60">Details</span>
              ) : (
                <span className="flex items-center justify-between gap-2">
                  <span className="text-sm font-semibold text-white" aria-live="polite">{resultsTitle}</span>
                  {loading && nearby && <Loader2 className="h-4 w-4 animate-spin text-lyo-300" aria-label="Updating" />}
                </span>
              )
            }
          >
            {preview ?? results}
          </BottomSheet>
        )}
      </div>

      {showCreatePost && <CreatePostModal onClose={() => setShowCreatePost(false)} onSubmit={createPost} />}
      {createItem && <CreateCommunityItemModal initialType={createItem} onClose={() => setCreateItem(null)} onCreated={() => { retry(); myCommunity.refetch() }} />}
    </div>
  )
}

function AccountList({
  title,
  icon: Icon,
  nodes,
  empty,
  onOpen,
}: {
  title: string
  icon: typeof Bookmark
  nodes: LearningNode[]
  empty: string
  onOpen: (node: LearningNode) => void
}) {
  return (
    <section aria-labelledby={`account-${title}`} className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-4">
      <div className="mb-2 flex items-center gap-2">
        <Icon className="h-5 w-5 text-lyo-300" aria-hidden="true" />
        <h2 id={`account-${title}`} className="font-display text-base font-semibold text-white">{title}</h2>
        <span className="text-xs text-white/40">{nodes.length || ''}</span>
      </div>
      {nodes.length ? (
        <ul className="space-y-1">
          {nodes.map((node) => (
            <li key={node.key}>
              <NodeRow node={node} onSelect={onOpen} />
            </li>
          ))}
        </ul>
      ) : (
        <p className="px-1 py-3 text-sm text-white/45">{empty}</p>
      )}
    </section>
  )
}

/** Paste an invite link (or code) someone sent in a message or email. */
function InviteLinkForm() {
  const router = useRouter()
  const [value, setValue] = useState('')
  const [invalid, setInvalid] = useState(false)
  const submit = (event: React.FormEvent) => {
    event.preventDefault()
    const token = inviteTokenFromText(value)
    if (!token) {
      setInvalid(true)
      return
    }
    router.push(invitePath(token))
  }
  return (
    <form onSubmit={submit} className="flex flex-col gap-2 rounded-3xl border border-white/[0.08] bg-white/[0.03] p-4 sm:flex-row sm:items-end">
      <label className="flex-1 text-sm text-white/70">
        <span className="flex items-center gap-2 font-medium text-white"><Link2 className="h-4 w-4 text-lyo-300" aria-hidden="true" />Have an invite link?</span>
        <input
          value={value}
          onChange={(event) => { setValue(event.target.value); setInvalid(false) }}
          placeholder="Paste it here"
          aria-invalid={invalid}
          aria-describedby={invalid ? 'invite-link-error' : undefined}
          className="mt-1.5 min-h-[44px] w-full rounded-xl border border-white/10 bg-white/5 px-3 text-sm text-white placeholder:text-white/35 focus:border-lyo-500 focus:outline-none"
        />
        {invalid && <span id="invite-link-error" className="mt-1 block text-xs text-amber-200">That doesn&apos;t look like a Lyo invite link.</span>}
      </label>
      <button type="submit" disabled={!value.trim()} className="min-h-[44px] rounded-xl bg-lyo-500 px-4 text-sm font-semibold text-white hover:bg-lyo-400 disabled:opacity-50">Open invite</button>
    </form>
  )
}

function MyCommunitySection({
  loading,
  error,
  data,
  withOverride,
  onRetry,
  onOpen,
}: {
  loading: boolean
  error: string | null
  data: import('@/types').MyCommunityResponse | null
  withOverride: <T extends LearningNode | null | undefined>(node: T) => T
  onRetry: () => void
  onOpen: (node: LearningNode) => void
}) {
  const router = useRouter()
  if (loading) return <ResultSkeleton rows={6} />
  if (error && !data) {
    return <StateMessage icon={Users} title="We couldn't load your Community." body="Please try again in a moment." tone="warning" action={{ label: 'Try again', onClick: onRetry }} />
  }
  if (!data) return null
  const saved = data.saved_nodes.map(withOverride)
  const going = (data.going ?? []).map(withOverride)
  const interested = (data.interested ?? []).map(withOverride)
  const hosting = (data.hosting ?? []).map(withOverride)
  const invited = (data.invited ?? []).map(withOverride)
  const groups = data.joined_groups
  return (
    <div className="space-y-4">
      <p className="text-sm text-white/50">Synced to your Lyo account — the same on web, iPhone, iPad, and Android.</p>
      {invited.length > 0 && (
        <AccountList title="Invited" icon={MailOpen} nodes={invited} empty="" onOpen={onOpen} />
      )}
      <InviteLinkForm />
      <div className="grid gap-4 lg:grid-cols-2">
        <AccountList title="Going" icon={Ticket} nodes={going} empty="Events you RSVP to appear here." onOpen={onOpen} />
        <AccountList title="Interested" icon={Star} nodes={interested} empty="Mark events as interested to keep an eye on them." onOpen={onOpen} />
        <AccountList title="Saved" icon={Bookmark} nodes={saved} empty="Save a place or event from the map and it appears here on every device." onOpen={onOpen} />
        <section aria-labelledby="account-hosting" className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-4">
          <div className="mb-2 flex items-center gap-2">
            <Calendar className="h-5 w-5 text-lyo-300" aria-hidden="true" />
            <h2 id="account-hosting" className="font-display text-base font-semibold text-white">Hosting</h2>
            <Link href="/community/events/new" className="ml-auto flex min-h-[36px] items-center gap-1 rounded-xl px-2 text-xs font-semibold text-lyo-300 hover:bg-white/5">
              <Plus className="h-3.5 w-3.5" aria-hidden="true" /> New event
            </Link>
          </div>
          {hosting.length ? (
            <ul className="space-y-1">
              {hosting.map((node) => (
                <li key={node.key} className="flex items-center gap-1">
                  <div className="min-w-0 flex-1"><NodeRow node={node} onSelect={onOpen} /></div>
                  {node.lifecycle !== 'past' && (
                    <button type="button" onClick={() => router.push(`/community/events/${node.id}/edit`)} className="min-h-[44px] shrink-0 rounded-xl px-3 text-xs font-medium text-white/60 hover:bg-white/10 hover:text-white">
                      Edit
                    </button>
                  )}
                </li>
              ))}
            </ul>
          ) : (
            <p className="px-1 py-3 text-sm text-white/45">Events you create appear here so you can edit or cancel them.</p>
          )}
        </section>
      </div>
      <section aria-labelledby="account-groups" className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-4">
        <div className="mb-2 flex items-center gap-2">
          <Users className="h-5 w-5 text-lyo-300" aria-hidden="true" />
          <h2 id="account-groups" className="font-display text-base font-semibold text-white">Study groups</h2>
          <Link href="/community/groups" className="ml-auto flex min-h-[36px] items-center gap-1 rounded-xl px-2 text-xs font-semibold text-lyo-300 hover:bg-white/5">
            Browse <ChevronRight className="h-3.5 w-3.5" aria-hidden="true" />
          </Link>
        </div>
        {groups.length ? (
          <ul className="grid gap-2 md:grid-cols-2">
            {groups.map((group) => (
              <li key={String(group.id)}>
                <Link href={`/community/places/study_group/${group.id}`} className="block rounded-2xl border border-white/[0.06] px-3.5 py-3 hover:bg-white/[0.04]">
                  <span className="block font-medium text-white">{String(group.name ?? 'Study group')}</span>
                  <span className="mt-0.5 block text-xs text-white/50">{group.is_online ? 'Online' : String(group.location ?? '')}</span>
                </Link>
              </li>
            ))}
          </ul>
        ) : (
          <p className="px-1 py-3 text-sm text-white/45">You haven&apos;t joined a study group yet.</p>
        )}
      </section>
      <section aria-labelledby="account-following" className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-4">
        <div className="mb-3 flex items-center gap-2">
          <MessageCircle className="h-5 w-5 text-lyo-300" aria-hidden="true" />
          <h2 id="account-following" className="font-display text-base font-semibold text-white">People you follow</h2>
        </div>
        {data.following.length ? (
          <div className="flex flex-wrap gap-2">
            {data.following.map((person) => (
              <Link key={person.id} href={`/profile/${person.id}`} className="flex min-h-[44px] items-center gap-2 rounded-xl border border-white/10 px-3 py-1.5 hover:border-lyo-500/50">
                <span className="grid h-8 w-8 place-items-center overflow-hidden rounded-full bg-lyo-500 text-sm font-bold text-white">
                  {person.avatar ? <img src={person.avatar} alt="" className="h-full w-full object-cover" /> : person.name.slice(0, 1).toUpperCase()}
                </span>
                <span className="text-sm font-medium text-white">{person.name}</span>
              </Link>
            ))}
          </div>
        ) : (
          <p className="text-sm text-white/45">People you follow will appear here.</p>
        )}
      </section>
    </div>
  )
}
