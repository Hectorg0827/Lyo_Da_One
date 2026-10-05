'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { Activity, Lock, MessageCircle, Trophy } from 'lucide-react';
import { useAuthStore } from '@/stores/auth-store';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import ProfileHeader from '@/components/profile/ProfileHeader';
import { formatTimeAgo } from '@/lib/utils';

const itemVariants = {
  hidden: { opacity: 0, y: 16 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] } },
};

const containerVariants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { staggerChildren: 0.07 } },
};

type TabId = 'activity' | 'achievements';

export default function ProfilePage() {
  const { user } = useAuthStore();
  const [activeTab, setActiveTab] = useState<TabId>('activity');
  const { data: achievementsRaw } = useApi(() => api.gamification.achievements(), []);
  const { data: feedData } = useApi(user ? () => api.users.posts(user.id) : null, [user?.id]);

  if (!user) return null;

  const activity = feedData?.posts ?? [];
  const achievements = achievementsRaw ?? [];

  return (
    <motion.div
      className="mx-auto max-w-3xl space-y-6 px-4 py-6 sm:px-6"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
    >
      <ProfileHeader user={user} isOwnProfile />

      <div className="flex gap-2 rounded-2xl border border-white/[0.06] bg-white/[0.03] p-1.5">
        {([
          { id: 'activity' as const, label: 'Activity', icon: Activity },
          { id: 'achievements' as const, label: 'Achievements', icon: Trophy },
        ]).map((tab) => {
          const Icon = tab.icon;
          const active = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id)}
              className={`flex flex-1 items-center justify-center gap-2 rounded-xl px-3 py-2.5 text-sm font-semibold transition-all ${active ? 'bg-lyo-600 text-white' : 'text-secondary hover:bg-white/[0.04] hover:text-primary'}`}
            >
              <Icon size={15} />
              {tab.label}
            </button>
          );
        })}
      </div>

      {activeTab === 'activity' && (
        <motion.div variants={containerVariants} initial="hidden" animate="visible" className="space-y-3">
          {activity.length === 0 ? (
            <div className="glass-card px-5 py-10 text-center">
              <MessageCircle className="mx-auto mb-3 h-8 w-8 text-white/25" />
              <p className="text-sm font-medium text-primary">No public activity yet</p>
              <p className="mt-1 text-xs text-secondary">Posts you share with the community will appear here.</p>
            </div>
          ) : (
            activity.slice(0, 12).map((raw: Record<string, unknown>, index: number) => (
              <motion.div key={String(raw.id ?? index)} variants={itemVariants} className="glass-card flex items-start gap-3 p-4">
                <div className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-lyo-500/15 text-lyo-300">
                  <MessageCircle size={16} />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="whitespace-pre-wrap text-sm text-primary">{String(raw.content ?? '')}</p>
                  <p className="mt-1 text-xs text-secondary">
                    {Number(raw.like_count ?? 0)} likes · {Number(raw.comment_count ?? 0)} comments
                  </p>
                </div>
                {raw.created_at ? (
                  <span className="shrink-0 text-[10px] text-secondary">{formatTimeAgo(String(raw.created_at))}</span>
                ) : null}
              </motion.div>
            ))
          )}
        </motion.div>
      )}

      {activeTab === 'achievements' && (
        <motion.div variants={containerVariants} initial="hidden" animate="visible" className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {achievements.length === 0 ? (
            <div className="glass-card col-span-full px-5 py-10 text-center">
              <Trophy className="mx-auto mb-3 h-8 w-8 text-white/25" />
              <p className="text-sm font-medium text-primary">No achievements yet</p>
              <p className="mt-1 text-xs text-secondary">Achievements will appear after they are awarded by LYO.</p>
            </div>
          ) : (
            achievements.map((raw: Record<string, unknown>, index: number) => {
              const unlocked = Boolean(raw.completed ?? raw.is_completed);
              return (
                <motion.div
                  key={String(raw.id ?? index)}
                  variants={itemVariants}
                  className={`glass-card flex flex-col items-center gap-2 p-4 text-center ${unlocked ? '' : 'opacity-50'}`}
                >
                  <div className={`grid h-14 w-14 place-items-center rounded-2xl text-2xl ${unlocked ? 'bg-lyo-500/20' : 'bg-white/[0.06]'}`}>
                    {unlocked ? String(raw.icon ?? '🏆') : <Lock size={20} className="text-white/30" />}
                  </div>
                  <p className="text-xs font-bold text-primary">{String(raw.name ?? raw.achievement_name ?? 'Achievement')}</p>
                  {raw.description ? <p className="text-[10px] leading-snug text-secondary">{String(raw.description)}</p> : null}
                  {raw.xp_reward != null ? <span className="text-[10px] font-semibold text-amber-400">+{Number(raw.xp_reward)} XP</span> : null}
                </motion.div>
              );
            })
          )}
        </motion.div>
      )}
    </motion.div>
  );
}
