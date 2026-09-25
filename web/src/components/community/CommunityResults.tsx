'use client'

import { AlertCircle, Bookmark, Compass, RotateCw, WifiOff } from 'lucide-react'
import {
  categoryLabel,
  formatDistance,
  formatPrice,
  formatWhen,
  type FriendlyError,
} from '@/lib/community-contract.mjs'
import { cn } from '@/lib/utils'
import type { LearningNode } from '@/types'
import { markerColors } from './CommunityEventMap'
import { LifecyclePill } from './NodePreview'

export function NodeRow({
  node,
  selected,
  onSelect,
}: {
  node: LearningNode
  selected?: boolean
  onSelect: (node: LearningNode) => void
}) {
  const when = formatWhen(node.starts_at, node.ends_at)
  const distance = formatDistance(node.distance_km)
  const price = formatPrice(node)
  const secondary = [when, distance && (node.latitude != null ? distance : null)].filter(Boolean).join(' · ')
  const where = node.venue_name || node.location_name || (node.is_online ? 'Online' : null)
  return (
    <button
      type="button"
      onClick={() => onSelect(node)}
      aria-current={selected ? 'true' : undefined}
      className={cn(
        'group flex w-full items-start gap-3 rounded-2xl border px-3.5 py-3 text-left transition',
        selected
          ? 'border-lyo-400/60 bg-lyo-500/10'
          : 'border-transparent hover:border-white/10 hover:bg-white/[0.04]',
      )}
    >
      <span
        className="mt-1 h-9 w-1.5 shrink-0 rounded-full"
        style={{ background: markerColors[node.category] }}
        aria-hidden="true"
      />
      <span className="min-w-0 flex-1">
        <span className="flex items-center gap-2 text-[11px] font-medium uppercase tracking-wide text-white/45">
          {categoryLabel(node)}
          <LifecyclePill node={node} />
        </span>
        <span className="mt-0.5 flex items-start justify-between gap-2">
          <span className="line-clamp-2 text-[15px] font-semibold leading-snug text-white">{node.title}</span>
          {node.is_saved && <Bookmark className="mt-0.5 h-4 w-4 shrink-0 fill-lyo-400 text-lyo-300" aria-label="Saved" />}
        </span>
        {secondary && <span className="mt-1 block truncate text-xs text-white/55">{secondary}</span>}
        <span className="mt-0.5 flex items-center gap-2 text-xs text-white/40">
          {where && <span className="truncate">{where}</span>}
          {price && <span className={cn('shrink-0', price === 'Free' && 'text-emerald-300/90')}>{price}</span>}
          {node.rsvp_status && (
            <span className="shrink-0 text-lyo-300">{node.rsvp_status === 'going' ? '· Going' : '· Interested'}</span>
          )}
        </span>
      </span>
    </button>
  )
}

export function ResultSkeleton({ rows = 5 }: { rows?: number }) {
  return (
    <div aria-hidden="true" className="space-y-2 px-1">
      {Array.from({ length: rows }).map((_, index) => (
        <div key={index} className="flex gap-3 rounded-2xl px-3.5 py-3">
          <div className="h-9 w-1.5 rounded-full bg-white/10" />
          <div className="flex-1 space-y-2">
            <div className="h-2.5 w-20 animate-pulse rounded bg-white/10 motion-reduce:animate-none" />
            <div className="h-3.5 w-4/5 animate-pulse rounded bg-white/15 motion-reduce:animate-none" />
            <div className="h-2.5 w-2/5 animate-pulse rounded bg-white/10 motion-reduce:animate-none" />
          </div>
        </div>
      ))}
    </div>
  )
}

export function StateMessage({
  icon: Icon,
  title,
  body,
  action,
  tone = 'neutral',
}: {
  icon: typeof AlertCircle
  title: string
  body?: string
  action?: { label: string; onClick: () => void }
  tone?: 'neutral' | 'warning'
}) {
  return (
    <div className="flex flex-col items-center px-6 py-10 text-center" role={tone === 'warning' ? 'alert' : 'status'}>
      <span
        className={cn(
          'mb-3 flex h-12 w-12 items-center justify-center rounded-2xl',
          tone === 'warning' ? 'bg-amber-400/10 text-amber-300' : 'bg-white/[0.06] text-white/50',
        )}
      >
        <Icon className="h-6 w-6" aria-hidden="true" />
      </span>
      <p className="font-display text-base font-semibold text-white">{title}</p>
      {body && <p className="mt-1 max-w-xs text-sm text-white/55">{body}</p>}
      {action && (
        <button
          type="button"
          onClick={action.onClick}
          className="mt-4 flex min-h-[44px] items-center gap-2 rounded-xl border border-white/15 px-4 text-sm font-medium text-white hover:bg-white/10"
        >
          <RotateCw className="h-4 w-4" aria-hidden="true" />
          {action.label}
        </button>
      )}
    </div>
  )
}

function minutesAgo(since: number): string {
  const minutes = Math.max(1, Math.round((Date.now() - since) / 60000))
  return minutes < 60 ? `${minutes} min ago` : `${Math.round(minutes / 60)} h ago`
}

export default function CommunityResults({
  nodes,
  loading,
  error,
  staleSince,
  degradedSources,
  selectedKey,
  hasFilters,
  onSelect,
  onRetry,
  onClearFilters,
}: {
  nodes: LearningNode[]
  loading: boolean
  error: FriendlyError | null
  staleSince: number | null
  degradedSources: string[]
  selectedKey: string | null
  hasFilters: boolean
  onSelect: (node: LearningNode) => void
  onRetry: () => void
  onClearFilters: () => void
}) {
  if (loading && !nodes.length) return <ResultSkeleton />
  if (error && !nodes.length) {
    return (
      <StateMessage
        icon={error.title === "You're offline" ? WifiOff : AlertCircle}
        title={error.title}
        body={error.body}
        tone="warning"
        action={error.retry ? { label: 'Try again', onClick: onRetry } : undefined}
      />
    )
  }
  return (
    <div className="space-y-2">
      {staleSince && (
        <div className="mx-1 flex items-center gap-2 rounded-xl bg-amber-400/10 px-3 py-2 text-xs text-amber-100" role="status">
          <WifiOff className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
          <span className="flex-1">Showing results from {minutesAgo(staleSince)}.</span>
          <button type="button" onClick={onRetry} className="font-semibold underline-offset-2 hover:underline">
            Refresh
          </button>
        </div>
      )}
      {degradedSources.includes('places') && !staleSince && (
        <p className="mx-1 rounded-xl bg-white/[0.05] px-3 py-2 text-xs text-white/55" role="status">
          Libraries and museums couldn&apos;t load right now. Events and groups are up to date.
        </p>
      )}
      {!nodes.length ? (
        <StateMessage
          icon={Compass}
          title="Nothing here yet"
          body={
            hasFilters
              ? 'No learning opportunities match these filters in this area.'
              : 'Try zooming out, searching another area, or create the first event here.'
          }
          action={hasFilters ? { label: 'Clear filters', onClick: onClearFilters } : undefined}
        />
      ) : (
        <ul className="space-y-1" aria-label={`${nodes.length} learning opportunities`}>
          {nodes.map((node) => (
            <li key={node.key}>
              <NodeRow node={node} selected={node.key === selectedKey} onSelect={onSelect} />
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
