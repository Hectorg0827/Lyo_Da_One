'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { MessageCircle } from 'lucide-react';
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

export default function UserProfilePage({ params }: { params: { userId: string } }) {
  const { data: user, isLoading } = useApi(() => api.users.get(params.userId), [params.userId]);
  const { data: feedData } = useApi(() => api.users.posts(params.userId), [params.userId]);
  const [isFollowing, setIsFollowing] = useState(false);

  useEffect(() => {
    setIsFollowing(Boolean(user?.isFollowing));
  }, [user?.isFollowing]);

  const handleFollow = () => {
    if (!user) return;
    const next = !isFollowing;
    setIsFollowing(next);
    const request = next ? api.users.follow(params.userId) : api.users.unfollow(params.userId);
    request.catch(() => setIsFollowing(!next));
  };

  if (isLoading) {
    return <div className="mx-auto max-w-3xl px-6 py-16 text-center text-sm text-white/50">Loading profile…</div>;
  }

  if (!user) {
    return <div className="mx-auto max-w-3xl px-6 py-16 text-center text-sm text-white/50">Profile unavailable.</div>;
  }

  const activity: ActivityItem[] = feedData?.posts
    ? feedData.posts.slice(0, 12).map((post: Record<string, unknown>, index: number) => ({
        id: String(post.id ?? index),
        text: String(post.content ?? ''),
        sub: `${Number(post.like_count) || 0} likes · ${Number(post.comment_count) || 0} comments`,
        time: (post.created_at as string) || new Date().toISOString(),
      }))
    : [];

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="mx-auto max-w-3xl space-y-6 px-4 py-6 sm:px-6"
    >
      <ProfileHeader
        user={user}
        isOwnProfile={false}
        isFollowing={isFollowing}
        onFollow={handleFollow}
      />

      <section>
        <div className="mb-3 flex items-center gap-2">
          <MessageCircle size={16} className="text-violet-300" />
          <h2 className="text-sm font-bold text-primary">Activity</h2>
        </div>

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
              <p className="text-sm font-medium text-white/70">No public activity yet</p>
            </div>
          )}
        </div>
      </section>
    </motion.div>
  );
}
