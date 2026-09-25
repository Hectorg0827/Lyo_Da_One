'use client'

import { useEffect, useId, useRef, useState } from 'react'
import type { Map as LeafletMap, Marker } from 'leaflet'
import { Loader2, MapPin, X } from 'lucide-react'
import { api } from '@/lib/api'
import { createMapHost, teardownMap } from '@/lib/leaflet-teardown'
import { cn } from '@/lib/utils'
import type { PlaceSuggestion } from '@/types'

export interface ChosenPlace {
  label: string
  name: string
  latitude: number
  longitude: number
}

const TILE_URL = process.env.NEXT_PUBLIC_MAP_TILE_URL || 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
const TILE_ATTRIBUTION =
  process.env.NEXT_PUBLIC_MAP_TILE_ATTRIBUTION || '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'

/** Drag the pin (or tap the map) to place the event exactly. */
function PinPicker({ place, onMove }: { place: ChosenPlace; onMove: (latitude: number, longitude: number) => void }) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const mapRef = useRef<LeafletMap | null>(null)
  const markerRef = useRef<Marker | null>(null)
  const onMoveRef = useRef(onMove)
  onMoveRef.current = onMove

  useEffect(() => {
    let disposed = false
    let host: HTMLDivElement | null = null
    void import('leaflet').then((L) => {
      if (disposed || !containerRef.current || mapRef.current) return
      host = createMapHost(containerRef.current)
      const map = L.map(host, { zoomControl: true, attributionControl: true }).setView([place.latitude, place.longitude], 16)
      L.tileLayer(TILE_URL, { maxZoom: 19, attribution: TILE_ATTRIBUTION }).addTo(map)
      const marker = L.marker([place.latitude, place.longitude], {
        draggable: true,
        keyboard: true,
        title: 'Event location. Drag to adjust.',
        icon: L.divIcon({
          className: 'lyo-learning-marker',
          html: '<span style="--marker:#6366f1" role="img" aria-label="Event location"><svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg></span>',
          iconSize: [40, 46],
          iconAnchor: [20, 44],
        }),
      }).addTo(map)
      marker.on('dragend', () => {
        const position = marker.getLatLng()
        onMoveRef.current(position.lat, position.lng)
      })
      map.on('click', (event) => {
        marker.setLatLng(event.latlng)
        onMoveRef.current(event.latlng.lat, event.latlng.lng)
      })
      mapRef.current = map
      markerRef.current = marker
      requestAnimationFrame(() => {
        if (mapRef.current === map) map.invalidateSize()
      })
    })
    return () => {
      disposed = true
      const map = mapRef.current
      mapRef.current = null
      markerRef.current = null
      teardownMap(map, host)
    }
    // One map per field; later place changes move it below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    const map = mapRef.current
    const marker = markerRef.current
    if (!map || !marker) return
    const current = marker.getLatLng()
    if (Math.abs(current.lat - place.latitude) < 1e-7 && Math.abs(current.lng - place.longitude) < 1e-7) return
    marker.setLatLng([place.latitude, place.longitude])
    map.setView([place.latitude, place.longitude], Math.max(map.getZoom(), 15))
  }, [place.latitude, place.longitude])

  return (
    <div
      ref={containerRef}
      role="application"
      aria-label="Adjust the event location. Drag the pin or tap the map."
      className="lyo-map mt-2 h-52 w-full overflow-hidden rounded-2xl border border-white/10 bg-[#0b1230]"
    />
  )
}

export default function PlaceSearchField({
  value,
  onChange,
  label = 'Address',
  withMap = false,
  origin,
}: {
  value: ChosenPlace | null
  onChange: (place: ChosenPlace | null) => void
  label?: string
  withMap?: boolean
  origin?: { latitude: number; longitude: number } | null
}) {
  const inputId = useId()
  const listId = useId()
  const [text, setText] = useState(value?.label ?? '')
  const [suggestions, setSuggestions] = useState<PlaceSuggestion[]>([])
  const [open, setOpen] = useState(false)
  const [loading, setLoading] = useState(false)
  const [highlight, setHighlight] = useState(0)
  const [notFound, setNotFound] = useState(false)

  useEffect(() => {
    if (value && value.label !== text) setText(value.label)
    // Only react to a place chosen elsewhere (e.g. an edit form loading).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value?.label])

  useEffect(() => {
    const query = text.trim()
    if (!open || query.length < 3 || query === value?.label) {
      setSuggestions([])
      setNotFound(false)
      return
    }
    let cancelled = false
    const timer = setTimeout(() => {
      setLoading(true)
      api.community
        .geocode(query, origin)
        .then((places) => {
          if (cancelled) return
          setSuggestions(places)
          setNotFound(places.length === 0)
          setHighlight(0)
        })
        .catch(() => {
          if (!cancelled) {
            setSuggestions([])
            setNotFound(true)
          }
        })
        .finally(() => !cancelled && setLoading(false))
    }, 350)
    return () => {
      cancelled = true
      clearTimeout(timer)
    }
  }, [text, open, origin, value?.label])

  const choose = (place: PlaceSuggestion) => {
    onChange({ label: place.label, name: place.name, latitude: place.latitude, longitude: place.longitude })
    setText(place.label)
    setOpen(false)
    setSuggestions([])
  }

  return (
    <div className="text-sm text-white/70">
      <label htmlFor={inputId}>{label}</label>
      <div className="relative mt-1.5">
        <MapPin className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" aria-hidden="true" />
        <input
          id={inputId}
          value={text}
          role="combobox"
          aria-expanded={open && suggestions.length > 0}
          aria-controls={listId}
          aria-autocomplete="list"
          autoComplete="off"
          placeholder="Search an address or venue"
          onFocus={() => setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 150)}
          onChange={(event) => {
            setText(event.target.value)
            setOpen(true)
            if (value) onChange(null)
          }}
          onKeyDown={(event) => {
            if (!suggestions.length) return
            if (event.key === 'ArrowDown') {
              event.preventDefault()
              setHighlight((index) => Math.min(suggestions.length - 1, index + 1))
            } else if (event.key === 'ArrowUp') {
              event.preventDefault()
              setHighlight((index) => Math.max(0, index - 1))
            } else if (event.key === 'Enter') {
              event.preventDefault()
              choose(suggestions[highlight])
            }
          }}
          className="w-full rounded-xl border border-white/10 bg-white/5 py-3 pl-10 pr-10 text-white placeholder:text-white/35 focus:border-lyo-500 focus:outline-none"
        />
        <span className="absolute right-2 top-1/2 -translate-y-1/2">
          {loading ? (
            <Loader2 className="h-4 w-4 animate-spin text-lyo-300" aria-label="Searching addresses" />
          ) : text ? (
            <button
              type="button"
              aria-label="Clear address"
              onClick={() => {
                setText('')
                onChange(null)
              }}
              className="flex h-8 w-8 items-center justify-center rounded-lg text-white/45 hover:bg-white/10 hover:text-white"
            >
              <X className="h-4 w-4" aria-hidden="true" />
            </button>
          ) : null}
        </span>
        {open && suggestions.length > 0 && (
          <ul id={listId} role="listbox" className="absolute inset-x-0 top-[52px] z-30 max-h-64 overflow-y-auto rounded-2xl border border-white/10 bg-[#0e173d] p-1 shadow-2xl">
            {suggestions.map((place, index) => (
              <li key={`${place.latitude},${place.longitude},${place.label}`} role="option" aria-selected={index === highlight}>
                <button
                  type="button"
                  onMouseDown={(event) => event.preventDefault()}
                  onClick={() => choose(place)}
                  className={cn('w-full rounded-xl px-3 py-2.5 text-left', index === highlight ? 'bg-white/10' : 'hover:bg-white/5')}
                >
                  <span className="block text-sm font-medium text-white">{place.name}</span>
                  <span className="block truncate text-xs text-white/50">{place.label}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
      {notFound && !loading && open && (
        <p className="mt-1.5 text-xs text-white/50">No matching address. Try a street and city, or a ZIP code.</p>
      )}
      {value && withMap && (
        <>
          <PinPicker place={value} onMove={(latitude, longitude) => onChange({ ...value, latitude, longitude })} />
          <p className="mt-1.5 text-xs text-white/45">Drag the pin or tap the map to mark the exact entrance. Only this public location is shared.</p>
        </>
      )}
    </div>
  )
}
