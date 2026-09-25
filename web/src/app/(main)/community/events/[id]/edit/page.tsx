'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import toast from 'react-hot-toast'
import { Lock } from 'lucide-react'
import EventForm from '@/components/community/EventForm'
import { ResultSkeleton, StateMessage } from '@/components/community/CommunityResults'
import { useApi } from '@/hooks/use-api'
import { api } from '@/lib/api'

export default function EditCommunityEventPage({ params }: { params: { id: string } }) {
  const router = useRouter()
  const eventId = decodeURIComponent(params.id)
  const detail = useApi(() => api.community.node('event', eventId), [eventId])

  if (detail.isLoading && !detail.data) return <div className="mx-auto max-w-3xl"><ResultSkeleton rows={6} /></div>
  if (!detail.data?.event || !detail.data.can_edit) {
    return (
      <div className="mx-auto max-w-lg">
        <StateMessage
          icon={Lock}
          title={detail.error ? "We couldn't load this event." : 'Only the host can edit this event'}
          body={detail.error ? 'Please try again in a moment.' : undefined}
          action={detail.error ? { label: 'Try again', onClick: detail.refetch } : undefined}
        />
        <div className="flex justify-center">
          <Link href={`/community/events/${eventId}`} className="min-h-[44px] rounded-xl px-4 py-2.5 text-sm font-semibold text-lyo-300 hover:bg-white/5">View event</Link>
        </div>
      </div>
    )
  }
  return (
    <div className="mx-auto max-w-3xl space-y-5">
      <header>
        <h1 className="font-display text-2xl font-semibold text-white">Edit event</h1>
        <p className="mt-1 text-sm text-white/55">Changes appear for everyone right away, on every device.</p>
      </header>
      <EventForm
        initial={detail.data.event}
        onCancel={() => router.back()}
        onSaved={() => {
          toast.success('Changes saved')
          router.replace(`/community/events/${eventId}`)
        }}
      />
    </div>
  )
}
