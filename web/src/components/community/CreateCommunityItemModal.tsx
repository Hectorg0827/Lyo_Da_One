'use client'

import { useEffect, useRef, useState } from 'react'
import { Loader2, X } from 'lucide-react'
import toast from 'react-hot-toast'
import { api } from '@/lib/api'
import { friendlyError } from '@/lib/community-contract.mjs'
import { cn } from '@/lib/utils'
import PlaceSearchField, { type ChosenPlace } from './PlaceSearchField'

type ItemType = 'group' | 'tutor'

/**
 * Study groups and tutoring offers. Events and classes have their own full
 * editor (/community/events/new) because they need dates, a map pin, and
 * more detail than a dialog comfortably holds.
 */
export default function CreateCommunityItemModal({
  onClose,
  onCreated,
  initialType = 'group',
}: {
  onClose: () => void
  onCreated: (type: ItemType) => void
  initialType?: ItemType
}) {
  const [type, setType] = useState<ItemType>(initialType)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [place, setPlace] = useState<ChosenPlace | null>(null)
  const [meetingUrl, setMeetingUrl] = useState('')
  const [isOnline, setIsOnline] = useState(false)
  const [subject, setSubject] = useState('')
  const [pricePerHour, setPricePerHour] = useState(0)
  const [maxPeople, setMaxPeople] = useState(20)
  const [isPrivate, setIsPrivate] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const dialogRef = useRef<HTMLElement | null>(null)

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null
    dialogRef.current?.querySelector<HTMLInputElement>('input')?.focus()
    const onKey = (event: KeyboardEvent) => event.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('keydown', onKey)
      previous?.focus?.()
    }
  }, [onClose])

  const submit = async () => {
    if (!title.trim() || submitting) return
    if (!isOnline && !place) {
      setError('Search for the address where you meet, or choose Online.')
      return
    }
    setSubmitting(true)
    setError(null)
    const location = place?.label
    const coordinates = !isOnline && place ? { latitude: place.latitude, longitude: place.longitude } : {}
    try {
      if (type === 'group') {
        await api.community.createGroup({
          name: title.trim(),
          description: description.trim() || undefined,
          privacy: isPrivate ? 'private' : 'public',
          max_members: maxPeople,
          requires_approval: isPrivate,
          location: isOnline ? 'Online' : location,
          is_online: isOnline,
          meeting_url: meetingUrl.trim() || undefined,
          ...coordinates,
        })
      } else {
        if (!subject.trim()) throw new Error('Add the subject you tutor.')
        await api.community.createTutor({
          title: title.trim(),
          description: description.trim() || undefined,
          subject: subject.trim(),
          price_per_hour: pricePerHour,
          currency: 'USD',
          duration_minutes: 60,
          location: isOnline ? 'Online' : location,
          is_online: isOnline,
          meeting_url: meetingUrl.trim() || undefined,
          ...coordinates,
        })
      }
      toast.success(type === 'group' ? 'Study group created' : 'Tutoring offer published')
      onCreated(type)
      onClose()
    } catch (reason) {
      const message = friendlyError(reason, `create this ${type === 'group' ? 'group' : 'offer'}`)
      setError(reason instanceof Error && !('status' in reason) ? reason.message : message.body || message.title)
    } finally {
      setSubmitting(false)
    }
  }

  const field = 'mt-1.5 w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white placeholder:text-white/35 focus:border-lyo-500 focus:outline-none'

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-0 backdrop-blur-sm sm:items-center sm:p-4" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section ref={dialogRef} role="dialog" aria-modal="true" aria-labelledby="create-item-title" className="flex max-h-[92vh] w-full max-w-xl flex-col overflow-hidden rounded-t-3xl border border-white/10 bg-[#0d0f18]/95 shadow-2xl backdrop-blur-2xl sm:rounded-3xl">
        <header className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <h2 id="create-item-title" className="text-lg font-semibold text-white">{type === 'group' ? 'New study group' : 'Offer tutoring'}</h2>
          <button onClick={onClose} aria-label="Close" className="flex h-11 w-11 items-center justify-center rounded-xl text-white/50 hover:bg-white/10 hover:text-white"><X className="h-5 w-5" /></button>
        </header>

        <div className="min-h-0 flex-1 space-y-4 overflow-y-auto p-5">
          <div className="grid grid-cols-2 gap-1 rounded-xl border border-white/10 bg-white/5 p-1" role="tablist" aria-label="What are you creating?">
            {(['group', 'tutor'] as const).map((item) => (
              <button key={item} role="tab" aria-selected={type === item} onClick={() => setType(item)} className={cn('min-h-[40px] rounded-lg px-4 text-sm font-medium transition', type === item ? 'bg-lyo-500 text-white' : 'text-white/60 hover:bg-white/10 hover:text-white')}>
                {item === 'group' ? 'Study group' : 'Tutoring'}
              </button>
            ))}
          </div>

          <label className="block text-sm text-white/70">
            {type === 'group' ? 'Group name' : 'Tutoring title'}
            <input value={title} onChange={(event) => setTitle(event.target.value)} maxLength={200} className={field} />
          </label>
          <label className="block text-sm text-white/70">
            Description
            <textarea value={description} onChange={(event) => setDescription(event.target.value)} rows={3} maxLength={2000} className={cn(field, 'resize-y')} />
          </label>

          {type === 'group' ? (
            <label className="flex min-h-[48px] items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/75">
              Private group (members need approval)
              <input type="checkbox" checked={isPrivate} onChange={(event) => setIsPrivate(event.target.checked)} className="h-5 w-5 accent-[#6366F1]" />
            </label>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2">
              <label className="text-sm text-white/70">Subject<input value={subject} onChange={(event) => setSubject(event.target.value)} placeholder="Biology, Spanish, SAT…" className={field} /></label>
              <label className="text-sm text-white/70">Price per hour (USD)<input type="number" min={0} value={pricePerHour} onChange={(event) => setPricePerHour(Number(event.target.value))} className={field} /></label>
            </div>
          )}

          <label className="flex min-h-[48px] items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white/75">
            Meets online
            <input type="checkbox" checked={isOnline} onChange={(event) => setIsOnline(event.target.checked)} className="h-5 w-5 accent-[#6366F1]" />
          </label>
          {isOnline ? (
            <label className="block text-sm text-white/70">Meeting link (shared only with members)<input value={meetingUrl} onChange={(event) => setMeetingUrl(event.target.value)} placeholder="https://…" inputMode="url" className={field} /></label>
          ) : (
            <PlaceSearchField value={place} onChange={setPlace} label="Where you meet" />
          )}

          {type === 'group' && (
            <label className="block text-sm text-white/70">Maximum members<input type="number" min={2} max={1000} value={maxPeople} onChange={(event) => setMaxPeople(Number(event.target.value))} className={field} /></label>
          )}
          {error && <p role="alert" className="rounded-xl bg-red-500/10 px-3 py-2 text-sm text-red-300">{error}</p>}
        </div>

        <footer className="flex justify-end gap-3 border-t border-white/10 px-5 py-4 pb-[calc(1rem+env(safe-area-inset-bottom))] sm:pb-4">
          <button onClick={onClose} disabled={submitting} className="min-h-[44px] rounded-xl border border-white/15 px-4 text-sm text-white/75 hover:bg-white/10">Cancel</button>
          <button onClick={submit} disabled={!title.trim() || submitting} className="flex min-h-[44px] min-w-32 items-center justify-center gap-2 rounded-xl bg-lyo-500 px-4 text-sm font-semibold text-white disabled:opacity-50">
            {submitting && <Loader2 className="h-4 w-4 animate-spin" />}{submitting ? 'Creating…' : type === 'group' ? 'Create group' : 'Publish'}
          </button>
        </footer>
      </section>
    </div>
  )
}
