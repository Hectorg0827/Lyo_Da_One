'use client'

import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { Users, Check } from 'lucide-react'
import { cn, formatNumber } from '@/lib/utils'
import { api } from '@/lib/api'
import type { Group } from '@/types'

interface GroupCardProps {
  group: Group
  className?: string
}

const CATEGORY_GRADIENTS: Record<string, string> = {
  Technology: 'from-blue-600 to-indigo-700',
  Science: 'from-emerald-600 to-teal-700',
  Arts: 'from-pink-600 to-rose-700',
  Languages: 'from-orange-600 to-amber-700',
  Math: 'from-violet-600 to-purple-700',
  Business: 'from-cyan-600 to-blue-700',
  Health: 'from-green-600 to-emerald-700',
  History: 'from-yellow-600 to-orange-700',
  General: 'from-lyo-500 to-accent-purple',
}

const CATEGORY_BADGE_STYLES: Record<string, string> = {
  Technology: 'bg-blue-500/20 text-blue-300 border-blue-500/30',
  Science: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30',
  Arts: 'bg-pink-500/20 text-pink-300 border-pink-500/30',
  Languages: 'bg-orange-500/20 text-orange-300 border-orange-500/30',
  Math: 'bg-violet-500/20 text-violet-300 border-violet-500/30',
  Business: 'bg-cyan-500/20 text-cyan-300 border-cyan-500/30',
  Health: 'bg-green-500/20 text-green-300 border-green-500/30',
  History: 'bg-yellow-500/20 text-yellow-300 border-yellow-500/30',
  General: 'bg-lyo-500/20 text-lyo-300 border-lyo-500/30',
}

export default function GroupCard({ group, className }: GroupCardProps) {
  const [joined, setJoined] = useState(group.isJoined ?? false)
  const [memberCount, setMemberCount] = useState(group.memberCount)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    setJoined(group.isJoined ?? false)
    setMemberCount(group.memberCount)
  }, [group.isJoined, group.memberCount])

  const gradient = CATEGORY_GRADIENTS[group.category] ?? CATEGORY_GRADIENTS.General
  const badgeStyle = CATEGORY_BADGE_STYLES[group.category] ?? CATEGORY_BADGE_STYLES.General

  const toggleJoin = async (e: React.MouseEvent) => {
    e.stopPropagation()
    if (busy) return
    setBusy(true)
    // Optimistic flip; revert if the server rejects it
    const wasJoined = joined
    setJoined(!wasJoined)
    setMemberCount(p => (wasJoined ? p - 1 : p + 1))
    try {
      if (wasJoined) {
        await api.community.leaveGroup(group.id)
      } else {
        await api.community.joinGroup(group.id)
      }
    } catch (err) {
      console.error('Failed to update membership:', err)
      setJoined(wasJoined)
      setMemberCount(p => (wasJoined ? p + 1 : p - 1))
    } finally {
      setBusy(false)
    }
  }

  return (
    <motion.div
      whileHover={{ y: -4 }}
      transition={{ type: 'spring', stiffness: 300, damping: 22 }}
      className={cn(
        'group relative rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm overflow-hidden cursor-pointer transition-shadow hover:shadow-xl hover:shadow-black/40 hover:border-white/20',
        className
      )}
    >
      {/* Cover Gradient */}
      <div className={cn('h-24 w-full bg-gradient-to-br', gradient, 'relative')}>
        <div className="absolute inset-0 bg-black/20" />
        {/* Group Icon */}
        <div className="absolute -bottom-5 left-4 w-12 h-12 rounded-xl border-2 border-[#0f0f1a] bg-[#0f0f1a] flex items-center justify-center text-2xl shadow-lg">
          {group.icon || '📚'}
        </div>
      </div>

      <div className="pt-7 px-4 pb-4">
        {/* Name + Category */}
        <div className="flex items-start justify-between gap-2 mb-1.5">
          <h3 className="font-semibold text-white text-sm leading-tight line-clamp-1">{group.name}</h3>
          <span className={cn('flex-shrink-0 text-xs px-2 py-0.5 rounded-full border font-medium', badgeStyle)}>
            {group.category}
          </span>
        </div>

        {/* Description */}
        <p className="text-xs text-white/50 line-clamp-2 mb-3 leading-relaxed">{group.description}</p>

        {/* Member Count */}
        <div className="flex items-center gap-1.5 text-xs text-white/40 mb-3">
          <Users className="w-3.5 h-3.5" />
          <span>{formatNumber(memberCount)} members</span>
        </div>

        {/* Recent Activity */}
        {group.recentActivity && (
          <p className="text-xs text-white/30 truncate mb-3">
            {group.recentActivity}
          </p>
        )}

        {/* Join Button */}
        <button
          onClick={toggleJoin}
          disabled={busy}
          className={cn(
            'w-full py-2 rounded-xl text-sm font-semibold transition-all duration-200',
            joined
              ? 'border border-accent-green/40 text-accent-green bg-accent-green/10 hover:bg-red-500/10 hover:border-red-400/40 hover:text-red-400'
              : 'bg-gradient-to-r from-lyo-500 to-accent-purple text-white hover:opacity-90 shadow-md'
          )}
        >
          <span className="flex items-center justify-center gap-1.5">
            {joined && <Check className="w-3.5 h-3.5" />}
            {joined ? 'Joined' : 'Join Group'}
          </span>
        </button>
      </div>
    </motion.div>
  )
}
