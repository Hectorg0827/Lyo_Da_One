'use client';

import { motion } from 'framer-motion';
import { ArrowLeft, MessageCircle } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import ProfileHeader from '@/components/profile/ProfileHeader';
import { formatTimeAgo } from '@/lib/utils';

const itemVariants = {
  hidden: { opacity: 0, y: 16 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.35 } },
};

const containerVariants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { staggerChildren: 0.06 } },
};

export default function UserProfilePage({ params }: { params: { userId: string } }) {
  const router = useRouter();
  const { data: user, isLoading } = useApi(() => api.users.get(params.userId), [params.userId]);
  const { data: feedData } = useApi(() => api.users.posts(params.userId), [params.userId]);

  if (isLoading && !user) {
    return <div className="mx-auto max-w-3xl px-4 py-10 text-sm text-secondary">Loading profile…</div>;
  }

  if (!user) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-10">
        <button type="button" onClick={() => router.back()} className="mb-6 flex items-center gap-2 text-sm text-secondary hover:text-primary">
          <ArrowLeft size={16} /> Back
        </button>
        <div className="glass-card px-5 py-10 text-center">
          <p className="text-sm font-medium text-primary">This profile is unavailable.</p>
        </div>
      </div>
    );
  }

  const activity = feedData?.posts ?? [];

  return (
    <motion.div className="mx-auto max-w-3xl space-y-6 px-4 py-6 sm:px-6" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
      <button type="button" onClick={() => router.back()} className="flex items-center gap-2 text-sm text-secondary hover:text-primary">
        <ArrowLeft size={16} /> Back
      </button>

      <ProfileHeader
        user={user}
        isOwnProfile={false}
        onFollow={(next) => {
          const request = next ? api.users.follow(params.userId) : api.users.unfollow(params.userId);
          void request.catch(() => undefined);
        }}
      />

      <section>
        <h2 className="mb-3 text-sm font-bold text-primary">Recent activity</h2>
        <motion.div variants={containerVariants} initial="hidden" animate="visible" className="space-y-3">
          {activity.length === 0 ? (
            <div className="glass-card px-5 py-10 text-center">
              <MessageCircle className="mx-auto mb-3 h-8 w-8 text-white/25" />
              <p className="text-sm font-medium text-primary">No public activity yet</p>
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
                {raw.created_at ? <span className="shrink-0 text-[10px] text-secondary">{formatTimeAgo(String(raw.created_at))}</span> : null}
              </motion.div>
            ))
          )}
        </motion.div>
      </section>
    </motion.div>
  );
}
