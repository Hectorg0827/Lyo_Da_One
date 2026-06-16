'use client'

import { motion } from 'framer-motion'
import { Plus } from 'lucide-react'
import { cn, getInitials } from '@/lib/utils'
import { useApi } from '@/hooks/use-api'
import { api } from '@/lib/api'

interface StoryUser {
  id: string
  name: string
  avatar?: string
  viewed: boolean
}

interface StoriesRailProps {
  onStoryClick?: (userId: string) => void
  onAddStory?: () => void
  className?: string
}

const AVATAR_COLORS = [
  'from-blue-500 to-indigo-600',
  'from-pink-500 to-rose-600',
  'from-emerald-500 to-teal-600',
  'from-orange-500 to-amber-600',
  'from-violet-500 to-purple-600',
  'from-cyan-500 to-blue-600',
  'from-red-500 to-pink-600',
  'from-green-500 to-emerald-600',
]

function StoryCircle({ user, index, onClick }: { user: StoryUser; index: number; onClick?: () => void }) {
  const color = AVATAR_COLORS[index % AVATAR_COLORS.length]

  return (
    <motion.button
      whileHover={{ scale: 1.05 }}
      whileTap={{ scale: 0.95 }}
      onClick={onClick}
      className="flex flex-col items-center gap-1.5 flex-shrink-0"
    >
      {/* Ring + Avatar */}
      <div
        className={cn(
          'w-16 h-16 rounded-full p-0.5',
          user.viewed
            ? 'bg-white/20'
            : 'bg-gradient-to-tr from-lyo-500 via-accent-purple to-accent-pink'
        )}
      >
        <div className="w-full h-full rounded-full border-2 border-[#0f0f1a] overflow-hidden">
          {user.avatar ? (
            <img src={user.avatar} alt={user.name} className="w-full h-full object-cover" />
          ) : (
            <div className={cn('w-full h-full rounded-full bg-gradient-to-br flex items-center justify-center text-sm font-bold text-white', color)}>
              {getInitials(user.name)}
            </div>
          )}
        </div>
      </div>
      <span className={cn('text-xs truncate w-16 text-center', user.viewed ? 'text-white/40' : 'text-white/80')}>
        {user.name.split(' ')[0]}
      </span>
    </motion.button>
  )
}

export default function StoriesRail({ onStoryClick, onAddStory, className }: StoriesRailProps) {
  const { data } = useApi(() => api.stories.list(), [])

  const stories: StoryUser[] = (data?.stories ?? []).map((s) => ({
    id: String(s.id),
    name: (s.user_name as string) || (s.username as string) || (s.display_name as string) || 'User',
    avatar: (s.avatar_url as string) || (s.user_avatar as string) || undefined,
    viewed: (s.viewed as boolean) || (s.is_seen as boolean) || false,
  }))

  return (
    <div className={cn('w-full', className)}>
      <div
        className="flex gap-4 overflow-x-auto pb-2"
        style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
      >
        {/* Your Story */}
        <motion.button
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={onAddStory}
          className="flex flex-col items-center gap-1.5 flex-shrink-0"
        >
          <div className="w-16 h-16 rounded-full border-2 border-dashed border-white/30 flex items-center justify-center bg-white/5 hover:bg-white/10 hover:border-lyo-500/60 transition-colors">
            <Plus className="w-6 h-6 text-white/50" />
          </div>
          <span className="text-xs text-white/60 w-16 text-center">Add Story</span>
        </motion.button>

        {/* Story Circles */}
        {stories.map((user, i) => (
          <StoryCircle
            key={user.id}
            user={user}
            index={i}
            onClick={() => onStoryClick?.(user.id)}
          />
        ))}
      </div>

      {/* Hide scrollbar for WebKit */}
      <style>{`
        div::-webkit-scrollbar { display: none; }
      `}</style>
    </div>
  )
}
