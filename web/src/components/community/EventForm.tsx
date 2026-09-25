'use client'

import { useMemo, useRef, useState } from 'react'
import { ImagePlus, Loader2, X } from 'lucide-react'
import { api } from '@/lib/api'
import { friendlyError } from '@/lib/community-contract.mjs'
import { cn } from '@/lib/utils'
import type { AttendanceMode, CommunityEventInput, CommunityEventRecord, CommunityEventType, EventVisibility } from '@/types'
import PlaceSearchField, { type ChosenPlace } from './PlaceSearchField'

const EVENT_TYPES: Array<{ value: CommunityEventType; label: string }> = [
  { value: 'workshop', label: 'Workshop' },
  { value: 'class', label: 'Class' },
  { value: 'lecture', label: 'Lecture or talk' },
  { value: 'seminar', label: 'Seminar' },
  { value: 'study_session', label: 'Study session or meetup' },
  { value: 'discussion', label: 'Discussion' },
  { value: 'office_hours', label: 'Office hours' },
  { value: 'networking', label: 'Career or networking' },
  { value: 'project_showcase', label: 'Project showcase' },
  { value: 'other', label: 'Other learning event' },
]

const MODES: Array<{ value: AttendanceMode; label: string }> = [
  { value: 'in_person', label: 'In person' },
  { value: 'online', label: 'Online' },
  { value: 'hybrid', label: 'Hybrid' },
]

const VISIBILITY: Array<{ value: EventVisibility; label: string; hint: string }> = [
  { value: 'public', label: 'Public', hint: 'On the map and in search' },
  { value: 'unlisted', label: 'Unlisted', hint: 'Only people with the link' },
  { value: 'private', label: 'Private', hint: 'Only you — a draft until you share it' },
]

/** `YYYY-MM-DDTHH:mm` in the device's zone, for datetime-local inputs. */
function toLocalInput(date: Date): string {
  const pad = (value: number) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function defaultStart(): Date {
  const date = new Date(Date.now() + 24 * 60 * 60 * 1000)
  date.setMinutes(0, 0, 0)
  date.setHours(Math.max(9, Math.min(date.getHours(), 18)))
  return date
}

function newRequestId(): string {
  try {
    return `web-${crypto.randomUUID()}`
  } catch {
    return `web-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`
  }
}

export interface EventFormProps {
  initial?: CommunityEventRecord | null
  /** Prefill from the quick Create sheet (title, description, ISO start). */
  draft?: { title?: string; description?: string; start?: string }
  origin?: { latitude: number; longitude: number } | null
  onSaved: (event: CommunityEventRecord) => void
  onCancel: () => void
}

export default function EventForm({ initial, draft, origin, onSaved, onCancel }: EventFormProps) {
  const editing = Boolean(initial)
  const start = useMemo(() => {
    if (initial) return new Date(initial.start_time)
    const drafted = draft?.start ? new Date(draft.start) : null
    return drafted && !Number.isNaN(drafted.getTime()) && drafted > new Date() ? drafted : defaultStart()
    // The draft is read once, when the form opens.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initial])
  const [title, setTitle] = useState(initial?.title ?? draft?.title ?? '')
  const [description, setDescription] = useState(initial?.description ?? draft?.description ?? '')
  const [eventType, setEventType] = useState<CommunityEventType>(initial?.event_type ?? 'workshop')
  const [startsAt, setStartsAt] = useState(toLocalInput(start))
  const [endsAt, setEndsAt] = useState(
    toLocalInput(initial ? new Date(initial.end_time) : new Date(start.getTime() + 2 * 60 * 60 * 1000)),
  )
  const [mode, setMode] = useState<AttendanceMode>(
    initial?.attendance_mode ?? (initial?.is_online ? 'online' : 'in_person'),
  )
  const [place, setPlace] = useState<ChosenPlace | null>(
    initial && initial.latitude != null && initial.longitude != null
      ? {
          label: initial.address || initial.location || 'Event location',
          name: initial.venue_name || initial.location || 'Event location',
          latitude: initial.latitude,
          longitude: initial.longitude,
        }
      : null,
  )
  const [venueName, setVenueName] = useState(initial?.venue_name ?? '')
  const [meetingUrl, setMeetingUrl] = useState(initial?.meeting_url ?? '')
  const [websiteUrl, setWebsiteUrl] = useState(initial?.website_url ?? '')
  const [organizerName, setOrganizerName] = useState(initial?.organizer_name ?? '')
  const [imageUrl, setImageUrl] = useState(initial?.image_url ?? '')
  const [capacity, setCapacity] = useState(initial?.max_attendees ? String(initial.max_attendees) : '')
  const [priceType, setPriceType] = useState<'free' | 'paid'>(initial?.price_type ?? 'free')
  const [price, setPrice] = useState(initial?.price_amount != null ? String(initial.price_amount) : '')
  const [visibility, setVisibility] = useState<EventVisibility>(initial?.visibility ?? 'public')
  const [submitting, setSubmitting] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  // One id per form: a double tap or a retry after a timeout returns the
  // event the first submit created instead of a duplicate.
  const requestId = useRef(newRequestId())
  const fileInput = useRef<HTMLInputElement | null>(null)

  const needsPlace = mode !== 'online'
  const needsLink = mode !== 'in_person'

  const validate = (): string | null => {
    if (!title.trim()) return 'Give your event a title.'
    const startDate = new Date(startsAt)
    const endDate = new Date(endsAt)
    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) return 'Choose when the event starts and ends.'
    if (endDate <= startDate) return 'The event must end after it starts.'
    if (endDate <= new Date() && (!editing || startsAt !== toLocalInput(start))) return 'Choose a time in the future.'
    if (needsPlace && !place) return 'Search for the address, then adjust the pin if needed.'
    if (needsLink && mode === 'online' && !meetingUrl.trim()) return 'Add the link people will use to join.'
    if (priceType === 'paid' && price && Number(price) < 0) return 'The price cannot be negative.'
    return null
  }

  const uploadImage = async (file: File) => {
    if (!file.type.startsWith('image/')) {
      setError('Choose an image file.')
      return
    }
    if (file.size > 8 * 1024 * 1024) {
      setError('Images can be up to 8 MB.')
      return
    }
    setUploading(true)
    setError(null)
    try {
      const uploaded = await api.media.upload(file, 'community')
      setImageUrl(uploaded.url)
    } catch {
      setError("We couldn't upload that image. You can publish without one.")
    } finally {
      setUploading(false)
    }
  }

  const submit = async (event: React.FormEvent) => {
    event.preventDefault()
    if (submitting) return
    const problem = validate()
    if (problem) {
      setError(problem)
      return
    }
    setSubmitting(true)
    setError(null)
    const payload: CommunityEventInput = {
      title: title.trim(),
      description: description.trim() || null,
      event_type: eventType,
      start_time: new Date(startsAt).toISOString(),
      end_time: new Date(endsAt).toISOString(),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
      attendance_mode: mode,
      is_online: mode !== 'in_person',
      location: needsPlace ? place?.label ?? null : 'Online',
      venue_name: needsPlace ? venueName.trim() || place?.name || null : null,
      address: needsPlace ? place?.label ?? null : null,
      latitude: needsPlace ? place?.latitude ?? null : null,
      longitude: needsPlace ? place?.longitude ?? null : null,
      meeting_url: needsLink ? meetingUrl.trim() || null : null,
      website_url: websiteUrl.trim() || null,
      image_url: imageUrl || null,
      organizer_name: organizerName.trim() || null,
      max_attendees: capacity ? Math.max(1, Math.min(10000, Number(capacity))) : null,
      price_type: priceType,
      price_amount: priceType === 'paid' && price ? Number(price) : null,
      currency: priceType === 'paid' ? 'USD' : null,
      visibility,
    }
    try {
      const saved = initial
        ? await api.community.updateEvent(String(initial.id), payload)
        : await api.community.createEvent({ ...payload, client_request_id: requestId.current })
      api.community.track(initial ? 'community_event_updated' : 'community_event_created', {
        event_type: eventType,
        mode,
        visibility,
      })
      onSaved(saved)
    } catch (reason) {
      const message = friendlyError(reason, editing ? 'save your changes' : 'publish this event')
      setError(message.title.startsWith("That didn't") ? message.body : `${message.title} ${message.body}`)
    } finally {
      setSubmitting(false)
    }
  }

  const field = 'mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white placeholder:text-white/35 focus:border-lyo-500 focus:outline-none'
  const segment = (active: boolean) =>
    cn(
      'min-h-[44px] rounded-lg px-3 text-sm font-medium transition',
      active ? 'bg-lyo-500 text-white' : 'text-white/65 hover:bg-white/10 hover:text-white',
    )

  return (
    <form onSubmit={submit} className="space-y-6" noValidate>
      <section className="space-y-4 rounded-3xl border border-white/[0.08] bg-white/[0.03] p-5">
        <h2 className="font-display text-lg font-semibold text-white">What</h2>
        <label className="block text-sm text-white/70">
          Title
          <input value={title} onChange={(event) => setTitle(event.target.value)} maxLength={200} required placeholder="e.g. Intro to Python for beginners" className={field} />
        </label>
        <label className="block text-sm text-white/70">
          Type of event
          <select value={eventType} onChange={(event) => setEventType(event.target.value as CommunityEventType)} className={cn(field, 'bg-[#121a3c]')}>
            {EVENT_TYPES.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
        <label className="block text-sm text-white/70">
          Description
          <textarea value={description} onChange={(event) => setDescription(event.target.value)} rows={5} maxLength={4000} placeholder="What will people learn? Who is it for? What should they bring?" className={cn(field, 'resize-y')} />
        </label>
        <div className="text-sm text-white/70">
          Cover image <span className="text-white/40">(optional)</span>
          <div className="mt-1.5 flex items-center gap-3">
            {imageUrl ? (
              <div className="relative h-20 w-32 overflow-hidden rounded-xl border border-white/10">
                <img src={imageUrl} alt="Event cover" className="h-full w-full object-cover" />
                <button type="button" onClick={() => setImageUrl('')} aria-label="Remove image" className="absolute right-1 top-1 flex h-7 w-7 items-center justify-center rounded-lg bg-black/60 text-white">
                  <X className="h-4 w-4" aria-hidden="true" />
                </button>
              </div>
            ) : (
              <button type="button" onClick={() => fileInput.current?.click()} disabled={uploading} className="flex min-h-[44px] items-center gap-2 rounded-xl border border-dashed border-white/20 px-4 text-sm text-white/70 hover:border-lyo-400/50 hover:text-white">
                {uploading ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" /> : <ImagePlus className="h-4 w-4" aria-hidden="true" />}
                {uploading ? 'Uploading…' : 'Add image'}
              </button>
            )}
            <input ref={fileInput} type="file" accept="image/*" className="sr-only" tabIndex={-1} onChange={(event) => event.target.files?.[0] && void uploadImage(event.target.files[0])} />
          </div>
        </div>
      </section>

      <section className="space-y-4 rounded-3xl border border-white/[0.08] bg-white/[0.03] p-5">
        <h2 className="font-display text-lg font-semibold text-white">When</h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="text-sm text-white/70">
            Starts
            <input type="datetime-local" value={startsAt} onChange={(event) => setStartsAt(event.target.value)} required className={cn(field, '[color-scheme:dark]')} />
          </label>
          <label className="text-sm text-white/70">
            Ends
            <input type="datetime-local" value={endsAt} min={startsAt} onChange={(event) => setEndsAt(event.target.value)} required className={cn(field, '[color-scheme:dark]')} />
          </label>
        </div>
        <p className="text-xs text-white/45">Times are in your timezone ({Intl.DateTimeFormat().resolvedOptions().timeZone}). Everyone sees them in theirs.</p>
      </section>

      <section className="space-y-4 rounded-3xl border border-white/[0.08] bg-white/[0.03] p-5">
        <h2 className="font-display text-lg font-semibold text-white">Where</h2>
        <div className="grid grid-cols-3 gap-1 rounded-xl border border-white/10 bg-white/5 p-1" role="radiogroup" aria-label="Format">
          {MODES.map((option) => (
            <button key={option.value} type="button" role="radio" aria-checked={mode === option.value} onClick={() => setMode(option.value)} className={segment(mode === option.value)}>
              {option.label}
            </button>
          ))}
        </div>
        {needsPlace && (
          <>
            <PlaceSearchField value={place} onChange={setPlace} label="Address" withMap origin={origin} />
            <label className="block text-sm text-white/70">
              Room or venue name <span className="text-white/40">(optional)</span>
              <input value={venueName} onChange={(event) => setVenueName(event.target.value)} maxLength={200} placeholder="e.g. Room 204, Main Library" className={field} />
            </label>
          </>
        )}
        {needsLink && (
          <label className="block text-sm text-white/70">
            Online link {mode === 'hybrid' && <span className="text-white/40">(optional)</span>}
            <input value={meetingUrl} onChange={(event) => setMeetingUrl(event.target.value)} inputMode="url" placeholder="https://…" className={field} />
            <span className="mt-1 block text-xs text-white/45">Only people who RSVP see this link.</span>
          </label>
        )}
      </section>

      <section className="space-y-4 rounded-3xl border border-white/[0.08] bg-white/[0.03] p-5">
        <h2 className="font-display text-lg font-semibold text-white">Details</h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="text-sm text-white/70">
            Organizer <span className="text-white/40">(optional)</span>
            <input value={organizerName} onChange={(event) => setOrganizerName(event.target.value)} maxLength={200} placeholder="e.g. Queens Coding Club" className={field} />
          </label>
          <label className="text-sm text-white/70">
            Capacity <span className="text-white/40">(optional)</span>
            <input type="number" min={1} max={10000} value={capacity} onChange={(event) => setCapacity(event.target.value)} placeholder="No limit" className={field} />
          </label>
        </div>
        <label className="block text-sm text-white/70">
          Website or registration link <span className="text-white/40">(optional)</span>
          <input value={websiteUrl} onChange={(event) => setWebsiteUrl(event.target.value)} inputMode="url" placeholder="https://…" className={field} />
        </label>
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="text-sm text-white/70">
            Cost
            <div className="mt-1.5 grid grid-cols-2 gap-1 rounded-xl border border-white/10 bg-white/5 p-1" role="radiogroup" aria-label="Cost">
              {(['free', 'paid'] as const).map((value) => (
                <button key={value} type="button" role="radio" aria-checked={priceType === value} onClick={() => setPriceType(value)} className={segment(priceType === value)}>
                  {value === 'free' ? 'Free' : 'Paid'}
                </button>
              ))}
            </div>
          </div>
          {priceType === 'paid' && (
            <label className="text-sm text-white/70">
              Price (USD)
              <input type="number" min={0} step="0.01" value={price} onChange={(event) => setPrice(event.target.value)} placeholder="0.00" className={field} />
            </label>
          )}
        </div>
        <fieldset>
          <legend className="text-sm text-white/70">Who can find it</legend>
          <div className="mt-1.5 grid gap-2 sm:grid-cols-3">
            {VISIBILITY.map((option) => (
              <label key={option.value} className={cn('flex min-h-[64px] cursor-pointer flex-col justify-center rounded-xl border px-3 py-2', visibility === option.value ? 'border-lyo-400/60 bg-lyo-500/15' : 'border-white/10 hover:bg-white/5')}>
                <span className="flex items-center gap-2 text-sm font-medium text-white">
                  <input type="radio" name="visibility" value={option.value} checked={visibility === option.value} onChange={() => setVisibility(option.value)} className="accent-[#6366F1]" />
                  {option.label}
                </span>
                <span className="mt-0.5 text-xs text-white/50">{option.hint}</span>
              </label>
            ))}
          </div>
        </fieldset>
      </section>

      {error && <p role="alert" className="rounded-2xl bg-red-500/10 px-4 py-3 text-sm text-red-200">{error}</p>}

      <div className="sticky bottom-24 z-10 flex justify-end gap-3 rounded-2xl border border-white/10 bg-[#0b1230]/95 p-3 backdrop-blur-xl md:bottom-4">
        <button type="button" onClick={onCancel} disabled={submitting} className="min-h-[44px] rounded-xl border border-white/15 px-4 text-sm text-white/75 hover:bg-white/10">
          Cancel
        </button>
        <button type="submit" disabled={submitting || uploading} className="flex min-h-[44px] min-w-36 items-center justify-center gap-2 rounded-xl bg-lyo-500 px-5 text-sm font-semibold text-white hover:bg-lyo-400 disabled:opacity-50">
          {submitting && <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />}
          {submitting ? 'Saving…' : editing ? 'Save changes' : 'Publish event'}
        </button>
      </div>
    </form>
  )
}
