'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { Flame, Zap, Edit3, UserPlus, UserCheck, Star, Crown } from 'lucide-react';
import { User } from '@/types';
import { cn } from '@/lib/utils';

interface ProfileHeaderProps {
  user: User;
  isOwnProfile: boolean;
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

export default function ProfileHeader({ user, isOwnProfile, onFollow }: ProfileHeaderProps) {
  const [isFollowing, setIsFollowing] = useState(false);
  const xpProgress = getXpProgress(user.xp, user.level);
  const xpInLevel = getXpInLevel(user.xp, user.level);

  const handleFollow = () => {
    setIsFollowing((prev) => !prev);
    onFollow?.();
  };

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
      {/* ── Cover Banner ─────────────────────────────────────────────── */}
      <div
        className="h-52 w-full relative overflow-hidden"
        style={{
          background: 'linear-gradient(135deg, #6c63ff 0%, #8b5cf6 40%, #ec4899 80%, #f59e0b 100%)',
        }}
      >
        {/* Decorative blobs */}
        <div
          className="absolute -top-10 -right-10 w-48 h-48 rounded-full blur-3xl opacity-50"
          style={{ background: 'radial-gradient(circle, rgba(236,72,153,0.7), transparent)' }}
        />
        <div
          className="absolute bottom-0 left-1/4 w-32 h-32 rounded-full blur-2xl opacity-40"
          style={{ background: 'radial-gradient(circle, rgba(167,139,250,0.8), transparent)' }}
        />
        <div
          className="absolute top-4 left-8 w-20 h-20 rounded-full blur-2xl opacity-30"
          style={{ background: 'radial-gradient(circle, rgba(108,99,255,0.9), transparent)' }}
        />

        {/* Badges in cover */}
        <div className="absolute top-4 left-4 flex items-center gap-2">
          {user.isPremium && (
            <motion.span
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.3 }}
              className="flex items-center gap-1 px-3 py-1 rounded-full text-xs font-bold text-white"
              style={{ background: 'linear-gradient(135deg, #f59e0b, #ef4444)', boxShadow: '0 2px 12px rgba(245,158,11,0.4)' }}
            >
              <Crown size={10} fill="white" /> Premium
            </motion.span>
          )}
        </div>
        <div className="absolute top-4 right-4">
          <span
            className="text-xs font-bold px-3 py-1 rounded-full capitalize text-white"
            style={{ background: 'rgba(0,0,0,0.3)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.15)' }}
          >
            {user.role}
          </span>
        </div>
      </div>

      {/* ── Profile Body ─────────────────────────────────────────────── */}
      <div className="px-5 pb-6">
        {/* Avatar row */}
        <div className="flex items-end justify-between -mt-14 mb-4">
          {/* Avatar */}
          <motion.div
            className="relative"
            initial={{ scale: 0.7, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ type: 'spring', stiffness: 260, damping: 20, delay: 0.1 }}
          >
            <div
              className="w-24 h-24 rounded-2xl p-[3px]"
              style={{
                background: 'linear-gradient(135deg, #6c63ff, #ec4899)',
                boxShadow: '0 8px 32px rgba(108,99,255,0.5)',
              }}
            >
              <div className="w-full h-full rounded-[14px] overflow-hidden" style={{ background: 'var(--surface-2)' }}>
                {user.avatar ? (
                  <img src={user.avatar} alt={user.displayName} className="w-full h-full object-cover" />
                ) : (
                  <div
                    className="w-full h-full flex items-center justify-center text-3xl font-black text-white"
                    style={{ background: 'linear-gradient(135deg, #6c63ff, #8b5cf6)' }}
                  >
                    {user.displayName.charAt(0).toUpperCase()}
                  </div>
                )}
              </div>
            </div>
            {/* Online indicator */}
            <div
              className="absolute -bottom-1 -right-1 w-4 h-4 rounded-full border-2"
              style={{ background: '#22c55e', borderColor: 'var(--surface)' }}
            />
          </motion.div>

          {/* Action button */}
          <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}>
            {isOwnProfile ? (
              <button className="flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold border border-white/15 bg-white/5 text-primary hover:bg-white/10 hover:border-white/25 transition-all duration-200">
                <Edit3 size={14} />
                Edit Profile
              </button>
            ) : (
              <button
                onClick={handleFollow}
                className={cn(
                  'flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold transition-all duration-200 active:scale-95',
                  isFollowing
                    ? 'border border-white/15 bg-white/5 text-primary hover:bg-red-500/10 hover:border-red-500/30 hover:text-red-400'
                    : 'text-white hover:opacity-90'
                )}
                style={
                  !isFollowing
                    ? { background: 'linear-gradient(135deg, #6c63ff, #8b5cf6)', boxShadow: '0 4px 20px rgba(108,99,255,0.4)' }
                    : {}
                }
              >
                {isFollowing ? (
                  <>
                    <UserCheck size={14} />
                    Following
                  </>
                ) : (
                  <>
                    <UserPlus size={14} />
                    Follow
                  </>
                )}
              </button>
            )}
          </motion.div>
        </div>

        {/* Name, username, bio */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.15 }}
          className="mb-4"
        >
          <h1 className="text-2xl font-black leading-tight gradient-text">{user.displayName}</h1>
          <p className="text-sm mt-0.5" style={{ color: 'var(--text-secondary)' }}>@{user.username}</p>
          {user.bio && (
            <p className="text-sm mt-2 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
              {user.bio}
            </p>
          )}
        </motion.div>

        {/* Level badge */}
        <motion.div
          initial={{ opacity: 0, x: -10 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.2 }}
          className="flex items-center gap-2 mb-4"
        >
          <div
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold"
            style={{
              background: 'linear-gradient(135deg, rgba(108,99,255,0.25), rgba(139,92,246,0.15))',
              border: '1px solid rgba(108,99,255,0.35)',
              color: '#a78bfa',
            }}
          >
            <Zap size={12} fill="#a78bfa" />
            Level {user.level}
          </div>
          <span className="text-xs" style={{ color: 'var(--text-secondary)' }}>{user.xp.toLocaleString()} total XP</span>
        </motion.div>

        {/* Stats row */}
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.25 }}
          className="flex items-center rounded-2xl overflow-hidden mb-4"
          style={{ border: '1px solid rgba(255,255,255,0.08)', background: 'rgba(255,255,255,0.03)' }}
        >
          {stats.map((stat, i) => (
            <button
              key={stat.label}
              className="flex-1 py-3.5 flex flex-col items-center hover:bg-white/5 transition-colors duration-200"
              style={{ borderRight: i < stats.length - 1 ? '1px solid rgba(255,255,255,0.08)' : 'none' }}
            >
              <span className="text-lg font-black" style={{ color: 'var(--text-primary)' }}>{stat.value}</span>
              <span className="text-[11px] mt-0.5" style={{ color: 'var(--text-secondary)' }}>{stat.label}</span>
            </button>
          ))}
        </motion.div>

        {/* XP progress bar */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.3 }}
          className="mb-4 space-y-1.5"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs" style={{ color: 'var(--text-secondary)' }}>Progress to Level {user.level + 1}</span>
            <span className="text-xs font-medium" style={{ color: 'var(--text-secondary)' }}>
              {xpInLevel.toLocaleString()} / {XP_PER_LEVEL.toLocaleString()} XP
            </span>
          </div>
          <div className="h-2 w-full rounded-full overflow-hidden" style={{ background: 'rgba(255,255,255,0.08)' }}>
            <motion.div
              className="h-full rounded-full"
              style={{ background: 'linear-gradient(90deg, #6c63ff, #a78bfa)' }}
              initial={{ width: 0 }}
              animate={{ width: `${xpProgress}%` }}
              transition={{ duration: 1, ease: 'easeOut', delay: 0.5 }}
            />
          </div>
        </motion.div>

        {/* Streak banner */}
        <motion.div
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.35 }}
          className="flex items-center gap-2.5 px-4 py-3 rounded-2xl mb-4"
          style={{ background: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.2)' }}
        >
          <Flame size={18} style={{ color: '#f59e0b' }} />
          <div>
            <span className="text-sm font-bold" style={{ color: '#fb923c' }}>
              {user.streak} day streak
            </span>
            <span className="text-xs ml-2" style={{ color: 'var(--text-secondary)' }}>Keep it going!</span>
          </div>
        </motion.div>

        {/* Interest tags */}
        {user.interests.length > 0 && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.4 }}
            className="flex flex-wrap gap-1.5"
          >
            {user.interests.map((interest) => (
              <span
                key={interest}
                className="text-xs px-3 py-1 rounded-full font-medium cursor-pointer hover:opacity-80 transition-opacity"
                style={{
                  background: 'rgba(108,99,255,0.12)',
                  color: '#8b83ff',
                  border: '1px solid rgba(108,99,255,0.22)',
                }}
              >
                {interest}
              </span>
            ))}
          </motion.div>
        )}
      </div>
    </motion.div>
  );
}
