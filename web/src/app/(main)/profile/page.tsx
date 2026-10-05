'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { Activity, MessageCircle, Trophy, Lock } from 'lucide-react';
import { useAuthStore } from '@/stores/auth-store';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import ProfileHeader from '@/components/profile/ProfileHeader';
import { formatTimeAgo } from '@/lib/utils';

type ActivityItem = {
  id: string;
  text: string;
  sub: string;
  time: string;
};

type AchievementItem = {
  id: string;
  title: string;
  desc: string;
  xp: number;
  icon: string;
  unlocked: boolean;
};

const tabs = [
  { id: 'activity', label: 'Activity', icon: Activity },
  { id: 'achievements', label: 'Achievements', icon: Trophy },
] as const;

export default function ProfilePage() {
  const { user } = useAuthStore();
  const [activeTab, setActiveTab] = useState<(typeof tabs)[number]['id']>('activity');

  const { data: achievementsRaw } = useApi(() => api.gamification.achievements(), []);
  const { data: feedData } = useApi(user ? () => api.users.posts(user.id) : null, [user?.id]);

  if (!user) return null;

  const activity: ActivityItem[] = feedData?.posts
    ? feedData.posts.slice(0, 12).map((post: Record<string, unknown>, index: number) => ({
        id: String(post.id ?? index),
        text: String(post.content ?? ''),
        sub: `${Number(post.like_count) || 0} likes · ${Number(post.comment_count) || 0} comments`,
        time: (post.created_at as string) || new Date().toISOString(),
      }))
    : [];

  const achievements: AchievementItem[] = Array.isArray(achievementsRaw)
    ? achievementsRaw.map((raw: Record<string, unknown>, index: number) => ({
        id: String(raw.id ?? index),
        title: String(raw.name ?? raw.achievement_name ?? 'Achievement'),
        desc: String(raw.description ?? ''),
        xp: Number(raw.xp_reward) || 0,
        icon: String(raw.icon ?? '🏆'),
        unlocked: Boolean(raw.completed ?? raw.is_completed),
      }))
    : [];

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="mx-auto max-w-3xl space-y-6 px-4 py-6 sm:px-6"
    >
      <ProfileHeader user={user} isOwnProfile />

      <div className="flex gap-1.5 overflow-x-auto no-scrollbar">
        {tabs.map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => setActiveTab(id)}
            className={`flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition ${
              activeTab === id ? 'bg-lyo-600 text-white' : 'bg-white/[0.04] text-secondary hover:bg-white/[0.07] hover:text-primary'
            }`}
          >
            <Icon size={14} />
            {label}
          </button>
        ))}
      </div>

      {activeTab === 'activity' && (
        <div className="space-y-3">
          {activity.length ? activity.map((item, index) => (
            <motion.div
              key={item.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.03 }}
              className="glass-card flex items-start gap-3 p-4"
            >
              <div className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-indigo-500/15 text-violet-300">
                <MessageCircle size={16} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm leading-relaxed text-primary">{item.text || 'Shared an update'}</p>
                <p className="mt-1 text-xs text-secondary">{item.sub}</p>
              </div>
              <span className="shrink-0 text-[10px] text-secondary">{formatTimeAgo(item.time)}</span>
            </motion.div>
          )) : (
            <div className="glass-card px-5 py-10 text-center">
              <MessageCircle className="mx-auto mb-3 text-white/25" />
              <p className="text-sm font-medium text-white/70">No activity yet</p>
              <p className="mt-1 text-xs text-white/40">Posts you share in Community will appear here.</p>
            </div>
          )}
        </div>
      )}

      {activeTab === 'achievements' && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {achievements.length ? achievements.map((achievement, index) => (
            <motion.div
              key={achievement.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: achievement.unlocked ? 1 : 0.5, y: 0 }}
              transition={{ delay: index * 0.03 }}
              className="glass-card flex flex-col items-center gap-2 p-4 text-center"
            >
              <div className={`flex h-14 w-14 items-center justify-center rounded-2xl text-2xl ${
                achievement.unlocked ? 'bg-gradient-to-br from-indigo-500 to-violet-500' : 'bg-white/[0.06]'
              }`}>
                {achievement.unlocked ? achievement.icon : <Lock size={20} className="text-white/30" />}
              </div>
              <div>
                <p className="text-xs font-bold text-primary">{achievement.title}</p>
                {achievement.desc && <p className="mt-1 text-[10px] leading-snug text-secondary">{achievement.desc}</p>}
              </div>
              {achievement.xp > 0 && <span className="text-[10px] font-bold text-amber-400">+{achievement.xp} XP</span>}
            </motion.div>
          )) : (
            <div className="col-span-full glass-card px-5 py-10 text-center">
              <Trophy className="mx-auto mb-3 text-white/25" />
              <p className="text-sm font-medium text-white/70">No achievements yet</p>
            </div>
          )}
        </div>
      )}
    </motion.div>
  );
}
