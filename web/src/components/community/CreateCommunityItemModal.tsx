'use client'

import { useState } from 'react'
import { Loader2, LocateFixed, X } from 'lucide-react'
import { api } from '@/lib/api'
import { cn } from '@/lib/utils'

type ItemType = 'event' | 'group' | 'tutor'
type EventType = 'study_session' | 'workshop' | 'class' | 'seminar' | 'lecture' | 'discussion' | 'networking' | 'office_hours'

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
  const [meetingUrl, setMeetingUrl] = useState('')
  const [isOnline, setIsOnline] = useState(false)
  const [eventType, setEventType] = useState<EventType>('study_session')
  const [subject, setSubject] = useState('')
  const [pricePerHour, setPricePerHour] = useState(0)
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
    if (type === 'event' && new Date(endTime) <= new Date(startTime)) {
      setError('The event must end after it starts.')
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
          location: location.trim() || undefined,
          is_online: isOnline,
          meeting_url: meetingUrl.trim() || undefined,
          ...(!isOnline ? coordinates : null),
        })
      } else if (type === 'tutor') {
        if (!subject.trim()) throw new Error('A subject is required for tutoring.')
        await api.community.createTutor({
          title: title.trim(),
          description: description.trim() || undefined,
          subject: subject.trim(),
          price_per_hour: pricePerHour,
          currency: 'USD',
          duration_minutes: 60,
          location: location.trim() || undefined,
          is_online: isOnline,
          meeting_url: meetingUrl.trim() || undefined,
          ...(!isOnline ? coordinates : null),
        })
      } else {
        await api.community.createEvent({
          title: title.trim(),
          description: description.trim() || undefined,
          event_type: eventType,
          start_time: new Date(startTime).toISOString(),
          end_time: new Date(endTime).toISOString(),
          location: location.trim() || (isOnline ? 'Online' : undefined),
          is_online: isOnline,
          meeting_url: meetingUrl.trim() || undefined,
          max_attendees: maxPeople,
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
          ...(!isOnline ? coordinates : null),
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
      <section role="dialog" aria-modal="true" aria-labelledby="create-item-title" className="w-full max-w-xl overflow-hidden rounded-2xl border border-white/12 bg-[#0d0f18]/95 backdrop-blur-2xl shadow-2xl">
        <header className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <h2 id="create-item-title" className="text-lg font-semibold text-white">Create in Community</h2>
          <button onClick={onClose} aria-label="Close" className="rounded-lg p-2 text-white/50 hover:bg-white/10 hover:text-white"><X className="h-5 w-5" /></button>
        </header>

        <div className="max-h-[75vh] space-y-4 overflow-y-auto p-5">
          <div className="grid grid-cols-3 gap-1 rounded-xl border border-white/10 bg-white/5 p-1">
            {(['event', 'group', 'tutor'] as const).map((item) => (
              <button key={item} onClick={() => setType(item)} className={cn('rounded-lg px-4 py-2.5 text-sm font-medium capitalize transition', type === item ? 'bg-lyo-500 text-white' : 'text-white/60 hover:bg-white/10 hover:text-white')}>
                {item === 'event' ? 'Event / class' : item === 'group' ? 'Study group' : 'Tutoring'}
              </button>
            ))}
          </div>

          <label className="block text-sm text-white/65">
            {type === 'event' ? 'Event or class title' : type === 'group' ? 'Group name' : 'Tutoring title'}
            <input value={title} onChange={(event) => setTitle(event.target.value)} maxLength={200} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" />
          </label>
          <label className="block text-sm text-white/65">
            Description
            <textarea value={description} onChange={(event) => setDescription(event.target.value)} rows={3} maxLength={2000} className="mt-1.5 w-full resize-y rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" />
          </label>

          {type === 'event' ? (
            <>
              <label className="block text-sm text-white/65">Learning format<select value={eventType} onChange={(event) => setEventType(event.target.value as EventType)} className="mt-1.5 w-full rounded-xl border border-white/10 bg-[#121a3c] px-4 py-3 text-white focus:border-lyo-500 focus:outline-none"><option value="study_session">Study session / meetup</option><option value="workshop">Workshop</option><option value="class">Class</option><option value="seminar">Seminar</option><option value="lecture">Lecture</option><option value="discussion">Discussion</option><option value="office_hours">Office hours</option><option value="networking">Learning network</option></select></label>
              <div className="grid gap-3 sm:grid-cols-2">
                <label className="text-sm text-white/65">Starts<input type="datetime-local" value={startTime} onChange={(event) => setStartTime(event.target.value)} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-white [color-scheme:dark] focus:border-lyo-500 focus:outline-none" /></label>
                <label className="text-sm text-white/65">Ends<input type="datetime-local" value={endTime} onChange={(event) => setEndTime(event.target.value)} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-white [color-scheme:dark] focus:border-lyo-500 focus:outline-none" /></label>
              </div>
            </>
          ) : type === 'group' ? (
            <label className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/70">
              Private group (approval required)
              <input type="checkbox" checked={isPrivate} onChange={(event) => setIsPrivate(event.target.checked)} className="h-4 w-4 accent-[#6366F1]" />
            </label>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2"><label className="text-sm text-white/65">Subject<input value={subject} onChange={(event) => setSubject(event.target.value)} placeholder="Biology, Spanish, SAT…" className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" /></label><label className="text-sm text-white/65">Price per hour (USD)<input type="number" min={0} value={pricePerHour} onChange={(event) => setPricePerHour(Number(event.target.value))} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" /></label></div>
          )}

          <label className="flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/70">Online learning<input type="checkbox" checked={isOnline} onChange={(event) => setIsOnline(event.target.checked)} className="h-4 w-4 accent-[#6366F1]" /></label>
          <label className="block text-sm text-white/65">{isOnline ? 'Optional physical location' : 'Location'}<input value={location} onChange={(event) => setLocation(event.target.value)} placeholder={isOnline ? 'Optional' : 'Where will this happen?'} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" /></label>
          {isOnline && <label className="block text-sm text-white/65">Meeting link<input value={meetingUrl} onChange={(event) => setMeetingUrl(event.target.value)} placeholder="https://…" className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" /></label>}
          {!isOnline && <button type="button" onClick={locate} disabled={locating} className="flex w-full items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/70 hover:border-lyo-500/60 hover:text-white">{locating ? <Loader2 className="h-4 w-4 animate-spin" /> : <LocateFixed className="h-4 w-4" />}{coordinates ? 'Location added to the shared map' : 'Use my current map location'}</button>}

          {type !== 'tutor' && <label className="block text-sm text-white/65">{type === 'event' ? 'Maximum attendees' : 'Maximum members'}<input type="number" min={2} max={type === 'event' ? 10000 : 1000} value={maxPeople} onChange={(event) => setMaxPeople(Number(event.target.value))} className="mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white focus:border-lyo-500 focus:outline-none" /></label>}
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
