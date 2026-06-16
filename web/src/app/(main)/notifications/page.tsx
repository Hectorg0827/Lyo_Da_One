'use client';

// TODO: wire to real notifications endpoint when available

import { useState, useEffect } from 'react';
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
} from 'lucide-react';
import { cn, formatTimeAgo, getInitials } from '@/lib/utils';
import type { AppNotification } from '@/types';

// ── Mock data (fallback until a real notifications endpoint exists) ───────────

const mockNotifications: AppNotification[] = [
  {
    id: '1',
    type: 'like',
    title: 'New likes',
    body: 'Maya Chen and 3 others liked your post about Machine Learning.',
    actor: {
      id: 'u2',
      displayName: 'Maya Chen',
      username: 'mayalearns',
      avatar: '',
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
    },
    targetId: 'post_1',
    targetType: 'post',
    isRead: false,
    createdAt: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
  },
  {
    id: '2',
    type: 'comment',
    title: 'New comment',
    body: 'Jordan Park commented: "Great breakdown! This really helped me understand backpropagation."',
    actor: {
      id: 'u3',
      displayName: 'Jordan Park',
      username: 'jparkdev',
      avatar: '',
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
      isPremium: true,
    },
    targetId: 'post_1',
    targetType: 'post',
    isRead: false,
    createdAt: new Date(Date.now() - 18 * 60 * 1000).toISOString(),
  },
  {
    id: '3',
    type: 'follow',
    title: 'New follower',
    body: 'Sofia Martinez started following you.',
    actor: {
      id: 'u4',
      displayName: 'Sofia Martinez',
      username: 'sofiadesigns',
      avatar: '',
      email: '',
      bio: '',
      role: 'creator',
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
    },
    isRead: false,
    createdAt: new Date(Date.now() - 45 * 60 * 1000).toISOString(),
  },
  {
    id: '4',
    type: 'achievement',
    title: 'Achievement unlocked!',
    body: 'You earned "Week Warrior" — 7-day learning streak. Keep it up!',
    isRead: false,
    createdAt: new Date(Date.now() - 2 * 3600 * 1000).toISOString(),
  },
  {
    id: '5',
    type: 'mention',
    title: 'You were mentioned',
    body: 'Alex Rivera mentioned you in a comment: "@you should check out this Python course!"',
    actor: {
      id: 'u5',
      displayName: 'Alex Rivera',
      username: 'alexrivera',
      avatar: '',
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
    },
    targetId: 'comment_5',
    targetType: 'comment',
    isRead: true,
    createdAt: new Date(Date.now() - 4 * 3600 * 1000).toISOString(),
  },
  {
    id: '6',
    type: 'like',
    title: 'New like',
    body: 'Sam Kim liked your clip "5 Python tips in 60 seconds".',
    actor: {
      id: 'u6',
      displayName: 'Sam Kim',
      username: 'samlearns',
      avatar: '',
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
    },
    isRead: true,
    createdAt: new Date(Date.now() - 6 * 3600 * 1000).toISOString(),
  },
  {
    id: '7',
    type: 'comment',
    title: 'New comment',
    body: 'Priya Sharma commented on your post: "This is exactly what I was looking for. Bookmarked!"',
    actor: {
      id: 'u7',
      displayName: 'Priya Sharma',
      username: 'priyalearns',
      avatar: '',
      email: '',
      bio: '',
      role: 'mentor',
      interests: [],
      learningGoals: [],
      streak: 0,
      xp: 0,
      level: 0,
      coursesCompleted: 0,
      followersCount: 0,
      followingCount: 0,
      createdAt: '',
      isPremium: true,
    },
    isRead: true,
    createdAt: new Date(Date.now() - 8 * 3600 * 1000).toISOString(),
  },
  {
    id: '8',
    type: 'group_invite',
    title: 'Group invitation',
    body: 'You were invited to join "AI Builders Community" by Priya Sharma.',
    actor: {
      id: 'u7',
      displayName: 'Priya Sharma',
      username: 'priyalearns',
      avatar: '',
      email: '',
      bio: '',
      role: 'mentor',
      interests: [],
      learningGoals: [],
      streak: 0,
      xp: 0,
      level: 0,
      coursesCompleted: 0,
      followersCount: 0,
      followingCount: 0,
      createdAt: '',
      isPremium: true,
    },
    isRead: true,
    createdAt: new Date(Date.now() - 10 * 3600 * 1000).toISOString(),
  },
  {
    id: '9',
    type: 'course_complete',
    title: 'Course completed!',
    body: 'Congratulations! You completed "UI/UX Design Principles". +500 XP earned.',
    isRead: true,
    createdAt: new Date(Date.now() - 24 * 3600 * 1000).toISOString(),
  },
  {
    id: '10',
    type: 'event_reminder',
    title: 'Event starting soon',
    body: '"Live Coding Session: React Hooks" starts in 30 minutes. Don\'t miss it!',
    isRead: true,
    createdAt: new Date(Date.now() - 26 * 3600 * 1000).toISOString(),
  },
  {
    id: '11',
    type: 'follow',
    title: 'New follower',
    body: 'Marcus Lee started following you.',
    actor: {
      id: 'u8',
      displayName: 'Marcus Lee',
      username: 'marcusbuilds',
      avatar: '',
      email: '',
      bio: '',
      role: 'creator',
      interests: [],
      learningGoals: [],
      streak: 0,
      xp: 0,
      level: 0,
      coursesCompleted: 0,
      followersCount: 0,
      followingCount: 0,
      createdAt: '',
      isPremium: true,
    },
    isRead: true,
    createdAt: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString(),
  },
  {
    id: '12',
    type: 'system',
    title: 'Weekly summary',
    body: 'You learned 14.5 hours this week — your best week yet! You rank #128 on the leaderboard.',
    isRead: true,
    createdAt: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString(),
  },
  {
    id: '13',
    type: 'mention',
    title: 'You were mentioned',
    body: 'Jordan Park mentioned you: "Check out @you\'s notes on neural networks — super clean!"',
    actor: {
      id: 'u3',
      displayName: 'Jordan Park',
      username: 'jparkdev',
      avatar: '',
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
      isPremium: true,
    },
    isRead: true,
    createdAt: new Date(Date.now() - 3 * 24 * 3600 * 1000).toISOString(),
  },
];

// ── Filter tabs ────────────────────────────────────────────────────────────────

const TABS = ['All', 'Mentions', 'Likes', 'Comments', 'System'] as const;
type Tab = typeof TABS[number];

function filterNotifications(notifications: AppNotification[], tab: Tab): AppNotification[] {
  switch (tab) {
    case 'Mentions': return notifications.filter((n) => n.type === 'mention');
    case 'Likes': return notifications.filter((n) => n.type === 'like');
    case 'Comments': return notifications.filter((n) => n.type === 'comment');
    case 'System': return notifications.filter((n) => ['system', 'achievement', 'course_complete', 'event_reminder'].includes(n.type));
    default: return notifications;
  }
}

// ── Notification icon ──────────────────────────────────────────────────────────

function NotifIcon({ type }: { type: AppNotification['type'] }) {
  const config: Record<string, { icon: React.ReactNode; color: string; bg: string }> = {
    like: { icon: <Heart size={14} fill="currentColor" />, color: '#ef4444', bg: 'rgba(239,68,68,0.15)' },
    comment: { icon: <MessageCircle size={14} />, color: '#6c63ff', bg: 'rgba(108,99,255,0.15)' },
    follow: { icon: <UserPlus size={14} />, color: '#22c55e', bg: 'rgba(34,197,94,0.15)' },
    achievement: { icon: <Trophy size={14} />, color: '#f59e0b', bg: 'rgba(245,158,11,0.15)' },
    course_complete: { icon: <Trophy size={14} />, color: '#f59e0b', bg: 'rgba(245,158,11,0.15)' },
    mention: { icon: <AtSign size={14} />, color: '#3b82f6', bg: 'rgba(59,130,246,0.15)' },
    group_invite: { icon: <Users size={14} />, color: '#a78bfa', bg: 'rgba(167,139,250,0.15)' },
    event_reminder: { icon: <CalendarClock size={14} />, color: '#ec4899', bg: 'rgba(236,72,153,0.15)' },
    system: { icon: <Bell size={14} />, color: '#8888aa', bg: 'rgba(136,136,170,0.12)' },
  };
  const c = config[type] ?? config.system;
  return (
    <div
      className="w-7 h-7 rounded-full flex items-center justify-center shrink-0"
      style={{ color: c.color, background: c.bg }}
    >
      {c.icon}
    </div>
  );
}

// ── Avatar ─────────────────────────────────────────────────────────────────────

const AVATAR_COLORS = ['#6c63ff', '#22c55e', '#ec4899', '#f59e0b', '#3b82f6', '#a78bfa'];

function ActorAvatar({ actor }: { actor: AppNotification['actor'] }) {
  if (!actor) {
    return (
      <div
        className="w-10 h-10 rounded-full flex items-center justify-center shrink-0 font-bold text-white text-xs"
        style={{ background: 'linear-gradient(135deg, #6c63ff, #8b5cf6)' }}
      >
        LYO
      </div>
    );
  }
  const colorIdx = actor.id.charCodeAt(actor.id.length - 1) % AVATAR_COLORS.length;
  return (
    <div
      className="w-10 h-10 rounded-full flex items-center justify-center shrink-0 font-bold text-white text-xs select-none"
      style={{ backgroundColor: AVATAR_COLORS[colorIdx] }}
    >
      {getInitials(actor.displayName)}
    </div>
  );
}

// ── Notification item ──────────────────────────────────────────────────────────

function NotifItem({ notif }: { notif: AppNotification }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      className={cn(
        'flex items-start gap-3 px-4 py-4 cursor-pointer transition-colors duration-150 hover:bg-white/[0.03] relative',
        !notif.isRead && 'bg-[#6c63ff]/[0.04]'
      )}
    >
      {/* Unread indicator */}
      {!notif.isRead && (
        <div
          className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 rounded-r-full"
          style={{ background: '#6c63ff' }}
        />
      )}

      {/* Actor avatar */}
      <div className="relative shrink-0">
        <ActorAvatar actor={notif.actor} />
        <div className="absolute -bottom-1 -right-1">
          <NotifIcon type={notif.type} />
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 space-y-0.5">
        <p className={cn('text-sm leading-relaxed', !notif.isRead ? 'text-primary font-medium' : 'text-secondary')}>
          {notif.body}
        </p>
        <p className="text-[11px] text-secondary">{formatTimeAgo(notif.createdAt)}</p>
      </div>
    </motion.div>
  );
}

// ── Main Page ──────────────────────────────────────────────────────────────────

export default function NotificationsPage() {
  const [activeTab, setActiveTab] = useState<Tab>('All');
  const [notifications, setNotifications] = useState(mockNotifications);

  // TODO: wire to real notifications endpoint when available
  // Attempt to enrich notifications from available endpoints (e.g. gamification achievements)
  useEffect(() => {
    let cancelled = false;

    async function fetchNotificationSources() {
      try {
        // Try to fetch recent achievements to generate achievement notifications
        const { api } = await import('@/lib/api');
        const achievements = await api.gamification.achievements(true);
        if (cancelled || !Array.isArray(achievements)) return;

        const achievementNotifs: AppNotification[] = achievements
          .filter((a: Record<string, unknown>) => a.completed_at || a.unlocked_at)
          .slice(0, 3)
          .map((a: Record<string, unknown>, i: number) => ({
            id: `api_achievement_${i}`,
            type: 'achievement' as const,
            title: 'Achievement unlocked!',
            body: `You earned "${String(a.title ?? a.name ?? 'Achievement')}"${a.xp_reward ? ` — +${a.xp_reward} XP` : ''}`,
            isRead: true,
            createdAt: String(a.completed_at ?? a.unlocked_at ?? new Date().toISOString()),
          }));

        if (achievementNotifs.length > 0) {
          setNotifications((prev) => {
            // Merge API achievement notifications with mock data, avoiding duplicates
            const existingIds = new Set(prev.map((n) => n.id));
            const newNotifs = achievementNotifs.filter((n) => !existingIds.has(n.id));
            if (newNotifs.length === 0) return prev;
            return [...prev, ...newNotifs].sort(
              (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
            );
          });
        }
      } catch {
        // Silently fall back to mock data if API is unavailable
      }
    }

    fetchNotificationSources();
    return () => { cancelled = true; };
  }, []);

  const filtered = filterNotifications(notifications, activeTab);
  const unreadCount = notifications.filter((n) => !n.isRead).length;

  function markAllRead() {
    setNotifications((prev) => prev.map((n) => ({ ...n, isRead: true })));
  }

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-black text-primary">Notifications</h1>
          {unreadCount > 0 && (
            <p className="text-xs text-secondary mt-0.5">{unreadCount} unread</p>
          )}
        </div>
        {unreadCount > 0 && (
          <button
            onClick={markAllRead}
            className="flex items-center gap-1.5 text-xs font-semibold text-secondary hover:text-[#8b83ff] transition-colors duration-150"
          >
            <CheckCheck size={14} />
            Mark all read
          </button>
        )}
      </div>

      {/* Filter tabs */}
      <div className="flex gap-1 p-1 rounded-xl" style={{ background: 'rgba(255,255,255,0.04)' }}>
        {TABS.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={cn(
              'flex-1 text-xs font-semibold py-2 px-2 rounded-lg transition-all duration-200',
              activeTab === tab
                ? 'text-white shadow-sm'
                : 'text-secondary hover:text-primary'
            )}
            style={
              activeTab === tab
                ? { background: 'linear-gradient(135deg, #6c63ff, #8b5cf6)' }
                : {}
            }
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Notification list */}
      <div
        className="rounded-2xl overflow-hidden divide-y"
        style={{
          background: 'rgba(17,17,24,0.6)',
          backdropFilter: 'blur(12px)',
          border: '1px solid rgba(255,255,255,0.07)',
        }}
      >
        <AnimatePresence mode="popLayout">
          {filtered.length > 0 ? (
            filtered.map((notif) => (
              <div key={notif.id} style={{ borderColor: 'rgba(255,255,255,0.05)', borderBottomWidth: 1 }}>
                <NotifItem notif={notif} />
              </div>
            ))
          ) : (
            <motion.div
              key="empty"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex flex-col items-center justify-center py-20 gap-3"
            >
              <div
                className="w-16 h-16 rounded-2xl flex items-center justify-center"
                style={{ background: 'rgba(255,255,255,0.05)' }}
              >
                <Bell size={28} className="text-secondary" />
              </div>
              <p className="text-base font-semibold text-primary">No notifications</p>
              <p className="text-sm text-secondary">
                {activeTab === 'All' ? "You're all caught up!" : `No ${activeTab.toLowerCase()} yet.`}
              </p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
