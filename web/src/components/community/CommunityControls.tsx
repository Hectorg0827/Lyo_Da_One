'use client'

import { useEffect, useRef, useState, type FormEvent, type PointerEvent as ReactPointerEvent } from 'react'
import { Loader2, Search, X } from 'lucide-react'
import { FILTERS, type FilterId } from '@/lib/community-contract.mjs'
import { cn } from '@/lib/utils'

const SUGGESTIONS = ['Libraries', 'Study groups', 'Coding workshop', 'SAT prep', 'Museums', 'Spanish classes']

export function CommunitySearchBar({
  value,
  onChange,
  onSubmit,
  onClear,
  busy,
  className,
}: {
  value: string
  onChange: (value: string) => void
  onSubmit: (value: string) => void
  onClear: () => void
  busy: boolean
  className?: string
}) {
  const [focused, setFocused] = useState(false)
  const submit = (event: FormEvent) => {
    event.preventDefault()
    if (value.trim()) onSubmit(value.trim())
  }
  return (
    <div className={cn('relative', className)}>
      <form role="search" onSubmit={submit} className="relative">
        <label htmlFor="community-search" className="sr-only">
          Search places, topics, or neighborhoods
        </label>
        <Search className="pointer-events-none absolute left-3.5 top-1/2 z-10 h-4 w-4 -translate-y-1/2 text-white/50" aria-hidden="true" />
        <input
          id="community-search"
          type="search"
          value={value}
          enterKeyHint="search"
          autoComplete="off"
          onFocus={() => setFocused(true)}
          onBlur={() => setTimeout(() => setFocused(false), 150)}
          onChange={(event) => onChange(event.target.value)}
          placeholder="Search classes, libraries, a neighborhood…"
          className="lyo-search-input h-12 w-full rounded-2xl border border-white/10 bg-[#0e173d]/90 pl-10 pr-20 text-[15px] text-white shadow-[0_8px_24px_rgba(3,7,18,0.35)] backdrop-blur-xl placeholder:text-white/40 focus:border-lyo-400 focus:outline-none"
        />
        <div className="absolute right-1.5 top-1/2 flex -translate-y-1/2 items-center gap-1">
          {busy && <Loader2 className="h-4 w-4 animate-spin text-lyo-300" aria-label="Searching" />}
          {value && !busy && (
            <button
              type="button"
              onClick={onClear}
              aria-label="Clear search"
              className="flex h-9 w-9 items-center justify-center rounded-xl text-white/50 hover:bg-white/10 hover:text-white"
            >
              <X className="h-4 w-4" aria-hidden="true" />
            </button>
          )}
          <button type="submit" className="sr-only">
            Search
          </button>
        </div>
      </form>
      {focused && !value && (
        <div className="absolute inset-x-0 top-[52px] z-20 rounded-2xl border border-white/10 bg-[#0e173d]/95 p-2 shadow-2xl backdrop-blur-xl">
          <p className="px-2 pb-1 pt-0.5 text-[11px] font-medium uppercase tracking-wide text-white/40">Try</p>
          <div className="flex flex-wrap gap-1.5">
            {SUGGESTIONS.map((suggestion) => (
              <button
                key={suggestion}
                type="button"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => {
                  onChange(suggestion)
                  onSubmit(suggestion)
                }}
                className="min-h-[36px] rounded-full border border-white/10 px-3 text-sm text-white/75 hover:border-lyo-400/50 hover:text-white"
              >
                {suggestion}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

export function FilterChips({
  active,
  onToggle,
  onClear,
  className,
}: {
  active: Set<FilterId>
  onToggle: (id: FilterId) => void
  onClear: () => void
  className?: string
}) {
  return (
    <div className={cn('flex items-center gap-2 overflow-x-auto no-scrollbar', className)} role="toolbar" aria-label="Filters">
      <button
        type="button"
        onClick={onClear}
        aria-pressed={active.size === 0}
        className={cn(
          'min-h-[36px] shrink-0 rounded-full border px-3.5 text-[13px] font-medium transition',
          active.size === 0
            ? 'border-lyo-400/70 bg-lyo-500/25 text-white'
            : 'border-white/10 bg-[#0e173d]/85 text-white/70 backdrop-blur-md hover:text-white',
        )}
      >
        {active.size ? 'Clear' : 'All'}
      </button>
      {FILTERS.map((filter) => {
        const on = active.has(filter.id)
        return (
          <button
            key={filter.id}
            type="button"
            aria-pressed={on}
            onClick={() => onToggle(filter.id)}
            className={cn(
              'min-h-[36px] shrink-0 rounded-full border px-3.5 text-[13px] font-medium transition',
              on
                ? 'border-lyo-400/70 bg-lyo-500/25 text-white'
                : 'border-white/10 bg-[#0e173d]/85 text-white/70 backdrop-blur-md hover:text-white',
            )}
          >
            {filter.label}
          </button>
        )
      })}
    </div>
  )
}

export type SheetState = 'collapsed' | 'medium' | 'expanded'

const SHEET_ORDER: SheetState[] = ['collapsed', 'medium', 'expanded']

/**
 * Mobile results/preview sheet. Drag the handle (or press it) to move between
 * a peek, half height, and nearly full height; the map stays usable above.
 */
export function BottomSheet({
  state,
  onStateChange,
  title,
  children,
  bottomInset,
  contentKey,
  onHeightChange,
}: {
  state: SheetState
  onStateChange: (state: SheetState) => void
  title: React.ReactNode
  children: React.ReactNode
  /** Space under the sheet taken by the app's bottom navigation. */
  bottomInset: string
  /** When this changes (list ↔ a preview), the content starts at the top. */
  contentKey?: string
  /** The sheet's real height in px, so the map can keep pins above it. */
  onHeightChange?: (height: number) => void
}) {
  const sheetRef = useRef<HTMLDivElement | null>(null)
  const contentRef = useRef<HTMLDivElement | null>(null)
  const drag = useRef<{ startY: number; startHeight: number } | null>(null)
  const [dragHeight, setDragHeight] = useState<number | null>(null)
  const [viewportHeight, setViewportHeight] = useState(800)

  useEffect(() => {
    const parent = sheetRef.current?.parentElement
    if (!parent) return
    const update = () => setViewportHeight(parent.clientHeight)
    update()
    const observer = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(update)
    observer?.observe(parent)
    return () => observer?.disconnect()
  }, [])

  const heights: Record<SheetState, number> = {
    collapsed: 84,
    medium: Math.round(viewportHeight * 0.46),
    expanded: Math.round(viewportHeight * 0.86),
  }
  const height = dragHeight ?? heights[state]

  useEffect(() => {
    onHeightChange?.(height)
  }, [height, onHeightChange])

  useEffect(() => {
    if (contentRef.current) contentRef.current.scrollTop = 0
  }, [contentKey])

  const onPointerDown = (event: ReactPointerEvent<HTMLButtonElement>) => {
    drag.current = { startY: event.clientY, startHeight: heights[state] }
    event.currentTarget.setPointerCapture(event.pointerId)
  }
  const onPointerMove = (event: ReactPointerEvent<HTMLButtonElement>) => {
    if (!drag.current) return
    const next = drag.current.startHeight + (drag.current.startY - event.clientY)
    setDragHeight(Math.max(heights.collapsed, Math.min(heights.expanded, next)))
  }
  const onPointerUp = (event: ReactPointerEvent<HTMLButtonElement>) => {
    if (!drag.current) return
    const moved = Math.abs(event.clientY - drag.current.startY)
    drag.current = null
    if (moved < 6 || dragHeight == null) {
      setDragHeight(null)
      const index = SHEET_ORDER.indexOf(state)
      onStateChange(SHEET_ORDER[(index + 1) % SHEET_ORDER.length])
      return
    }
    const nearest = SHEET_ORDER.reduce((best, candidate) =>
      Math.abs(heights[candidate] - dragHeight) < Math.abs(heights[best] - dragHeight) ? candidate : best,
    )
    setDragHeight(null)
    onStateChange(nearest)
  }

  return (
    <section
      ref={sheetRef}
      aria-label="Learning opportunities"
      className={cn(
        'absolute inset-x-0 z-20 flex flex-col rounded-t-[26px] border-t border-white/10 bg-[#0b1230]/[0.97] shadow-[0_-12px_40px_rgba(3,7,18,0.55)] backdrop-blur-2xl',
        dragHeight == null && 'transition-[height] duration-300 ease-out motion-reduce:transition-none',
      )}
      style={{ height, bottom: bottomInset }}
    >
      <button
        type="button"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={() => {
          drag.current = null
          setDragHeight(null)
        }}
        onKeyDown={(event) => {
          if (event.key === 'ArrowUp') {
            event.preventDefault()
            onStateChange(SHEET_ORDER[Math.min(SHEET_ORDER.length - 1, SHEET_ORDER.indexOf(state) + 1)])
          } else if (event.key === 'ArrowDown') {
            event.preventDefault()
            onStateChange(SHEET_ORDER[Math.max(0, SHEET_ORDER.indexOf(state) - 1)])
          }
        }}
        aria-label={state === 'expanded' ? 'Collapse list' : 'Expand list'}
        aria-expanded={state !== 'collapsed'}
        className="flex w-full shrink-0 touch-none flex-col items-center gap-2 px-5 pb-2 pt-2.5"
      >
        <span className="h-1.5 w-10 rounded-full bg-white/25" aria-hidden="true" />
        <span className="w-full text-left">{title}</span>
      </button>
      {/* Bottom padding lets the last row scroll clear of the app's centre button. */}
      <div
        ref={contentRef}
        aria-hidden={state === 'collapsed' && dragHeight == null}
        className={cn(
          'min-h-0 flex-1 overflow-y-auto overscroll-contain px-3 pb-16',
          state === 'collapsed' && dragHeight == null && 'invisible',
        )}
      >
        {children}
      </div>
    </section>
  )
}
