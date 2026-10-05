'use client';

import Link from 'next/link';
import { motion } from 'framer-motion';
import { Flame, Zap, Edit3, UserPlus, UserCheck, Crown } from 'lucide-react';
import { User } from '@/types';
import { cn } from '@/lib/utils';

interface ProfileHeaderProps {
  user: User;
  isOwnProfile: boolean;
  isFollowing?: boolean;
  onFollow?: () => void;
}

const XP_PER_LEVEL = 5000;

function getXpInLevel(xp: number, level: number): number {
  const base = (level - 1) * XP_PER_LEVEL;
  return Math.max(0, xp - base);
}

function getXpProgress(xp: number, level: number): number {
  const inLevel = getXpInLevel(xp, level);
  return Math.min(100, Math.round((inLevel / XP_PER_LEVEL) * 100));
}

function formatCount(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1).replace('.0', '') + 'M';
  if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace('.0', '') + 'k';
  return String(n);
}

export default function ProfileHeader({
  user,
  isOwnProfile,
  isFollowing = false,
  onFollow,
}: ProfileHeaderProps) {
  const xpProgress = getXpProgress(user.xp, user.level);
  const xpInLevel = getXpInLevel(user.xp, user.level);

  const stats = [
    { label: 'Followers', value: formatCount(user.followersCount) },
    { label: 'Following', value: formatCount(user.followingCount) },
    { label: 'Courses', value: String(user.coursesCompleted) },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
      className="glass-card overflow-hidden"
    >
      <div
        className="h-52 w-full relative overflow-hidden"
        style={{ background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 40%, #ec4899 80%, #f59e0b 100%)' }}
      >
        <div className="absolute -top-10 -right-10 h-48 w-48 rounded-full bg-pink-500/30 blur-3xl" />
        <div className="absolute bottom-0 left-1/4 h-32 w-32 rounded-full bg-violet-300/30 blur-2xl" />
        <div className="absolute top-4 left-4">
          {user.isPremium && (
            <motion.span
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.3 }}
              className="flex items-center gap-1 rounded-full bg-gradient-to-r from-amber-500 to-red-500 px-3 py-1 text-xs font-bold text-white"
            >
              <Crown size={10} fill="white" /> Premium
            </motion.span>
          )}
        </div>
      </div>

      <div className="px-5 pb-6">
        <div className="-mt-14 mb-4 flex items-end justify-between">
          <motion.div
            initial={{ scale: 0.7, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ type: 'spring', stiffness: 260, damping: 20, delay: 0.1 }}
            className="relative"
          >
            <div className="h-24 w-24 rounded-2xl bg-gradient-to-br from-indigo-500 to-pink-500 p-[3px] shadow-[0_8px_32px_rgba(99,102,241,0.5)]">
              <div className="h-full w-full overflow-hidden rounded-[14px] bg-[var(--surface-2)]">
                {user.avatar ? (
                  <img src={user.avatar} alt={user.displayName} className="h-full w-full object-cover" />
                ) : (
                  <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-indigo-500 to-violet-500 text-3xl font-black text-white">
                    {user.displayName.charAt(0).toUpperCase()}
                  </div>
                )}
              </div>
            </div>
          </motion.div>

          <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}>
            {isOwnProfile ? (
              <Link href="/settings" className="flex items-center gap-2 rounded-xl border border-white/15 bg-white/5 px-5 py-2.5 text-sm font-semibold text-primary transition hover:bg-white/10 hover:border-white/25">
                <Edit3 size={14} />
                Edit Profile
              </Link>
            ) : (
              <button
                onClick={onFollow}
                className={cn(
                  'flex items-center gap-2 rounded-xl px-5 py-2.5 text-sm font-semibold transition-all active:scale-95',
                  isFollowing
                    ? 'border border-white/15 bg-white/5 text-primary hover:border-red-500/30 hover:bg-red-500/10 hover:text-red-400'
                    : 'bg-gradient-to-r from-indigo-500 to-violet-500 text-white shadow-[0_4px_20px_rgba(99,102,241,0.4)]'
                )}
              >
                {isFollowing ? <UserCheck size={14} /> : <UserPlus size={14} />}
                {isFollowing ? 'Following' : 'Follow'}
              </button>
            )}
          </motion.div>
        </div>

        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.15 }} className="mb-4">
          <h1 className="gradient-text text-2xl font-black leading-tight">{user.displayName}</h1>
          {user.username && <p className="mt-0.5 text-sm text-secondary">@{user.username}</p>}
          {user.bio && <p className="mt-2 text-sm leading-relaxed text-secondary">{user.bio}</p>}
        </motion.div>

        <div className="mb-4 flex items-center gap-2">
          <div className="flex items-center gap-1.5 rounded-xl border border-indigo-500/35 bg-indigo-500/15 px-3 py-1.5 text-xs font-bold text-violet-300">
            <Zap size={12} fill="currentColor" />
            Level {user.level}
          </div>
          <span className="text-xs text-secondary">{user.xp.toLocaleString()} total XP</span>
        </div>

        <div className="mb-4 flex items-center overflow-hidden rounded-2xl border border-white/[0.08] bg-white/[0.03]">
          {stats.map((stat, index) => (
            <div
              key={stat.label}
              className="flex-1 py-3.5 text-center"
              style={{ borderRight: index < stats.length - 1 ? '1px solid rgba(255,255,255,0.08)' : 'none' }}
            >
              <span className="block text-lg font-black text-primary">{stat.value}</span>
              <span className="mt-0.5 block text-[11px] text-secondary">{stat.label}</span>
            </div>
          ))}
        </div>

        <div className="mb-4 space-y-1.5">
          <div className="flex items-center justify-between">
            <span className="text-xs text-secondary">Progress to Level {user.level + 1}</span>
            <span className="text-xs font-medium text-secondary">{xpInLevel.toLocaleString()} / {XP_PER_LEVEL.toLocaleString()} XP</span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full bg-white/[0.08]">
            <motion.div
              className="h-full rounded-full bg-gradient-to-r from-indigo-500 to-violet-400"
              initial={{ width: 0 }}
              animate={{ width: `${xpProgress}%` }}
              transition={{ duration: 1, ease: 'easeOut', delay: 0.5 }}
            />
          </div>
        </div>

        <div className="mb-4 flex items-center gap-2.5 rounded-2xl border border-amber-500/20 bg-amber-500/[0.08] px-4 py-3">
          <Flame size={18} className="text-amber-500" />
          <span className="text-sm font-bold text-orange-400">{user.streak} day streak</span>
        </div>

        {user.interests.length > 0 && (
          <div className="flex flex-wrap gap-1.5">
            {user.interests.map((interest) => (
              <span key={interest} className="rounded-full border border-indigo-500/20 bg-indigo-500/10 px-3 py-1 text-xs font-medium text-violet-300">
                {interest}
              </span>
            ))}
          </div>
        )}
      </div>
    </motion.div>
  );
}
