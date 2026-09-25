'use client'

import { Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import toast from 'react-hot-toast'
import EventForm from '@/components/community/EventForm'
import { ResultSkeleton } from '@/components/community/CommunityResults'

function NewEvent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const draft = {
    title: searchParams.get('title') ?? undefined,
    description: searchParams.get('description') ?? undefined,
    start: searchParams.get('start') ?? undefined,
  }
  return (
    <EventForm
      draft={draft}
      onCancel={() => router.back()}
      onSaved={(event) => {
        toast.success('Your event is live')
        router.replace(`/community/events/${event.id}`)
      }}
    />
  )
}

export default function NewCommunityEventPage() {
  return (
    <div className="mx-auto max-w-3xl space-y-5">
      <header>
        <h1 className="font-display text-2xl font-semibold text-white">Create a learning event</h1>
        <p className="mt-1 text-sm text-white/55">Workshops, classes, talks, and study sessions appear on the Community map for learners nearby.</p>
      </header>
      <Suspense fallback={<ResultSkeleton rows={6} />}>
        <NewEvent />
      </Suspense>
    </div>
  )
}
