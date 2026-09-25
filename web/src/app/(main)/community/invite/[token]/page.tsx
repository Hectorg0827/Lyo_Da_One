'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import toast from 'react-hot-toast'
import { CalendarClock, Loader2, Lock, MapPin, UserRound, Video } from 'lucide-react'
import { useApi } from '@/hooks/use-api'
import { api } from '@/lib/api'
import { INVITE_STATUS_COPY, formatWhen, friendlyError, invitePath, safeWebUrl } from '@/lib/community-contract.mjs'

/**
 * Where an invite link lands. It shows what the invitation is for, then puts
 * the learner on the event's guest list (their Lyo account, so every device
 * sees the event) and opens it.
 */
export default function CommunityInvitePage({ params }: { params: { token: string } }) {
  const token = decodeURIComponent(params.token)
  const router = useRouter()
  const [accepting, setAccepting] = useState(false)
  const [attempt, setAttempt] = useState(0)
  const preview = useApi(() => api.community.invitePreview(token), [token, attempt])

  const eventPath = (id: number) => `/community/events/${id}`
  const signInHref = `/auth/login?next=${encodeURIComponent(invitePath(token))}`

  const accept = async () => {
    setAccepting(true)
    try {
      const node = await api.community.acceptInvite(token)
      api.community.track('community_invite_accepted', { visibility: node.visibility ?? 'private' })
      toast.success("You're on the guest list")
      router.replace(eventPath(Number(node.id)))
    } catch (reason) {
      const message = friendlyError(reason, 'accept this invite')
      toast.error(message.title.startsWith("That didn't") ? message.body : `${message.title} ${message.body}`)
      setAccepting(false)
      setAttempt((value) => value + 1)
    }
  }

  const shell = (children: React.ReactNode) => (
    <div className="mx-auto flex min-h-full max-w-lg flex-col justify-center px-4 py-10" data-testid="invite-page">
      <div className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-6 shadow-xl">{children}</div>
    </div>
  )

  if (preview.isLoading && !preview.data) {
    return shell(
      <div className="flex flex-col items-center gap-3 py-8 text-white/60" role="status">
        <Loader2 className="h-6 w-6 animate-spin" aria-hidden="true" />
        Opening your invitation…
      </div>,
    )
  }

  if (!preview.data) {
    // Signed out: keep the invite and come back to it after signing in.
    const signedOut = typeof window !== 'undefined' && !localStorage.getItem('lyo_token')
    if (signedOut) {
      return shell(
        <div className="space-y-4 text-center">
          <Lock className="mx-auto h-8 w-8 text-lyo-300" aria-hidden="true" />
          <h1 className="font-display text-xl font-semibold text-white">You&apos;ve been invited to a Lyo event</h1>
          <p className="text-sm text-white/65">Sign in or create a free account to see the event and accept.</p>
          <div className="flex flex-col gap-2 sm:flex-row sm:justify-center">
            <Link href={signInHref} className="flex min-h-[44px] items-center justify-center rounded-xl bg-lyo-500 px-5 text-sm font-semibold text-white hover:bg-lyo-400">Sign in</Link>
            <Link href={`/auth/signup?next=${encodeURIComponent(invitePath(token))}`} className="flex min-h-[44px] items-center justify-center rounded-xl border border-white/15 px-5 text-sm font-semibold text-white/85 hover:bg-white/10">Create account</Link>
          </div>
        </div>,
      )
    }
    const notFound = /not valid|isn't valid|not found|404/i.test(preview.error ?? '')
    const offline = typeof navigator !== 'undefined' && navigator.onLine === false
    const message = notFound
      ? { title: "This invite link isn't valid", body: 'Check that you copied the whole link, or ask the host for a new one.' }
      : offline
        ? { title: "You're offline", body: 'Check your connection and try again.' }
        : { title: "We couldn't open this invite.", body: 'Please try again in a moment.' }
    return shell(
      <div className="space-y-4 text-center" role="alert">
        <h1 className="font-display text-xl font-semibold text-white">{message.title}</h1>
        <p className="text-sm text-white/65">{message.body}</p>
        <div className="flex flex-col gap-2 sm:flex-row sm:justify-center">
          {!notFound && (
            <button type="button" onClick={() => setAttempt((value) => value + 1)} className="min-h-[44px] rounded-xl bg-lyo-500 px-5 text-sm font-semibold text-white hover:bg-lyo-400">Try again</button>
          )}
          <Link href="/community" className="flex min-h-[44px] items-center justify-center rounded-xl border border-white/15 px-5 text-sm text-white/80 hover:bg-white/10">Browse Community</Link>
        </div>
      </div>,
    )
  }

  const invite = preview.data
  const when = formatWhen(invite.starts_at, invite.ends_at)
  const image = safeWebUrl(invite.image_url)
  const hostName = invite.organizer_name || invite.host?.name
  const closed = invite.status !== 'valid'
  const copy = closed ? INVITE_STATUS_COPY[invite.status as keyof typeof INVITE_STATUS_COPY] : null
  const inAlready = invite.already_guest || invite.is_host

  return shell(
    <article className="space-y-5" aria-labelledby="invite-event-title">
      {image && (
        <div className="aspect-[16/7] overflow-hidden rounded-2xl border border-white/10 bg-white/5">
          <img src={image} alt="" className="h-full w-full object-cover" />
        </div>
      )}
      <div className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-lyo-300">
          {invite.is_host ? 'Your event' : invite.visibility === 'private' ? 'Private invitation' : 'Invitation'}
        </p>
        <h1 id="invite-event-title" className="font-display text-2xl font-semibold leading-tight text-white">{invite.title}</h1>
        {hostName && !invite.is_host && <p className="text-sm text-white/60">{hostName} invited you</p>}
      </div>
      <ul className="space-y-2 text-sm text-white/80">
        {when && (
          <li className="flex items-start gap-2"><CalendarClock className="mt-0.5 h-4 w-4 shrink-0 text-white/45" aria-hidden="true" />{when}</li>
        )}
        {invite.attendance_mode === 'online' ? (
          <li className="flex items-start gap-2"><Video className="mt-0.5 h-4 w-4 shrink-0 text-white/45" aria-hidden="true" />Online</li>
        ) : invite.location_name ? (
          <li className="flex items-start gap-2"><MapPin className="mt-0.5 h-4 w-4 shrink-0 text-white/45" aria-hidden="true" />{invite.location_name}{invite.attendance_mode === 'hybrid' ? ' · also online' : ''}</li>
        ) : null}
        {hostName && (
          <li className="flex items-start gap-2"><UserRound className="mt-0.5 h-4 w-4 shrink-0 text-white/45" aria-hidden="true" />Hosted by {hostName}</li>
        )}
      </ul>

      {inAlready ? (
        <div className="space-y-2">
          <p className="text-sm text-white/65">{invite.is_host ? "You're the host of this event." : "You're already on the guest list."}</p>
          <Link href={eventPath(invite.event_id)} className="flex min-h-[48px] w-full items-center justify-center rounded-xl bg-lyo-500 text-sm font-semibold text-white hover:bg-lyo-400">Open event</Link>
        </div>
      ) : copy ? (
        <div className="space-y-3 rounded-2xl bg-white/[0.05] p-4" role="status">
          <p className="font-semibold text-white">{copy.title}</p>
          <p className="text-sm text-white/65">{copy.body}</p>
          <Link href="/community" className="inline-flex min-h-[44px] items-center text-sm font-semibold text-lyo-300 hover:underline">Browse Community</Link>
        </div>
      ) : (
        <div className="space-y-2">
          <button type="button" onClick={() => void accept()} disabled={accepting} className="flex min-h-[48px] w-full items-center justify-center gap-2 rounded-xl bg-lyo-500 text-sm font-semibold text-white transition hover:bg-lyo-400 disabled:opacity-60">
            {accepting && <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />}
            Accept invitation
          </button>
          <p className="text-center text-xs text-white/45">Accepting adds this event to your Lyo account on every device. You can RSVP next.</p>
        </div>
      )}
    </article>,
  )
}
