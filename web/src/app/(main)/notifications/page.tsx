'use client';

import { useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Heart,
  MessageCircle,
  UserPlus,
  Trophy,
  Bell,
  AtSign,
  Users,
  CalendarClock,
  CheckCheck,
  Loader2,
  RefreshCw,
  AlertTriangle,
} from 'lucide-react';
import { cn, formatTimeAgo, getInitials } from '@/lib/utils';
import { useApi } from '@/hooks/use-api';
import { useSyncEvents } from '@/hooks/use-sync';
import { api } from '@/lib/api';
import type { AppNotification, User } from '@/types';

const TABS = ['All', 'Mentions', 'Likes', 'Comments', 'System'] as const;
type Tab = (typeof TABS)[number];

function filterNotifications(notifications: AppNotification[], tab: Tab): AppNotification[] {
  switch (tab) {
    case 'Mentions':
      return notifications.filter((notification) => notification.type === 'mention');
    case 'Likes':
      return notifications.filter((notification) => notification.type === 'like');
    case 'Comments':
      return notifications.filter((notification) => notification.type === 'comment');
    case 'System':
      return notifications.filter((notification) =>
        ['system', 'achievement', 'course_complete', 'event_reminder'].includes(notification.type),
      );
    default:
      return notifications;
  }
}

function NotifIcon({ type }: { type: AppNotification['type'] }) {
  const config: Record<string, { icon: ReactNode; color: string; bg: string }> = {
    like: {
      icon: <Heart size={14} fill="currentColor" />,
      color: '#ef4444',
      bg: 'rgba(239,68,68,0.15)',
    },
    comment: {
      icon: <MessageCircle size={14} />,
      color: '#6c63ff',
      bg: 'rgba(108,99,255,0.15)',
    },
    follow: {
      icon: <UserPlus size={14} />,
      color: '#22c55e',
      bg: 'rgba(34,197,94,0.15)',
    },
    achievement: {
      icon: <Trophy size={14} />,
      color: '#f59e0b',
      bg: 'rgba(245,158,11,0.15)',
    },
    course_complete: {
      icon: <Trophy size={14} />,
      color: '#f59e0b',
      bg: 'rgba(245,158,11,0.15)',
    },
    mention: {
      icon: <AtSign size={14} />,
      color: '#3b82f6',
      bg: 'rgba(59,130,246,0.15)',
    },
    group_invite: {
      icon: <Users size={14} />,
      color: '#a78bfa',
      bg: 'rgba(167,139,250,0.15)',
    },
    event_reminder: {
      icon: <CalendarClock size={14} />,
      color: '#ec4899',
      bg: 'rgba(236,72,153,0.15)',
    },
    system: {
      icon: <Bell size={14} />,
      color: '#8888aa',
      bg: 'rgba(136,136,170,0.12)',
    },
  };
  const selected = config[type] ?? config.system;

  return (
    <div
      className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full"
      style={{ color: selected.color, background: selected.bg }}
    >
      {selected.icon}
    </div>
  );
}

const AVATAR_COLORS = ['#6c63ff', '#22c55e', '#ec4899', '#f59e0b', '#3b82f6', '#a78bfa'];

function ActorAvatar({ actor }: { actor: AppNotification['actor'] }) {
  if (!actor) {
    return (
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-[#6c63ff] to-[#8b5cf6] text-xs font-bold text-white">
        LYO
      </div>
    );
  }

  if (actor.avatar) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={actor.avatar} alt="" className="h-10 w-10 shrink-0 rounded-full object-cover" />;
  }

  const finalCharacter = actor.id.charCodeAt(Math.max(actor.id.length - 1, 0));
  const backgroundColor = AVATAR_COLORS[finalCharacter % AVATAR_COLORS.length];
  return (
    <div
      className="flex h-10 w-10 shrink-0 select-none items-center justify-center rounded-full text-xs font-bold text-white"
      style={{ backgroundColor }}
    >
      {getInitials(actor.displayName)}
    </div>
  );
}

function notificationHref(notification: AppNotification): string | null {
  const targetId = notification.targetId;
  const targetType = notification.targetType?.toLowerCase();

  if (notification.type === 'follow' && notification.actor?.id) {
    return `/profile/${notification.actor.id}`;
  }
  if (!targetId) return null;

  switch (targetType) {
    case 'post':
    case 'comment':
      return `/community/${targetId}`;
    case 'course':
    case 'lesson':
      return `/courses/${targetId}`;
    case 'clip':
    case 'reel':
      return `/clips?clip=${encodeURIComponent(targetId)}`;
    case 'profile':
    case 'user':
      return `/profile/${targetId}`;
    case 'conversation':
    case 'message':
      return `/messages?conversation=${encodeURIComponent(targetId)}`;
    case 'group':
      return `/community?group=${encodeURIComponent(targetId)}`;
    case 'event':
      return `/community?event=${encodeURIComponent(targetId)}`;
    default:
      return null;
  }
}

function NotifItem({
  notification,
  onOpen,
}: {
  notification: AppNotification;
  onOpen: (notification: AppNotification) => void;
}) {
  return (
    <motion.button
      type="button"
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      onClick={() => onOpen(notification)}
      className={cn(
        'relative flex w-full cursor-pointer items-start gap-3 px-4 py-4 text-left transition-colors duration-150 hover:bg-white/[0.03]',
        !notification.isRead && 'bg-[#6c63ff]/[0.04]',
      )}
    >
      {!notification.isRead && (
        <div className="absolute left-0 top-1/2 h-8 w-1 -translate-y-1/2 rounded-r-full bg-[#6c63ff]" />
      )}

      <div className="relative shrink-0">
        <ActorAvatar actor={notification.actor} />
        <div className="absolute -bottom-1 -right-1">
          <NotifIcon type={notification.type} />
        </div>
      </div>

      <div className="min-w-0 flex-1 space-y-0.5">
        {notification.title && (
          <p className={cn('text-sm', !notification.isRead ? 'font-semibold text-primary' : 'font-medium text-secondary')}>
            {notification.title}
          </p>
        )}
        <p className={cn('text-sm leading-relaxed', !notification.isRead ? 'text-primary' : 'text-secondary')}>
          {notification.body}
        </p>
        <p className="text-[11px] text-secondary">{formatTimeAgo(notification.createdAt)}</p>
      </div>
    </motion.button>
  );
}

function mapApiNotification(raw: Record<string, unknown>): AppNotification {
  const actorId = raw.actor_id ?? raw.actorId;
  const actor: User | undefined = actorId
    ? {
        id: String(actorId),
        displayName:
          (raw.actor_display_name as string) ||
          (raw.actorDisplayName as string) ||
          (raw.actor_name as string) ||
          'Member',
        username: (raw.actor_username as string) || (raw.actorUsername as string) || '',
        avatar: (raw.actor_avatar_url as string) || (raw.actorAvatarUrl as string) || '',
        email: '',
        bio: '',
        role: 'student',
        interests: [],
        learningGoals: [],
        streak: 0,
        xp: 0,
        level: 0,
        coursesCompleted: 0,
        followersCount: 0,
        followingCount: 0,
        createdAt: '',
        isPremium: false,
      }
    : undefined;

  return {
    id: String(raw.id ?? ''),
    type: (raw.type as AppNotification['type']) || 'system',
    title: (raw.title as string) || '',
    body: (raw.body as string) || '',
    actor,
    targetId: String(raw.target_id ?? raw.targetId ?? '') || undefined,
    targetType: (raw.target_type as string) || (raw.targetType as string) || undefined,
    isRead: Boolean(raw.is_read ?? raw.isRead ?? true),
    createdAt: (raw.created_at as string) || (raw.createdAt as string) || new Date().toISOString(),
  };
}

export default function NotificationsPage() {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<Tab>('All');
  const [actionError, setActionError] = useState<string | null>(null);
  const [markingAll, setMarkingAll] = useState(false);
  const { data: notificationData, isLoading, error, refetch } = useApi(
    () => api.notifications.list(1, 50),
    [],
  );

  useSyncEvents(() => refetch(), ['context_updated', 'message_received']);

  const notifications = (notificationData?.notifications ?? []).map(mapApiNotification);
  const filtered = filterNotifications(notifications, activeTab);
  const unreadCount = notificationData?.unread_count ?? notifications.filter((notification) => !notification.isRead).length;

  async function openNotification(notification: AppNotification) {
    setActionError(null);
    if (!notification.isRead) {
      try {
        await api.notifications.markRead(notification.id);
        refetch();
      } catch (reason) {
        setActionError(reason instanceof Error ? reason.message : 'Unable to mark the notification as read.');
      }
    }

    const href = notificationHref(notification);
    if (href) router.push(href);
  }

  async function markAllRead() {
    if (markingAll) return;
    setMarkingAll(true);
    setActionError(null);
    try {
      await api.notifications.markAllRead();
      refetch();
    } catch (reason) {
      setActionError(reason instanceof Error ? reason.message : 'Unable to mark notifications as read.');
    } finally {
      setMarkingAll(false);
    }
  }

  return (
    <div className="mx-auto max-w-2xl space-y-5 px-4 py-6 sm:px-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-black text-primary">Notifications</h1>
          {unreadCount > 0 && <p className="mt-0.5 text-xs text-secondary">{unreadCount} unread</p>}
        </div>
        {unreadCount > 0 && !isLoading && (
          <button
            type="button"
            onClick={markAllRead}
            disabled={markingAll}
            className="flex items-center gap-1.5 text-xs font-semibold text-secondary transition-colors duration-150 hover:text-[#8b83ff] disabled:opacity-50"
          >
            {markingAll ? <Loader2 size={14} className="animate-spin" /> : <CheckCheck size={14} />}
            Mark all read
          </button>
        )}
      </div>

      <div className="flex gap-1 rounded-xl bg-white/[0.04] p-1">
        {TABS.map((tab) => (
          <button
            type="button"
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={cn(
              'flex-1 rounded-lg px-2 py-2 text-xs font-semibold transition-all duration-200',
              activeTab === tab ? 'text-white shadow-sm' : 'text-secondary hover:text-primary',
            )}
            style={activeTab === tab ? { background: 'linear-gradient(135deg, #6c63ff, #8b5cf6)' } : {}}
          >
            {tab}
          </button>
        ))}
      </div>

      {(error || actionError) && (
        <div role="alert" className="flex items-start gap-3 rounded-xl border border-red-400/20 bg-red-400/10 p-4 text-sm text-red-200">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <div className="min-w-0 flex-1">
            <p>{actionError || error}</p>
            {error && (
              <button type="button" onClick={refetch} className="mt-2 inline-flex items-center gap-1 font-semibold text-red-100 hover:text-white">
                <RefreshCw className="h-3.5 w-3.5" />
                Try again
              </button>
            )}
          </div>
        </div>
      )}

      <div className="divide-y overflow-hidden rounded-2xl border border-white/[0.07] bg-[#111118]/60 backdrop-blur-xl">
        {isLoading ? (
          <div className="flex items-center justify-center gap-2 py-20 text-sm text-secondary">
            <Loader2 className="h-5 w-5 animate-spin" />
            Loading notifications…
          </div>
        ) : (
          <AnimatePresence mode="popLayout">
            {filtered.length > 0 ? (
              filtered.map((notification) => (
                <div key={notification.id} className="border-b border-white/[0.05] last:border-0">
                  <NotifItem notification={notification} onOpen={openNotification} />
                </div>
              ))
            ) : (
              <motion.div
                key="empty"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="flex flex-col items-center justify-center gap-3 py-20"
              >
                <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-white/[0.05]">
                  <Bell size={28} className="text-secondary" />
                </div>
                <p className="text-base font-semibold text-primary">No notifications</p>
                <p className="text-sm text-secondary">
                  {activeTab === 'All' ? "You're all caught up." : `No ${activeTab.toLowerCase()} yet.`}
                </p>
              </motion.div>
            )}
          </AnimatePresence>
        )}
      </div>
    </div>
  );
}
