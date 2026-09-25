'use client'

import Link from 'next/link'
import toast from 'react-hot-toast'
import {
  Bookmark,
  Check,
  ChevronRight,
  Clock,
  Globe,
  Laptop,
  MapPin,
  Navigation,
  Share2,
  Star,
  Ticket,
  Users,
  X,
} from 'lucide-react'
import { api } from '@/lib/api'
import {
  LIFECYCLE_LABELS,
  categoryLabel,
  detailPath,
  directionsUrl,
  formatDistance,
  formatPrice,
  formatWhen,
  safeWebUrl,
} from '@/lib/community-contract.mjs'
import { cn, formatNumber } from '@/lib/utils'
import type { LearningNode, RSVPStatus } from '@/types'
import { markerColors } from './CommunityEventMap'

export async function shareNode(node: LearningNode) {
  const url = `${window.location.origin}${detailPath(node)}`
  api.community.track('community_event_shared', { kind: node.kind })
  try {
    if (navigator.share) {
      await navigator.share({ title: node.title, text: `${node.title} on Lyo`, url })
      return
    }
    await navigator.clipboard.writeText(url)
    toast.success('Link copied')
  } catch (error) {
    if ((error as DOMException)?.name !== 'AbortError') toast.error("Couldn't share this link")
  }
}

export function LifecyclePill({ node }: { node: LearningNode }) {
  if (!node.lifecycle || node.lifecycle === 'upcoming') return null
  const tone =
    node.lifecycle === 'live'
      ? 'bg-emerald-400/15 text-emerald-300 ring-emerald-400/30'
      : node.lifecycle === 'today'
        ? 'bg-amber-400/15 text-amber-200 ring-amber-400/30'
        : 'bg-white/10 text-white/60 ring-white/15'
  return (
    <span className={cn('inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-semibold ring-1', tone)}>
      {LIFECYCLE_LABELS[node.lifecycle]}
    </span>
  )
}

export function CategoryBadge({ node }: { node: LearningNode }) {
  return (
    <span className="inline-flex items-center gap-1.5 text-xs font-medium text-white/60">
      <span className="h-2 w-2 rounded-full" style={{ background: markerColors[node.category] }} aria-hidden="true" />
      {categoryLabel(node)}
    </span>
  )
}

export function RsvpControl({
  node,
  busy,
  onRsvp,
  size = 'md',
}: {
  node: LearningNode
  busy: boolean
  onRsvp: (status: RSVPStatus | null) => void
  size?: 'md' | 'lg'
}) {
  const closed = node.lifecycle === 'past' || node.lifecycle === 'cancelled'
  if (closed) return null
  const going = node.rsvp_status === 'going'
  const interested = node.rsvp_status === 'interested'
  const full = Boolean(node.is_full) && !going
  const base = size === 'lg' ? 'min-h-[48px] px-5 text-sm' : 'min-h-[44px] px-4 text-sm'
  return (
    <div className="flex gap-2" role="group" aria-label="Your RSVP">
      <button
        type="button"
        disabled={busy || full}
        aria-pressed={going}
        onClick={() => onRsvp(going ? null : 'going')}
        className={cn(
          base,
          'flex flex-1 items-center justify-center gap-2 rounded-xl font-semibold transition disabled:opacity-50',
          going ? 'bg-emerald-500 text-white hover:bg-emerald-400' : 'bg-lyo-500 text-white hover:bg-lyo-400',
        )}
      >
        {going ? <Check className="h-4 w-4" aria-hidden="true" /> : <Ticket className="h-4 w-4" aria-hidden="true" />}
        {going ? 'Going' : full ? 'Full' : 'RSVP'}
      </button>
      <button
        type="button"
        disabled={busy}
        aria-pressed={interested}
        onClick={() => onRsvp(interested ? null : 'interested')}
        className={cn(
          base,
          'flex items-center justify-center gap-2 rounded-xl border font-medium transition disabled:opacity-50',
          interested
            ? 'border-amber-300/50 bg-amber-300/15 text-amber-100'
            : 'border-white/15 text-white/80 hover:bg-white/10',
        )}
      >
        <Star className={cn('h-4 w-4', interested && 'fill-current')} aria-hidden="true" />
        Interested
      </button>
    </div>
  )
}

export function IconAction({
  label,
  onClick,
  href,
  children,
  pressed,
  disabled,
}: {
  label: string
  onClick?: () => void
  href?: string | null
  children: React.ReactNode
  pressed?: boolean
  disabled?: boolean
}) {
  const className = cn(
    'flex min-h-[44px] min-w-[44px] items-center justify-center gap-2 rounded-xl border border-white/10 px-3 text-sm font-medium text-white/80 transition hover:bg-white/10 disabled:opacity-50',
    pressed && 'border-lyo-400/50 bg-lyo-500/15 text-white',
  )
  if (href) {
    return (
      <a href={href} target="_blank" rel="noreferrer" className={className} aria-label={label}>
        {children}
      </a>
    )
  }
  return (
    <button type="button" onClick={onClick} disabled={disabled} className={className} aria-label={label} aria-pressed={pressed}>
      {children}
    </button>
  )
}

export function NodeFacts({ node, compact = false }: { node: LearningNode; compact?: boolean }) {
  const when = formatWhen(node.starts_at, node.ends_at)
  const distance = formatDistance(node.distance_km)
  const price = formatPrice(node)
  const address = node.address || node.location_name
  // "Main Library · Main Library, 5th Ave" reads as a stutter; keep one.
  const place =
    node.venue_name && address && address.toLowerCase().includes(node.venue_name.toLowerCase())
      ? address
      : [node.venue_name, address].filter(Boolean).join(' · ')
  const online = node.attendance_mode === 'online' || (node.is_online && node.latitude == null)
  const website = safeWebUrl(node.website_url)
  const facts: Array<{ icon: typeof Clock; text: string; href?: string }> = []
  if (when) facts.push({ icon: Clock, text: when })
  if (online) facts.push({ icon: Laptop, text: node.attendance_mode === 'hybrid' ? 'In person and online' : 'Online' })
  else if (node.attendance_mode === 'hybrid') facts.push({ icon: Laptop, text: 'Also online' })
  if (place) facts.push({ icon: MapPin, text: distance ? `${place} · ${distance}` : place })
  else if (distance) facts.push({ icon: MapPin, text: `${distance} away` })
  if (!compact && node.opening_hours) facts.push({ icon: Clock, text: node.opening_hours })
  if (!compact && website) facts.push({ icon: Globe, text: new URL(website).hostname.replace(/^www\./, ''), href: website })
  const people: string[] = []
  if (node.going_count) people.push(`${formatNumber(node.going_count)} going`)
  if (node.interested_count) people.push(`${formatNumber(node.interested_count)} interested`)
  if (node.member_count != null && node.kind === 'study_group') people.push(`${formatNumber(node.member_count)} members`)
  if (node.capacity && node.kind === 'event') people.push(`${formatNumber(node.capacity)} spots`)
  if (people.length) facts.push({ icon: Users, text: people.join(' · ') })
  return (
    <ul className="space-y-1.5 text-sm text-white/70">
      {facts.map(({ icon: Icon, text, href }) => (
        <li key={`${text}`} className="flex items-start gap-2">
          <Icon className="mt-0.5 h-4 w-4 shrink-0 text-white/40" aria-hidden="true" />
          {href ? (
            <a href={href} target="_blank" rel="noreferrer" className="truncate text-lyo-300 underline-offset-2 hover:underline">
              {text}
            </a>
          ) : (
            <span className={compact ? 'line-clamp-1' : ''}>{text}</span>
          )}
        </li>
      ))}
      {price && (
        <li className="flex items-center gap-2">
          <Ticket className="h-4 w-4 shrink-0 text-white/40" aria-hidden="true" />
          <span className={cn(price === 'Free' && 'font-medium text-emerald-300')}>{price}</span>
        </li>
      )}
    </ul>
  )
}

/**
 * The first answer to a marker tap: enough to decide, with the map still
 * visible behind it. "View details" is the only action that leaves the map.
 */
export default function NodePreview({
  node,
  busy,
  onClose,
  onToggleSave,
  onRsvp,
  onToggleMembership,
  headingId = 'community-preview-title',
  className,
}: {
  node: LearningNode
  busy: boolean
  onClose: () => void
  onToggleSave: () => void
  onRsvp: (status: RSVPStatus | null) => void
  onToggleMembership: () => void
  headingId?: string
  className?: string
}) {
  const hostName = node.organizer_name || node.host?.name
  const directions = directionsUrl(node)
  return (
    <article aria-labelledby={headingId} className={cn('space-y-3', className)}>
      <header className="flex items-start gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <CategoryBadge node={node} />
            <LifecyclePill node={node} />
          </div>
          <h2 id={headingId} tabIndex={-1} className="mt-1 font-display text-lg font-semibold leading-snug text-white focus:outline-none">
            {node.title}
          </h2>
          {hostName && <p className="mt-0.5 text-xs text-white/50">Hosted by {hostName}</p>}
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close preview"
          className="-mr-1 -mt-1 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl text-white/50 hover:bg-white/10 hover:text-white"
        >
          <X className="h-5 w-5" aria-hidden="true" />
        </button>
      </header>

      <NodeFacts node={node} compact />
      {node.description ? (
        <p className="line-clamp-3 text-sm leading-relaxed text-white/65">{node.description}</p>
      ) : node.relevance ? (
        <p className="text-sm leading-relaxed text-white/60">{node.relevance}</p>
      ) : null}

      {node.kind === 'event' && <RsvpControl node={node} busy={busy} onRsvp={onRsvp} />}
      {node.kind === 'study_group' && !node.is_owner && (
        <button
          type="button"
          disabled={busy}
          onClick={onToggleMembership}
          className={cn(
            'flex min-h-[44px] w-full items-center justify-center gap-2 rounded-xl text-sm font-semibold transition disabled:opacity-50',
            node.is_joined ? 'border border-white/15 text-white/80 hover:bg-white/10' : 'bg-lyo-500 text-white hover:bg-lyo-400',
          )}
        >
          <Users className="h-4 w-4" aria-hidden="true" />
          {node.is_joined ? 'Leave group' : 'Join group'}
        </button>
      )}

      <div className="flex flex-wrap gap-2">
        <IconAction label={node.is_saved ? 'Remove from saved' : 'Save'} onClick={onToggleSave} pressed={node.is_saved} disabled={busy}>
          <Bookmark className={cn('h-4 w-4', node.is_saved && 'fill-current text-lyo-300')} aria-hidden="true" />
          <span>{node.is_saved ? 'Saved' : 'Save'}</span>
        </IconAction>
        <IconAction label="Share" onClick={() => void shareNode(node)}>
          <Share2 className="h-4 w-4" aria-hidden="true" />
        </IconAction>
        {directions && (
          <IconAction label="Directions (opens maps)" href={directions}>
            <Navigation className="h-4 w-4" aria-hidden="true" />
          </IconAction>
        )}
        <Link
          href={detailPath(node)}
          className="ml-auto flex min-h-[44px] items-center gap-1 rounded-xl px-3 text-sm font-semibold text-lyo-300 hover:bg-white/5 hover:text-white"
        >
          View details
          <ChevronRight className="h-4 w-4" aria-hidden="true" />
        </Link>
      </div>
    </article>
  )
}
