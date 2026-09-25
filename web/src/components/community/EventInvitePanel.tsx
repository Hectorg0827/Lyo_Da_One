'use client'

import { useEffect, useMemo, useState } from 'react'
import toast from 'react-hot-toast'
import { Check, Copy, Link2, Loader2, Search, Share2, UserMinus, UserPlus, X } from 'lucide-react'
import { useApi } from '@/hooks/use-api'
import { api } from '@/lib/api'
import { describeInviteLink, friendlyError, invitePath } from '@/lib/community-contract.mjs'
import { cn } from '@/lib/utils'
import type { EventInvite, LearningNode } from '@/types'

type Member = { id: number; username: string; name: string; avatar_url: string | null }

const USE_OPTIONS = [
  { value: '', label: 'Anyone' },
  { value: '1', label: '1 person' },
  { value: '5', label: 'Up to 5' },
  { value: '25', label: 'Up to 25' },
]
const EXPIRY_OPTIONS = [
  { value: '7', label: '7 days' },
  { value: '30', label: '30 days' },
  { value: '90', label: '90 days' },
]

function errorText(reason: unknown, action: string) {
  const message = friendlyError(reason, action)
  return message.title.startsWith("That didn't") ? message.body : `${message.title} ${message.body}`
}

function linkUrl(link: EventInvite) {
  // The page the learner is on is the right host (production, staging, local).
  return typeof window === 'undefined' ? link.url : `${window.location.origin}${invitePath(link.token)}`
}

/**
 * Host-only: who can get into a private or unlisted event. Invite links can
 * be limited and turned off; Lyo members can be invited by name (they are
 * notified on every device); anyone on the guest list can be removed.
 */
export default function EventInvitePanel({ node, currentUserId }: { node: LearningNode; currentUserId?: number | null }) {
  const invitations = useApi(() => api.community.invitations(node.id), [node.id])
  const [maxUses, setMaxUses] = useState('')
  const [expiresIn, setExpiresIn] = useState('30')
  const [creating, setCreating] = useState(false)
  const [busy, setBusy] = useState<string | null>(null)
  const [copied, setCopied] = useState<number | null>(null)
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Member[]>([])
  const [searching, setSearching] = useState(false)

  const guests = invitations.data?.guests ?? []
  const links = invitations.data?.links ?? []
  const guestIds = useMemo(() => new Set(guests.map((guest) => guest.user.id)), [guests])
  const isPrivate = node.visibility === 'private'

  useEffect(() => {
    const text = query.trim()
    if (text.length < 2) {
      setResults([])
      return
    }
    let cancelled = false
    const timer = setTimeout(async () => {
      setSearching(true)
      try {
        const found = await api.search.query(text, 'users', 8)
        if (!cancelled) setResults(found.users.filter((user) => user.id !== currentUserId))
      } catch {
        if (!cancelled) setResults([])
      } finally {
        if (!cancelled) setSearching(false)
      }
    }, 300)
    return () => {
      cancelled = true
      clearTimeout(timer)
    }
  }, [query, currentUserId])

  const createLink = async () => {
    setCreating(true)
    try {
      const link = await api.community.createInvite(node.id, {
        max_uses: maxUses ? Number(maxUses) : null,
        expires_in_days: Number(expiresIn),
      })
      api.community.track('community_invite_created', { max_uses: maxUses || 'any', days: Number(expiresIn) })
      invitations.refetch()
      await copyLink(link)
    } catch (reason) {
      toast.error(errorText(reason, 'create an invite link'))
    } finally {
      setCreating(false)
    }
  }

  const copyLink = async (link: EventInvite) => {
    try {
      await navigator.clipboard.writeText(linkUrl(link))
      setCopied(link.id)
      toast.success('Invite link copied')
      setTimeout(() => setCopied((current) => (current === link.id ? null : current)), 2000)
    } catch {
      toast.error("Couldn't copy. Use Share instead.")
    }
  }

  const shareLink = async (link: EventInvite) => {
    try {
      if (navigator.share) {
        await navigator.share({ title: node.title, text: `You're invited to ${node.title} on Lyo`, url: linkUrl(link) })
      } else {
        await copyLink(link)
      }
    } catch (error) {
      if ((error as DOMException)?.name !== 'AbortError') toast.error("Couldn't share this link")
    }
  }

  const turnOff = async (link: EventInvite) => {
    setBusy(`link:${link.id}`)
    try {
      await api.community.revokeInvite(node.id, link.id)
      toast.success('Link turned off. People who already joined keep their spot.')
      invitations.refetch()
    } catch (reason) {
      toast.error(errorText(reason, 'turn off this link'))
    } finally {
      setBusy(null)
    }
  }

  const invite = async (member: Member) => {
    setBusy(`user:${member.id}`)
    try {
      await api.community.inviteGuest(node.id, member.id)
      toast.success(`Invited ${member.name}`)
      setQuery('')
      setResults([])
      invitations.refetch()
    } catch (reason) {
      toast.error(errorText(reason, 'send this invitation'))
    } finally {
      setBusy(null)
    }
  }

  const remove = async (userId: number, name: string) => {
    setBusy(`guest:${userId}`)
    try {
      await api.community.removeGuest(node.id, userId)
      toast.success(`${name} was removed from the guest list`)
      invitations.refetch()
    } catch (reason) {
      toast.error(errorText(reason, 'remove this guest'))
    } finally {
      setBusy(null)
    }
  }

  return (
    <section aria-labelledby="invite-title" className="space-y-4 rounded-3xl border border-white/[0.08] bg-white/[0.03] p-4">
      <div>
        <h2 id="invite-title" className="text-sm font-semibold text-white">Invite people</h2>
        <p className="mt-1 text-xs text-white/55">
          {isPrivate
            ? 'This event is private: only you and the people you invite can see it.'
            : 'This event is unlisted: it is not on the map, so share an invite with the people you want.'}
        </p>
      </div>

      <div className="space-y-2">
        <div className="grid grid-cols-2 gap-2">
          <label className="text-xs text-white/55">
            Who can use it
            <select value={maxUses} onChange={(event) => setMaxUses(event.target.value)} className="mt-1 min-h-[40px] w-full rounded-xl border border-white/10 bg-[#0e173d] px-2 text-sm text-white">
              {USE_OPTIONS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
          </label>
          <label className="text-xs text-white/55">
            Link works for
            <select value={expiresIn} onChange={(event) => setExpiresIn(event.target.value)} className="mt-1 min-h-[40px] w-full rounded-xl border border-white/10 bg-[#0e173d] px-2 text-sm text-white">
              {EXPIRY_OPTIONS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
          </label>
        </div>
        <button type="button" onClick={() => void createLink()} disabled={creating} className="flex min-h-[44px] w-full items-center justify-center gap-2 rounded-xl bg-lyo-500 text-sm font-semibold text-white transition hover:bg-lyo-400 disabled:opacity-60">
          {creating ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" /> : <Link2 className="h-4 w-4" aria-hidden="true" />}
          Create and copy invite link
        </button>
      </div>

      {links.length > 0 && (
        <ul className="space-y-1.5" aria-label="Invite links">
          {links.map((link) => (
            <li key={link.id} className={cn('rounded-2xl border border-white/10 px-3 py-2', !link.active && 'opacity-60')}>
              <p className="text-xs text-white/65">{describeInviteLink(link)}</p>
              {link.active && (
                <div className="mt-1.5 flex flex-wrap gap-1.5">
                  <button type="button" onClick={() => void copyLink(link)} className="flex min-h-[36px] items-center gap-1.5 rounded-lg border border-white/10 px-2.5 text-xs text-white/80 hover:bg-white/10">
                    {copied === link.id ? <Check className="h-3.5 w-3.5" aria-hidden="true" /> : <Copy className="h-3.5 w-3.5" aria-hidden="true" />}
                    {copied === link.id ? 'Copied' : 'Copy'}
                  </button>
                  <button type="button" onClick={() => void shareLink(link)} className="flex min-h-[36px] items-center gap-1.5 rounded-lg border border-white/10 px-2.5 text-xs text-white/80 hover:bg-white/10">
                    <Share2 className="h-3.5 w-3.5" aria-hidden="true" /> Share
                  </button>
                  <button type="button" onClick={() => void turnOff(link)} disabled={busy === `link:${link.id}`} className="flex min-h-[36px] items-center gap-1.5 rounded-lg px-2.5 text-xs text-amber-200 hover:bg-white/10 disabled:opacity-50">
                    <X className="h-3.5 w-3.5" aria-hidden="true" /> Turn off
                  </button>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}

      <div>
        <label htmlFor="invite-search" className="text-xs font-medium text-white/70">Invite a Lyo member by name</label>
        <div className="relative mt-1">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" aria-hidden="true" />
          <input
            id="invite-search"
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Name or username"
            autoComplete="off"
            className="min-h-[44px] w-full rounded-xl border border-white/10 bg-white/5 pl-9 pr-9 text-sm text-white placeholder:text-white/35 focus:border-lyo-500 focus:outline-none"
          />
          {searching && <Loader2 className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-white/40" aria-hidden="true" />}
        </div>
        {results.length > 0 && (
          <ul className="mt-1.5 space-y-1" aria-label="People">
            {results.map((member) => {
              const already = guestIds.has(member.id)
              return (
                <li key={member.id} className="flex items-center justify-between gap-2 rounded-xl px-2 py-1.5 hover:bg-white/5">
                  <span className="min-w-0 truncate text-sm text-white/85">
                    {member.name} <span className="text-white/40">@{member.username}</span>
                  </span>
                  <button
                    type="button"
                    disabled={already || busy === `user:${member.id}`}
                    onClick={() => void invite(member)}
                    className="flex min-h-[36px] shrink-0 items-center gap-1.5 rounded-lg border border-white/10 px-2.5 text-xs text-white/80 hover:bg-white/10 disabled:opacity-50"
                  >
                    <UserPlus className="h-3.5 w-3.5" aria-hidden="true" /> {already ? 'Invited' : 'Invite'}
                  </button>
                </li>
              )
            })}
          </ul>
        )}
        {query.trim().length >= 2 && !searching && results.length === 0 && (
          <p className="mt-1.5 text-xs text-white/45">No Lyo members match “{query.trim()}”.</p>
        )}
      </div>

      <div>
        <h3 className="text-xs font-medium text-white/70">Guest list {guests.length > 0 && <span className="text-white/40">· {guests.length}</span>}</h3>
        {invitations.isLoading && !invitations.data ? (
          <p className="mt-2 text-xs text-white/45">Loading guests…</p>
        ) : invitations.error && !invitations.data ? (
          <button type="button" onClick={invitations.refetch} className="mt-2 text-xs text-lyo-300 hover:underline">We couldn&apos;t load your guest list. Try again</button>
        ) : guests.length === 0 ? (
          <p className="mt-2 text-xs text-white/45">No guests yet. Invite someone by link or by name.</p>
        ) : (
          <ul className="mt-1.5 space-y-1">
            {guests.map((guest) => (
              <li key={guest.user.id} className="flex items-center justify-between gap-2 rounded-xl px-2 py-1.5">
                <span className="min-w-0">
                  <span className="block truncate text-sm text-white/85">{guest.user.name}</span>
                  <span className="text-[11px] text-white/45">
                    {guest.rsvp_status === 'going' ? 'Going' : guest.rsvp_status === 'interested' ? 'Interested' : 'No reply yet'}
                    {' · '}
                    {guest.source === 'direct' ? 'Invited by name' : 'Joined with a link'}
                  </span>
                </span>
                <button
                  type="button"
                  onClick={() => void remove(guest.user.id, guest.user.name)}
                  disabled={busy === `guest:${guest.user.id}`}
                  aria-label={`Remove ${guest.user.name} from the guest list`}
                  className="flex min-h-[36px] shrink-0 items-center gap-1.5 rounded-lg px-2.5 text-xs text-red-300 hover:bg-white/10 disabled:opacity-50"
                >
                  <UserMinus className="h-3.5 w-3.5" aria-hidden="true" /> Remove
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  )
}
