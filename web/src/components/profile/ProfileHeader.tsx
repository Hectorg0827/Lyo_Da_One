'use client';

import { useState } from 'react';
import Link from 'next/link';
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
          background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 40%, #ec4899 80%, #f59e0b 100%)',
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
          style={{ background: 'radial-gradient(circle, rgba(99,102,241,0.9), transparent)' }}
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
                background: 'linear-gradient(135deg, #6366f1, #ec4899)',
                boxShadow: '0 8px 32px rgba(99,102,241,0.5)',
              }}
            >
              <div className="w-full h-full rounded-[14px] overflow-hidden" style={{ background: 'var(--surface-2)' }}>
                {user.avatar ? (
                  <img src={user.avatar} alt={user.displayName} className="w-full h-full object-cover" />
                ) : (
                  <div
                    className="w-full h-full flex items-center justify-center text-3xl font-black text-white"
                    style={{ background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }}
                  >
                    {user.displayName.charAt(0).toUpperCase()}
                  </div>
                )}
              </div>
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
                  background: 'rgba(99,102,241,0.12)',
                  color: '#a78bfa',
                  border: '1px solid rgba(99,102,241,0.22)',
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
