'use client'

import { useEffect, useRef, useState } from 'react'
import type { LayerGroup, Map as LeafletMap } from 'leaflet'
import { createMapHost, teardownMap } from '@/lib/leaflet-teardown'
import type { LearningNode, LearningNodeCategory } from '@/types'
import {
  areaForBounds,
  categoryLabel,
  clusterNodes,
  type NodeCluster,
  type SearchArea,
} from '@/lib/community-contract.mjs'

type LeafletModule = typeof import('leaflet')

export interface MapView extends SearchArea {
  /** Change this to move the map; the same token never re-applies. */
  token: number
}

/**
 * A layout resize is not the learner moving the map. Leaflet fires moveend
 * synchronously inside invalidateSize (only when the size changed), so the
 * flag covers exactly that event and a still-running fit keeps its own flag.
 */
function resizeQuietly(map: LeafletMap, programmaticMove: { current: boolean }) {
  const pending = programmaticMove.current
  programmaticMove.current = true
  map.invalidateSize()
  programmaticMove.current = pending
}

export interface CommunityEventMapProps {
  nodes: LearningNode[]
  view: MapView
  selectedKey?: string | null
  userLocation?: { latitude: number; longitude: number } | null
  onSelect: (node: LearningNode) => void
  onClusterSelect?: (members: LearningNode[]) => void
  /**
   * The visible area after every move. `programmatic` is true when the app
   * moved the map (a search, locate me, a resize), false when the learner did.
   */
  onViewportChange?: (area: SearchArea, programmatic: boolean) => void
  /** Space covered by overlays (px) so a selected pin is never hidden. */
  padding?: { top: number; bottom: number; left: number; right: number }
  className?: string
}

export const markerColors: Record<LearningNodeCategory, string> = {
  event: '#f97316',
  workshop: '#f59e0b',
  class: '#8b5cf6',
  study_group: '#3b82f6',
  tutor: '#ec4899',
  library: '#10b981',
  museum: '#06b6d4',
  educational_center: '#6366f1',
}

// Stroke icons (24×24, lucide geometry) so every marker reads at a glance.
const markerIcons: Record<LearningNodeCategory, string> = {
  event: '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  workshop: '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
  class: '<path d="M22 10 12 5 2 10l10 5 10-5z"/><path d="M6 12v5c3 3 9 3 12 0v-5"/><path d="M22 10v6"/>',
  study_group: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  tutor: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="m16 11 2 2 4-4"/>',
  library: '<path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>',
  museum: '<path d="M3 22h18"/><path d="M6 18v-7M10 18v-7M14 18v-7M18 18v-7"/><path d="M12 2 20 7H4z"/>',
  educational_center: '<path d="m4 6 8-4 8 4"/><path d="m18 10 4 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-8l4-2"/><path d="M6 5v17M18 5v17"/><path d="M14 22v-4a2 2 0 1 0-4 0v4"/>',
}

const TILE_URL = process.env.NEXT_PUBLIC_MAP_TILE_URL || 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
const TILE_ATTRIBUTION =
  process.env.NEXT_PUBLIC_MAP_TILE_ATTRIBUTION || '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character] ?? character)
}

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true
}

function boundsFor(L: LeafletModule, area: SearchArea) {
  const latDelta = area.radiusKm / 111
  const lngDelta = area.radiusKm / (111 * Math.max(Math.cos((area.latitude * Math.PI) / 180), 0.15))
  // The area is a circle; frame its inscribed square so the whole searched
  // area is on screen without a wide empty margin.
  const shrink = Math.SQRT1_2
  return L.latLngBounds(
    [area.latitude - latDelta * shrink, area.longitude - lngDelta * shrink],
    [area.latitude + latDelta * shrink, area.longitude + lngDelta * shrink],
  )
}

/**
 * The Community map. Leaflet renders; the backend decides what exists. Moving
 * the map only *reports* the new viewport — the page decides whether to offer
 * "Search this area", so panning never fires a request by itself.
 */
export default function CommunityEventMap({
  nodes,
  view,
  selectedKey,
  userLocation,
  onSelect,
  onClusterSelect,
  onViewportChange,
  padding = { top: 0, bottom: 0, left: 0, right: 0 },
  className,
}: CommunityEventMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const mapRef = useRef<LeafletMap | null>(null)
  const leafletRef = useRef<LeafletModule | null>(null)
  const markerLayerRef = useRef<LayerGroup | null>(null)
  const userLayerRef = useRef<LayerGroup | null>(null)
  const appliedViewToken = useRef<number | null>(null)
  // Set before the app moves the map; the next moveend is then not the learner's.
  const programmaticMove = useRef(false)
  // Whether the learner has panned or zoomed since the app last framed a view.
  const learnerMoved = useRef(false)
  const viewRef = useRef(view)
  viewRef.current = view
  const [mapReady, setMapReady] = useState(false)
  const [zoomTick, setZoomTick] = useState(0)

  // Latest callbacks without re-running effects on every render.
  const callbacks = useRef({ onSelect, onClusterSelect, onViewportChange })
  callbacks.current = { onSelect, onClusterSelect, onViewportChange }
  const paddingRef = useRef(padding)
  paddingRef.current = padding

  /**
   * The layout changed size (first paint, a rotated phone, the desktop split
   * appearing). Until the learner touches the map, re-frame the searched area
   * for the new size so the map always opens on what was searched, not on a
   * wider view that depends on how fast the page laid out.
   */
  const settleLayout = (map: LeafletMap) => {
    resizeQuietly(map, programmaticMove)
    const L = leafletRef.current
    if (!L || learnerMoved.current) return
    const pad = paddingRef.current
    programmaticMove.current = true
    map.fitBounds(boundsFor(L, viewRef.current), {
      paddingTopLeft: [pad.left, pad.top],
      paddingBottomRight: [pad.right, pad.bottom],
      animate: false,
    })
  }

  useEffect(() => {
    let disposed = false
    let viewportTimer: ReturnType<typeof setTimeout> | undefined
    let host: HTMLDivElement | null = null
    void import('leaflet').then((L) => {
      if (disposed || !containerRef.current || mapRef.current) return
      const reduced = prefersReducedMotion()
      host = createMapHost(containerRef.current)
      const map = L.map(host, {
        zoomControl: false,
        attributionControl: true,
        zoomAnimation: !reduced,
        fadeAnimation: !reduced,
        markerZoomAnimation: !reduced,
        worldCopyJump: true,
        minZoom: 3,
      })
      // Listen before the first fit so the starting view is known too. The
      // app's own moves are reported at once, so where it framed the map is
      // always known before any drag that follows; the learner's moves settle
      // for a moment first so a drag is one report, not dozens.
      const reportViewport = (programmatic: boolean) => {
        const bounds = map.getBounds()
        callbacks.current.onViewportChange?.(
          areaForBounds({
            north: bounds.getNorth(),
            south: bounds.getSouth(),
            east: bounds.getEast(),
            west: bounds.getWest(),
          }),
          programmatic,
        )
      }
      map.on('moveend', () => {
        const programmatic = programmaticMove.current
        programmaticMove.current = false
        if (programmatic) {
          reportViewport(true)
          return
        }
        learnerMoved.current = true
        clearTimeout(viewportTimer)
        viewportTimer = setTimeout(() => reportViewport(false), 250)
      })
      const initialPad = paddingRef.current
      programmaticMove.current = true
      map.fitBounds(boundsFor(L, view), {
        paddingTopLeft: [initialPad.left, initialPad.top],
        paddingBottomRight: [initialPad.right, initialPad.bottom],
        animate: false,
      })
      appliedViewToken.current = view.token
      L.control.zoom({ position: 'bottomright' }).addTo(map)
      L.tileLayer(TILE_URL, { maxZoom: 19, attribution: TILE_ATTRIBUTION }).addTo(map)
      leafletRef.current = L
      mapRef.current = map
      markerLayerRef.current = L.layerGroup().addTo(map)
      userLayerRef.current = L.layerGroup().addTo(map)
      map.on('zoomend', () => setZoomTick((tick) => tick + 1))
      setMapReady(true)
      requestAnimationFrame(() => {
        if (mapRef.current === map) settleLayout(map)
      })
    })
    return () => {
      disposed = true
      clearTimeout(viewportTimer)
      const map = mapRef.current
      mapRef.current = null
      markerLayerRef.current = null
      userLayerRef.current = null
      teardownMap(map, host)
    }
    // Initialization is intentionally one-time; following effects update it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Keep Leaflet's size in sync with responsive layout changes.
  useEffect(() => {
    const map = mapRef.current
    const container = containerRef.current
    if (!map || !container || typeof ResizeObserver === 'undefined') return
    const observer = new ResizeObserver(() => {
      if (mapRef.current === map) settleLayout(map)
    })
    observer.observe(container)
    return () => observer.disconnect()
  }, [mapReady])

  // Explicit view changes (locate me, a place search, a new search area).
  useEffect(() => {
    const map = mapRef.current
    const L = leafletRef.current
    if (!map || !L || !mapReady || appliedViewToken.current === view.token) return
    appliedViewToken.current = view.token
    const pad = paddingRef.current
    // A new search area: frame it, and follow layout changes again until the
    // learner moves. fitBounds always ends in exactly one moveend.
    learnerMoved.current = false
    programmaticMove.current = true
    map.fitBounds(boundsFor(L, view), {
      paddingTopLeft: [pad.left, pad.top],
      paddingBottomRight: [pad.right, pad.bottom],
      animate: !prefersReducedMotion(),
    })
  }, [mapReady, view])

  useEffect(() => {
    const L = leafletRef.current
    const layer = userLayerRef.current
    if (!L || !layer || !mapReady) return
    layer.clearLayers()
    if (!userLocation) return
    L.marker([userLocation.latitude, userLocation.longitude], {
      icon: L.divIcon({
        className: 'lyo-user-marker',
        html: '<span aria-hidden="true"></span>',
        iconSize: [22, 22],
        iconAnchor: [11, 11],
      }),
      keyboard: false,
      interactive: false,
      zIndexOffset: -100,
    }).addTo(layer)
  }, [mapReady, userLocation])

  // Markers and clusters, recomputed when the data or the zoom level changes.
  useEffect(() => {
    const map = mapRef.current
    const L = leafletRef.current
    const layer = markerLayerRef.current
    if (!map || !L || !layer || !mapReady) return
    layer.clearLayers()
    const zoom = map.getZoom()
    const clusters: NodeCluster[] =
      zoom >= 17
        ? clusterNodes(nodes, (node) => map.project([node.latitude as number, node.longitude as number], zoom), 1)
        : clusterNodes(nodes, (node) => map.project([node.latitude as number, node.longitude as number], zoom), 52)
    for (const cluster of clusters) {
      if (cluster.members.length === 1) {
        const node = cluster.members[0]
        const selected = node.key === selectedKey
        const color = markerColors[node.category] ?? '#6366f1'
        const label = `${categoryLabel(node)}: ${node.title}`
        L.marker([node.latitude as number, node.longitude as number], {
          icon: L.divIcon({
            className: 'lyo-learning-marker',
            html: `<span class="${selected ? 'is-selected' : ''}${node.lifecycle === 'live' ? ' is-live' : ''}" style="--marker:${color}" role="button" aria-label="${escapeHtml(label)}"><svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">${markerIcons[node.category] ?? markerIcons.event}</svg></span>`,
            iconSize: [40, 46],
            iconAnchor: [20, 44],
          }),
          keyboard: true,
          title: label,
          alt: label,
          riseOnHover: true,
          zIndexOffset: selected ? 1000 : 0,
        })
          .on('click', () => callbacks.current.onSelect(node))
          .addTo(layer)
        continue
      }
      const count = cluster.members.length
      const size = count < 10 ? 40 : count < 50 ? 46 : 52
      const containsSelected = cluster.members.some((node) => node.key === selectedKey)
      L.marker([cluster.latitude, cluster.longitude], {
        icon: L.divIcon({
          className: 'lyo-cluster-marker',
          html: `<span class="${containsSelected ? 'is-selected' : ''}" style="--size:${size}px" role="button" aria-label="${count} learning opportunities here. Zoom in to see them.">${count}</span>`,
          iconSize: [size, size],
          iconAnchor: [size / 2, size / 2],
        }),
        keyboard: true,
        title: `${count} learning opportunities`,
        alt: `${count} learning opportunities`,
      })
        .on('click', () => {
          const bounds = L.latLngBounds(
            [cluster.bounds.south, cluster.bounds.west],
            [cluster.bounds.north, cluster.bounds.east],
          )
          const nextZoom = map.getBoundsZoom(bounds.pad(0.3))
          if (nextZoom > map.getZoom() && map.getZoom() < 17) {
            const pad = paddingRef.current
            map.fitBounds(bounds.pad(0.3), {
              paddingTopLeft: [pad.left, pad.top],
              paddingBottomRight: [pad.right, pad.bottom],
              animate: !prefersReducedMotion(),
            })
          } else {
            // Same building or max zoom: list them instead of zooming forever.
            callbacks.current.onClusterSelect?.(cluster.members)
          }
        })
        .addTo(layer)
    }
  }, [mapReady, nodes, selectedKey, zoomTick])

  // Keep a selected pin visible, but never re-frame the whole map for it.
  useEffect(() => {
    const map = mapRef.current
    const L = leafletRef.current
    if (!map || !L || !mapReady || !selectedKey) return
    const node = nodes.find((item) => item.key === selectedKey)
    if (node?.latitude == null || node.longitude == null) return
    const pad = paddingRef.current
    const size = map.getSize()
    const point = map.latLngToContainerPoint([node.latitude, node.longitude])
    const visible =
      point.x >= pad.left + 24 &&
      point.x <= size.x - pad.right - 24 &&
      point.y >= pad.top + 40 &&
      point.y <= size.y - pad.bottom - 16
    if (visible) return
    const targetX = pad.left + (size.x - pad.left - pad.right) / 2
    const targetY = pad.top + (size.y - pad.top - pad.bottom) / 2
    map.panBy([point.x - targetX, point.y - targetY], { animate: !prefersReducedMotion() })
  }, [mapReady, nodes, selectedKey])

  return (
    <div
      ref={containerRef}
      role="application"
      aria-label="Map of learning opportunities. Use Tab to move between places, Enter to open one."
      className={className ?? 'lyo-map h-full w-full bg-[#0b1230]'}
    />
  )
}
