'use client'

import { useMemo, useState } from 'react'
import { MapPin } from 'lucide-react'
import { cn } from '@/lib/utils'

export interface MappableCommunityEvent {
  id: string
  title: string
  location: string
  latitude?: number
  longitude?: number
}

export default function CommunityEventMap({ events }: { events: MappableCommunityEvent[] }) {
  const mappable = useMemo(
    () => events.filter((event) => Number.isFinite(event.latitude) && Number.isFinite(event.longitude)),
    [events],
  )
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const selected = mappable.find((event) => event.id === selectedId) ?? mappable[0]

  if (!selected) {
    return (
      <div className="flex min-h-[420px] flex-col items-center justify-center rounded-2xl border border-white/10 bg-white/5 p-8 text-center">
        <MapPin className="mb-3 h-10 w-10 text-white/25" />
        <h3 className="font-semibold text-white">No mapped events yet</h3>
        <p className="mt-1 max-w-sm text-sm text-white/45">Add a location when creating an event and it will appear on the shared map.</p>
      </div>
    )
  }

  const lat = selected.latitude as number
  const lng = selected.longitude as number
  const delta = 0.035
  const params = new URLSearchParams({
    bbox: `${lng - delta},${lat - delta},${lng + delta},${lat + delta}`,
    layer: 'mapnik',
    marker: `${lat},${lng}`,
  })

  return (
    <section className="overflow-hidden rounded-2xl border border-white/10 bg-[var(--surface)]">
      <iframe
        key={selected.id}
        title={`Map for ${selected.title}`}
        src={`https://www.openstreetmap.org/export/embed.html?${params}`}
        className="h-[420px] w-full border-0 md:h-[560px]"
        loading="lazy"
      />
      <div className="border-t border-white/10 p-3">
        <p className="mb-2 text-xs font-medium uppercase tracking-wide text-white/40">Mapped events</p>
        <div className="flex gap-2 overflow-x-auto pb-1">
          {mappable.map((event) => (
            <button
              key={event.id}
              onClick={() => setSelectedId(event.id)}
              className={cn(
                'min-w-48 rounded-xl border px-3 py-2 text-left transition',
                event.id === selected.id
                  ? 'border-lyo-500 bg-lyo-500/15 text-white'
                  : 'border-white/10 bg-white/5 text-white/60 hover:border-white/20 hover:text-white',
              )}
            >
              <span className="block truncate text-sm font-medium">{event.title}</span>
              <span className="block truncate text-xs opacity-70">{event.location}</span>
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}
