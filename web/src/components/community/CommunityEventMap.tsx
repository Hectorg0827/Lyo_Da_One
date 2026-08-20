'use client'

import { useEffect, useRef, useState } from 'react'
import type { LayerGroup, Map as LeafletMap } from 'leaflet'
import type { LearningNode, LearningNodeCategory } from '@/types'

export interface CommunityEventMapProps {
  nodes: LearningNode[]
  center: { latitude: number; longitude: number }
  selectedKey?: string | null
  onSelect: (node: LearningNode) => void
}

const markerColors: Record<LearningNodeCategory, string> = {
  event: '#f97316',
  workshop: '#f59e0b',
  class: '#8b5cf6',
  study_group: '#3b82f6',
  tutor: '#ec4899',
  library: '#10b981',
  museum: '#06b6d4',
  educational_center: '#6366f1',
}

const markerGlyphs: Record<LearningNodeCategory, string> = {
  event: '●',
  workshop: 'W',
  class: 'C',
  study_group: 'G',
  tutor: 'T',
  library: 'L',
  museum: 'M',
  educational_center: 'E',
}

/**
 * Real multi-marker Leaflet map. The backend supplies the same nodes to web,
 * iOS, and Android; Leaflet is only the platform renderer.
 */
export default function CommunityEventMap({
  nodes,
  center,
  selectedKey,
  onSelect,
}: CommunityEventMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const mapRef = useRef<LeafletMap | null>(null)
  const markerLayerRef = useRef<LayerGroup | null>(null)
  const userMarkerLayerRef = useRef<LayerGroup | null>(null)
  const [mapReady, setMapReady] = useState(false)

  useEffect(() => {
    let disposed = false
    void import('leaflet').then((L) => {
      if (disposed || !containerRef.current || mapRef.current) return
      const map = L.map(containerRef.current, {
        zoomControl: false,
        attributionControl: true,
      }).setView([center.latitude, center.longitude], 13)
      L.control.zoom({ position: 'bottomright' }).addTo(map)
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors',
      }).addTo(map)
      mapRef.current = map
      markerLayerRef.current = L.layerGroup().addTo(map)
      userMarkerLayerRef.current = L.layerGroup().addTo(map)
      setMapReady(true)
      requestAnimationFrame(() => map.invalidateSize())
    })
    return () => {
      disposed = true
      mapRef.current?.remove()
      mapRef.current = null
      markerLayerRef.current = null
      userMarkerLayerRef.current = null
    }
    // Initialization is intentionally one-time; following effects update it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    const map = mapRef.current
    if (!map || !mapReady) return
    map.setView([center.latitude, center.longitude], map.getZoom(), { animate: true })
    void import('leaflet').then((L) => {
      const layer = userMarkerLayerRef.current
      if (!layer) return
      layer.clearLayers()
      L.circleMarker([center.latitude, center.longitude], {
        radius: 8,
        color: '#ffffff',
        weight: 3,
        fillColor: '#6366f1',
        fillOpacity: 1,
      }).bindTooltip('You are here').addTo(layer)
    })
  }, [center.latitude, center.longitude, mapReady])

  useEffect(() => {
    const map = mapRef.current
    const layer = markerLayerRef.current
    if (!map || !layer || !mapReady) return
    let disposed = false
    void import('leaflet').then((L) => {
      if (disposed || !markerLayerRef.current) return
      layer.clearLayers()
      const bounds: Array<[number, number]> = []
      nodes.forEach((node) => {
        if (!Number.isFinite(node.latitude) || !Number.isFinite(node.longitude)) return
        const latitude = node.latitude as number
        const longitude = node.longitude as number
        bounds.push([latitude, longitude])
        const selected = node.key === selectedKey
        const color = markerColors[node.category]
        const icon = L.divIcon({
          className: 'lyo-learning-marker',
          html: `<span style="--marker:${color};--scale:${selected ? 1.18 : 1}">${markerGlyphs[node.category]}</span>`,
          iconSize: [38, 44],
          iconAnchor: [19, 42],
        })
        L.marker([latitude, longitude], { icon, keyboard: true, title: node.title })
          .on('click', () => onSelect(node))
          .addTo(layer)
      })
      if (selectedKey) {
        const selected = nodes.find((node) => node.key === selectedKey)
        if (selected?.latitude != null && selected.longitude != null) {
          map.panTo([selected.latitude, selected.longitude], { animate: true })
        }
      } else if (bounds.length > 1) {
        map.fitBounds(bounds, { padding: [48, 48], maxZoom: 14 })
      }
    })
    return () => { disposed = true }
  }, [mapReady, nodes, onSelect, selectedKey])

  return (
    <div
      ref={containerRef}
      aria-label="Learning Around Me map"
      className="h-[62vh] min-h-[480px] w-full bg-[#0b1230] md:h-[680px]"
    />
  )
}
