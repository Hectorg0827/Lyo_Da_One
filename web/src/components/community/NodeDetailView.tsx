'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import toast from 'react-hot-toast'
import {
  ArrowLeft,
  Bookmark,
  CalendarPlus,
  ExternalLink,
  Flag,
  Globe,
  Mail,
  Navigation,
  Pencil,
  Phone,
  Share2,
  Trash2,
  Users,
  Video,
  XCircle,
} from 'lucide-react'
import { useApi } from '@/hooks/use-api'
import { useSyncEvents } from '@/hooks/use-sync'
import { useCommunityActions } from '@/hooks/use-community-actions'
import { api } from '@/lib/api'
import {
  buildIcs,
  detailPath,
  directionsUrl,
  friendlyError,
  googleCalendarUrl,
  safeWebUrl,
} from '@/lib/community-contract.mjs'
import { cn } from '@/lib/utils'
import type { LearningNode, LearningNodeKind } from '@/types'
import CommunityEventMap from './CommunityEventMap'
import { NodeRow, ResultSkeleton, StateMessage } from './CommunityResults'
import { CategoryBadge, IconAction, LifecyclePill, NodeFacts, RsvpControl, shareNode } from './NodePreview'

const REPORT_REASONS = [
  { value: 'spam', label: 'Spam or advertising' },
  { value: 'misinformation', label: 'Misleading or fake event' },
  { value: 'inappropriate', label: 'Inappropriate content' },
  { value: 'harassment', label: 'Harassment or hate' },
  { value: 'other', label: 'Something else' },
]

function ConfirmDialog({
  title,
  body,
  confirmLabel,
  destructive,
  busy,
  onConfirm,
  onClose,
  children,
}: {
  title: string
  body: string
  confirmLabel: string
  destructive?: boolean
  busy: boolean
  onConfirm: () => void
  onClose: () => void
  children?: React.ReactNode
}) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => event.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 backdrop-blur-sm sm:items-center sm:p-4" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section role="alertdialog" aria-modal="true" aria-labelledby="confirm-title" aria-describedby="confirm-body" className="w-full max-w-md rounded-t-3xl border border-white/10 bg-[#0e173d] p-5 pb-[calc(1.25rem+env(safe-area-inset-bottom))] shadow-2xl sm:rounded-3xl sm:pb-5">
        <h2 id="confirm-title" className="font-display text-lg font-semibold text-white">{title}</h2>
        <p id="confirm-body" className="mt-1 text-sm text-white/60">{body}</p>
        {children}
        <div className="mt-5 flex justify-end gap-2">
          <button type="button" autoFocus onClick={onClose} disabled={busy} className="min-h-[44px] rounded-xl border border-white/15 px-4 text-sm text-white/80 hover:bg-white/10">
            Not now
          </button>
          <button type="button" onClick={onConfirm} disabled={busy} className={cn('min-h-[44px] rounded-xl px-4 text-sm font-semibold text-white disabled:opacity-50', destructive ? 'bg-red-500 hover:bg-red-400' : 'bg-lyo-500 hover:bg-lyo-400')}>
            {busy ? 'Working…' : confirmLabel}
          </button>
        </div>
      </section>
    </div>
  )
}

function downloadIcs(node: LearningNode) {
  const ics = buildIcs(node, `${window.location.origin}${detailPath(node)}`)
  if (!ics) return
  const blob = new Blob([ics], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${node.title.replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '-').slice(0, 60) || 'lyo-event'}.ics`
  document.body.appendChild(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

/**
 * The full experience for one learning opportunity. Events keep working
 * after they end (history) or are cancelled; only the host can edit.
 */
export default function NodeDetailView({ kind, nodeId }: { kind: LearningNodeKind; nodeId: string }) {
  const router = useRouter()
  const [origin, setOrigin] = useState<{ latitude: number; longitude: number } | null>(null)

  // Distance is a bonus: only when location permission was already granted.
  useEffect(() => {
    let cancelled = false
    navigator.permissions
      ?.query({ name: 'geolocation' as PermissionName })
      .then((status) => {
        if (status.state !== 'granted' || cancelled) return
        navigator.geolocation.getCurrentPosition(
          ({ coords }) => !cancelled && setOrigin({ latitude: coords.latitude, longitude: coords.longitude }),
          () => undefined,
          { maximumAge: 300_000, timeout: 8_000 },
        )
      })
      .catch(() => undefined)
    return () => {
      cancelled = true
    }
  }, [])

  const detail = useApi(() => api.community.node(kind, nodeId, origin), [kind, nodeId, origin?.latitude, origin?.longitude])
  const refresh = detail.refetch
  const actions = useCommunityActions(refresh)
  const { clearSettled, withOverride } = actions
  useEffect(() => {
    if (detail.data) clearSettled()
  }, [detail.data, clearSettled])
  useSyncEvents(refresh, ['community_updated', 'context_updated'])

  useEffect(() => {
    if (detail.data) {
      api.community.track(kind === 'event' ? 'community_event_opened' : 'community_place_opened', { kind })
    }
    // Once per item, not per refresh.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [Boolean(detail.data), kind, nodeId])

  const [dialog, setDialog] = useState<'report' | 'cancel' | 'delete' | null>(null)
  const [dialogBusy, setDialogBusy] = useState(false)
  const [reportReason, setReportReason] = useState('spam')
  const [reportNote, setReportNote] = useState('')

  const node = withOverride(detail.data?.node ?? null)
  const related = useMemo(() => (detail.data?.related ?? []).map(withOverride), [detail.data, withOverride])
  const mapView = useMemo(
    () => (node?.latitude != null && node.longitude != null ? { latitude: node.latitude, longitude: node.longitude, radiusKm: 0.6, token: 1 } : null),
    [node?.latitude, node?.longitude],
  )

  const runDialog = useCallback(async () => {
    if (!node) return
    setDialogBusy(true)
    try {
      if (dialog === 'report') {
        const result = await api.community.reportEvent(node.id, reportReason, reportNote)
        api.community.track('community_event_reported', { reason: reportReason })
        toast.success(result.message)
      } else if (dialog === 'cancel') {
        await api.community.updateEvent(node.id, { status: 'cancelled' })
        toast.success('Event cancelled. Attendees will see it as cancelled.')
        refresh()
      } else if (dialog === 'delete') {
        await api.community.deleteEvent(node.id)
        api.community.track('community_event_deleted')
        toast.success('Event deleted')
        router.push('/community')
        return
      }
      setDialog(null)
    } catch (reason) {
      const message = friendlyError(reason, 'finish that')
      toast.error(message.title.startsWith("That didn't") ? message.body : message.title)
    } finally {
      setDialogBusy(false)
    }
  }, [dialog, node, refresh, reportNote, reportReason, router])

  if (detail.isLoading && !detail.data) {
    return (
      <div className="mx-auto max-w-4xl space-y-4">
        <div className="h-48 animate-pulse rounded-3xl bg-white/[0.06] motion-reduce:animate-none" />
        <ResultSkeleton rows={4} />
      </div>
    )
  }
  if (!node) {
    const error = friendlyError({ status: detail.error?.toLowerCase().includes('no longer') ? 404 : undefined, message: detail.error ?? '' }, 'load this')
    return (
      <div className="mx-auto max-w-lg">
        <StateMessage
          icon={XCircle}
          title={error.title}
          body={error.body}
          tone="warning"
          action={error.retry ? { label: 'Try again', onClick: refresh } : undefined}
        />
        <div className="flex justify-center">
          <Link href="/community" className="min-h-[44px] rounded-xl px-4 py-2.5 text-sm font-semibold text-lyo-300 hover:bg-white/5">
            Back to the map
          </Link>
        </div>
      </div>
    )
  }

  const busy = actions.busy.has(node.key)
  const isEvent = node.kind === 'event'
  const canEdit = Boolean(detail.data?.can_edit)
  const directions = directionsUrl(node)
  const website = safeWebUrl(node.website_url)
  const meeting = safeWebUrl(node.meeting_url)
  const image = safeWebUrl(node.image_url)
  const calendar = isEvent && node.lifecycle !== 'past' && node.lifecycle !== 'cancelled' ? googleCalendarUrl(node) : null
  const hostName = node.organizer_name || node.host?.name
  const closed = node.lifecycle === 'past' || node.lifecycle === 'cancelled'

  return (
    <article className="mx-auto max-w-4xl space-y-5 pb-8" aria-labelledby="node-title">
      <button type="button" onClick={() => (window.history.length > 1 ? router.back() : router.push('/community'))} className="flex min-h-[44px] items-center gap-2 rounded-xl pr-3 text-sm font-medium text-white/65 hover:text-white">
        <ArrowLeft className="h-4 w-4" aria-hidden="true" /> Back
      </button>

      {image && (
        <div className="aspect-[16/7] overflow-hidden rounded-3xl border border-white/10 bg-white/5">
          <img src={image} alt="" className="h-full w-full object-cover" />
        </div>
      )}

      <header className="space-y-2">
        <div className="flex flex-wrap items-center gap-2">
          <CategoryBadge node={node} />
          <LifecyclePill node={node} />
          {node.visibility && node.visibility !== 'public' && (
            <span className="rounded-full bg-white/10 px-2 py-0.5 text-[11px] font-semibold text-white/60">{node.visibility === 'unlisted' ? 'Unlisted' : 'Private'}</span>
          )}
        </div>
        <h1 id="node-title" className="font-display text-2xl font-semibold leading-tight text-white md:text-3xl">{node.title}</h1>
        {hostName && <p className="text-sm text-white/55">Hosted by <span className="text-white/80">{hostName}</span></p>}
        {node.lifecycle === 'cancelled' && (
          <p className="rounded-2xl bg-red-500/10 px-4 py-3 text-sm text-red-200" role="status">This event was cancelled by the host.</p>
        )}
        {node.lifecycle === 'past' && (
          <p className="rounded-2xl bg-white/[0.06] px-4 py-3 text-sm text-white/65" role="status">This event has ended.</p>
        )}
      </header>

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div className="space-y-5">
          <section className="space-y-4 rounded-3xl border border-white/[0.08] bg-white/[0.03] p-5">
            <NodeFacts node={node} />
            {isEvent && !closed && <RsvpControl node={node} busy={busy} onRsvp={(status) => void actions.setRsvp(node, status)} size="lg" />}
            {node.kind === 'study_group' && !node.is_owner && (
              <button type="button" disabled={busy} onClick={() => void actions.toggleMembership(node)} className={cn('flex min-h-[48px] w-full items-center justify-center gap-2 rounded-xl text-sm font-semibold transition disabled:opacity-50', node.is_joined ? 'border border-white/15 text-white/80 hover:bg-white/10' : 'bg-lyo-500 text-white hover:bg-lyo-400')}>
                <Users className="h-4 w-4" aria-hidden="true" /> {node.is_joined ? 'Leave group' : 'Join group'}
              </button>
            )}
            <div className="flex flex-wrap gap-2">
              <IconAction label={node.is_saved ? 'Remove from saved' : 'Save'} onClick={() => void actions.toggleSave(node)} pressed={node.is_saved} disabled={busy}>
                <Bookmark className={cn('h-4 w-4', node.is_saved && 'fill-current text-lyo-300')} aria-hidden="true" />
                <span>{node.is_saved ? 'Saved' : 'Save'}</span>
              </IconAction>
              <IconAction label="Share" onClick={() => void shareNode(node)}>
                <Share2 className="h-4 w-4" aria-hidden="true" />
                <span>Share</span>
              </IconAction>
              {calendar && (
                <>
                  <IconAction label="Add to calendar (download .ics)" onClick={() => downloadIcs(node)}>
                    <CalendarPlus className="h-4 w-4" aria-hidden="true" />
                    <span>Add to calendar</span>
                  </IconAction>
                  <IconAction label="Add to Google Calendar" href={calendar}>
                    <span>Google Calendar</span>
                  </IconAction>
                </>
              )}
              {directions && (
                <IconAction label="Directions (opens maps)" href={directions}>
                  <Navigation className="h-4 w-4" aria-hidden="true" />
                  <span>Directions</span>
                </IconAction>
              )}
              {meeting && !closed && (
                <IconAction label="Join online" href={meeting}>
                  <Video className="h-4 w-4" aria-hidden="true" />
                  <span>Join online</span>
                </IconAction>
              )}
            </div>
          </section>

          {(node.description || node.relevance) && (
            <section className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-5">
              <h2 className="mb-2 font-display text-base font-semibold text-white">{isEvent ? 'About this event' : 'About'}</h2>
              {node.description && <p className="whitespace-pre-line text-[15px] leading-relaxed text-white/75">{node.description}</p>}
              {node.relevance && <p className={cn('text-sm text-white/60', node.description && 'mt-3')}>{node.relevance}</p>}
            </section>
          )}

          {!isEvent && (website || node.phone || node.email || node.opening_hours) && (
            <section className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-5">
              <h2 className="mb-3 font-display text-base font-semibold text-white">Visit and contact</h2>
              <ul className="space-y-2 text-sm text-white/75">
                {node.opening_hours && <li><span className="text-white/45">Hours · </span>{node.opening_hours}</li>}
                {website && <li><a href={website} target="_blank" rel="noreferrer" className="inline-flex items-center gap-2 text-lyo-300 hover:underline"><Globe className="h-4 w-4" aria-hidden="true" />{new URL(website).hostname.replace(/^www\./, '')}</a></li>}
                {node.phone && <li><a href={`tel:${node.phone.replace(/[^\d+]/g, '')}`} className="inline-flex items-center gap-2 hover:text-white"><Phone className="h-4 w-4 text-white/45" aria-hidden="true" />{node.phone}</a></li>}
                {node.email && <li><a href={`mailto:${node.email}`} className="inline-flex items-center gap-2 hover:text-white"><Mail className="h-4 w-4 text-white/45" aria-hidden="true" />{node.email}</a></li>}
              </ul>
              {node.source === 'openstreetmap' && safeWebUrl(node.source_url) && (
                <a href={safeWebUrl(node.source_url) as string} target="_blank" rel="noreferrer" className="mt-3 inline-flex items-center gap-1 text-xs text-white/40 hover:text-white/70">
                  Place data from OpenStreetMap <ExternalLink className="h-3 w-3" aria-hidden="true" />
                </a>
              )}
            </section>
          )}

          {isEvent && website && (
            <a href={website} target="_blank" rel="noreferrer" className="flex min-h-[48px] items-center justify-between rounded-2xl border border-white/10 px-4 text-sm text-white/80 hover:bg-white/5">
              <span className="inline-flex items-center gap-2"><Globe className="h-4 w-4 text-white/45" aria-hidden="true" />Event website</span>
              <ExternalLink className="h-4 w-4 text-white/40" aria-hidden="true" />
            </a>
          )}
        </div>

        <aside className="space-y-4">
          {mapView && (
            <div className="relative h-56 overflow-hidden rounded-3xl border border-white/10">
              <div className="absolute inset-0 isolate">
                <CommunityEventMap nodes={[node]} view={mapView} selectedKey={node.key} onSelect={() => undefined} />
              </div>
            </div>
          )}
          {canEdit && isEvent && (
            <section className="space-y-2 rounded-3xl border border-white/[0.08] bg-white/[0.03] p-4">
              <h2 className="text-sm font-semibold text-white">You&apos;re hosting</h2>
              {!closed && (
                <Link href={`/community/events/${node.id}/edit`} className="flex min-h-[44px] items-center gap-2 rounded-xl px-3 text-sm text-white/80 hover:bg-white/10">
                  <Pencil className="h-4 w-4" aria-hidden="true" /> Edit event
                </Link>
              )}
              {!closed && (
                <button type="button" onClick={() => setDialog('cancel')} className="flex min-h-[44px] w-full items-center gap-2 rounded-xl px-3 text-sm text-amber-200 hover:bg-white/10">
                  <XCircle className="h-4 w-4" aria-hidden="true" /> Cancel event
                </button>
              )}
              <button type="button" onClick={() => setDialog('delete')} className="flex min-h-[44px] w-full items-center gap-2 rounded-xl px-3 text-sm text-red-300 hover:bg-white/10">
                <Trash2 className="h-4 w-4" aria-hidden="true" /> Delete event
              </button>
            </section>
          )}
          {isEvent && !canEdit && (
            <button type="button" onClick={() => setDialog('report')} className="flex min-h-[44px] items-center gap-2 rounded-xl px-3 text-sm text-white/50 hover:bg-white/5 hover:text-white/80">
              <Flag className="h-4 w-4" aria-hidden="true" /> Report this event
            </button>
          )}
        </aside>
      </div>

      {related.length > 0 && (
        <section aria-labelledby="related-title" className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-4">
          <h2 id="related-title" className="mb-2 px-1 font-display text-base font-semibold text-white">More learning nearby</h2>
          <ul className="grid gap-1 md:grid-cols-2">
            {related.map((item) => (
              <li key={item.key}>
                <NodeRow node={item} onSelect={(next) => router.push(detailPath(next))} />
              </li>
            ))}
          </ul>
        </section>
      )}

      {dialog === 'report' && (
        <ConfirmDialog title="Report this event" body="Tell us what's wrong. Reports are anonymous to the host." confirmLabel="Send report" busy={dialogBusy} onConfirm={() => void runDialog()} onClose={() => setDialog(null)}>
          <fieldset className="mt-4 space-y-1.5">
            <legend className="sr-only">Reason</legend>
            {REPORT_REASONS.map((reason) => (
              <label key={reason.value} className="flex min-h-[44px] items-center gap-3 rounded-xl px-2 text-sm text-white/80 hover:bg-white/5">
                <input type="radio" name="report-reason" value={reason.value} checked={reportReason === reason.value} onChange={() => setReportReason(reason.value)} className="accent-[#6366F1]" />
                {reason.label}
              </label>
            ))}
          </fieldset>
          <label className="mt-3 block text-sm text-white/65">
            Details <span className="text-white/40">(optional)</span>
            <textarea value={reportNote} onChange={(event) => setReportNote(event.target.value)} rows={3} maxLength={1000} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-white focus:border-lyo-500 focus:outline-none" />
          </label>
        </ConfirmDialog>
      )}
      {dialog === 'cancel' && (
        <ConfirmDialog title="Cancel this event?" body="It stays visible as cancelled to people who RSVP'd, and leaves the map." confirmLabel="Cancel event" destructive busy={dialogBusy} onConfirm={() => void runDialog()} onClose={() => setDialog(null)} />
      )}
      {dialog === 'delete' && (
        <ConfirmDialog title="Delete this event?" body="This removes it for everyone, including saved copies and RSVPs. This can't be undone." confirmLabel="Delete" destructive busy={dialogBusy} onConfirm={() => void runDialog()} onClose={() => setDialog(null)} />
      )}
    </article>
  )
}
