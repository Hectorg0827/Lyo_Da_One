'use client'

import { useState } from 'react'
import { Loader2, LocateFixed, X } from 'lucide-react'
import { api } from '@/lib/api'
import { cn } from '@/lib/utils'

type ItemType = 'event' | 'group'

export default function CreateCommunityItemModal({
  onClose,
  onCreated,
  initialType = 'event',
}: {
  onClose: () => void
  onCreated: (type: ItemType) => void
  initialType?: ItemType
}) {
  const [type, setType] = useState<ItemType>(initialType)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [location, setLocation] = useState('')
  const [startTime, setStartTime] = useState('')
  const [endTime, setEndTime] = useState('')
  const [maxPeople, setMaxPeople] = useState(20)
  const [isPrivate, setIsPrivate] = useState(false)
  const [coordinates, setCoordinates] = useState<{ latitude: number; longitude: number } | null>(null)
  const [locating, setLocating] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const locate = () => {
    if (!navigator.geolocation) {
      setError('Location is not available in this browser.')
      return
    }
    setLocating(true)
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        setCoordinates({ latitude: coords.latitude, longitude: coords.longitude })
        setLocating(false)
      },
      () => {
        setError('Location permission was not granted. You can still create an online event.')
        setLocating(false)
      },
      { enableHighAccuracy: true, timeout: 10000 },
    )
  }

  const submit = async () => {
    if (!title.trim() || submitting) return
    if (type === 'event' && (!startTime || !endTime)) {
      setError('Start and end times are required.')
      return
    }
    setSubmitting(true)
    setError(null)
    try {
      if (type === 'group') {
        await api.community.createGroup({
          name: title.trim(),
          description: description.trim() || undefined,
          privacy: isPrivate ? 'private' : 'public',
          max_members: maxPeople,
          requires_approval: isPrivate,
        })
      } else {
        await api.community.createEvent({
          title: title.trim(),
          description: description.trim() || undefined,
          event_type: 'study_session',
          start_time: new Date(startTime).toISOString(),
          end_time: new Date(endTime).toISOString(),
          location: location.trim() || 'Online',
          max_attendees: maxPeople,
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
          ...coordinates,
        })
      }
      onCreated(type)
      onClose()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : `Unable to create ${type}`)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section role="dialog" aria-modal="true" aria-labelledby="create-item-title" className="w-full max-w-xl overflow-hidden rounded-2xl border border-white/10 bg-[var(--surface)] shadow-2xl">
        <header className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <h2 id="create-item-title" className="text-lg font-semibold text-white">Create in Community</h2>
          <button onClick={onClose} aria-label="Close" className="rounded-lg p-2 text-white/50 hover:bg-white/10 hover:text-white"><X className="h-5 w-5" /></button>
        </header>

        <div className="max-h-[75vh] space-y-4 overflow-y-auto p-5">
          <div className="grid grid-cols-2 gap-1 rounded-xl border border-white/10 bg-white/5 p-1">
            {(['event', 'group'] as const).map((item) => (
              <button key={item} onClick={() => setType(item)} className={cn('rounded-lg px-4 py-2.5 text-sm font-medium capitalize transition', type === item ? 'bg-lyo-500 text-white' : 'text-white/60 hover:bg-white/10 hover:text-white')}>
                {item === 'event' ? 'Event' : 'Study group'}
              </button>
            ))}
          </div>

          <label className="block text-sm text-white/65">
            {type === 'event' ? 'Event title' : 'Group name'}
            <input value={title} onChange={(event) => setTitle(event.target.value)} maxLength={200} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" />
          </label>
          <label className="block text-sm text-white/65">
            Description
            <textarea value={description} onChange={(event) => setDescription(event.target.value)} rows={3} maxLength={2000} className="mt-1.5 w-full resize-y rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" />
          </label>

          {type === 'event' ? (
            <>
              <div className="grid gap-3 sm:grid-cols-2">
                <label className="text-sm text-white/65">Starts<input type="datetime-local" value={startTime} onChange={(event) => setStartTime(event.target.value)} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-white [color-scheme:dark] focus:border-lyo-500 focus:outline-none" /></label>
                <label className="text-sm text-white/65">Ends<input type="datetime-local" value={endTime} onChange={(event) => setEndTime(event.target.value)} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-white [color-scheme:dark] focus:border-lyo-500 focus:outline-none" /></label>
              </div>
              <label className="block text-sm text-white/65">Location or online<input value={location} onChange={(event) => setLocation(event.target.value)} placeholder="Online" className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" /></label>
              <button type="button" onClick={locate} disabled={locating} className="flex w-full items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/70 hover:border-lyo-500/60 hover:text-white">
                {locating ? <Loader2 className="h-4 w-4 animate-spin" /> : <LocateFixed className="h-4 w-4" />}
                {coordinates ? 'Location added to map' : 'Use my location for the event map'}
              </button>
            </>
          ) : (
            <label className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/70">
              Private group (approval required)
              <input type="checkbox" checked={isPrivate} onChange={(event) => setIsPrivate(event.target.checked)} className="h-4 w-4 accent-[#6366F1]" />
            </label>
          )}

          <label className="block text-sm text-white/65">{type === 'event' ? 'Maximum attendees' : 'Maximum members'}<input type="number" min={2} max={type === 'event' ? 10000 : 1000} value={maxPeople} onChange={(event) => setMaxPeople(Number(event.target.value))} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" /></label>
          {error && <p role="alert" className="text-sm text-red-400">{error}</p>}
        </div>

        <footer className="flex justify-end gap-3 border-t border-white/10 px-5 py-4">
          <button onClick={onClose} disabled={submitting} className="rounded-xl border border-white/15 px-4 py-2.5 text-sm text-white/70 hover:bg-white/10">Cancel</button>
          <button onClick={submit} disabled={!title.trim() || submitting} className="flex min-w-32 items-center justify-center gap-2 rounded-xl bg-lyo-500 px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-50">
            {submitting && <Loader2 className="h-4 w-4 animate-spin" />}{submitting ? 'Creating…' : `Create ${type}`}
          </button>
        </footer>
      </section>
    </div>
  )
}
