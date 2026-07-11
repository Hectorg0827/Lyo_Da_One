'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, Send, MessageSquare, Phone, Video, MoreHorizontal, ArrowLeft } from 'lucide-react';
import { cn, getInitials, formatTimeAgo } from '@/lib/utils';
import { useAuthStore } from '@/stores/auth-store';
import { useApi } from '@/hooks/use-api';
import { useSyncEvents } from '@/hooks/use-sync';
import { api } from '@/lib/api';
import type { Conversation, DirectMessage, User } from '@/types';

// ── Mock data (local-only until backend DM endpoints are added) ─────────────

const CURRENT_USER_ID = 'user_1';

const AVATAR_COLORS = ['#6c63ff', '#22c55e', '#ec4899', '#f59e0b', '#3b82f6'];

function avatarColor(id: string) {
  return AVATAR_COLORS[id.charCodeAt(id.length - 1) % AVATAR_COLORS.length];
}

const mockParticipants = {
  u2: { id: 'u2', displayName: 'Maya Chen', username: 'mayalearns', avatar: '', email: '', bio: '', role: 'student' as const, interests: [], learningGoals: [], streak: 5, xp: 1200, level: 8, coursesCompleted: 7, followersCount: 210, followingCount: 90, createdAt: '', isPremium: false },
  u3: { id: 'u3', displayName: 'Jordan Park', username: 'jparkdev', avatar: '', email: '', bio: '', role: 'student' as const, interests: [], learningGoals: [], streak: 30, xp: 5400, level: 18, coursesCompleted: 15, followersCount: 890, followingCount: 200, createdAt: '', isPremium: true },
  u7: { id: 'u7', displayName: 'Priya Sharma', username: 'priyalearns', avatar: '', email: '', bio: '', role: 'mentor' as const, interests: [], learningGoals: [], streak: 45, xp: 12000, level: 32, coursesCompleted: 60, followersCount: 4200, followingCount: 180, createdAt: '', isPremium: true },
  u8: { id: 'u8', displayName: 'Marcus Lee', username: 'marcusbuilds', avatar: '', email: '', bio: '', role: 'creator' as const, interests: [], learningGoals: [], streak: 20, xp: 7800, level: 22, coursesCompleted: 31, followersCount: 2100, followingCount: 400, createdAt: '', isPremium: true },
};

type MockMessages = Record<string, DirectMessage[]>;

const mockMessages: MockMessages = {
  conv_1: [
    { id: 'm1', senderId: 'u2', content: 'Hey! Did you check out the new ML course that was added?', type: 'text', isRead: true, createdAt: new Date(Date.now() - 3 * 3600 * 1000).toISOString() },
    { id: 'm2', senderId: CURRENT_USER_ID, content: 'Yeah! The one on transformers? It looks really good. I started the first module.', type: 'text', isRead: true, createdAt: new Date(Date.now() - 2.9 * 3600 * 1000).toISOString() },
    { id: 'm3', senderId: 'u2', content: 'Exactly that one. The explanations are so clear. Way better than the Stanford lecture imo 😅', type: 'text', isRead: true, createdAt: new Date(Date.now() - 2.8 * 3600 * 1000).toISOString() },
    { id: 'm4', senderId: CURRENT_USER_ID, content: 'I know right. The animations really help with the attention mechanism. How far are you?', type: 'text', isRead: true, createdAt: new Date(Date.now() - 2.5 * 3600 * 1000).toISOString() },
    { id: 'm5', senderId: 'u2', content: 'About 35% in. Let\'s study together sometime?', type: 'text', isRead: false, createdAt: new Date(Date.now() - 20 * 60 * 1000).toISOString() },
    { id: 'm6', senderId: 'u2', content: 'We could do a shared notes session on LYO!', type: 'text', isRead: false, createdAt: new Date(Date.now() - 18 * 60 * 1000).toISOString() },
  ],
  conv_2: [
    { id: 'm7', senderId: 'u3', content: 'Congrats on the 30-day streak! That\'s huge 🔥', type: 'text', isRead: true, createdAt: new Date(Date.now() - 5 * 3600 * 1000).toISOString() },
    { id: 'm8', senderId: CURRENT_USER_ID, content: 'Thanks Jordan! Saw your post about it. You\'re an inspiration honestly', type: 'text', isRead: true, createdAt: new Date(Date.now() - 4.8 * 3600 * 1000).toISOString() },
    { id: 'm9', senderId: 'u3', content: 'Keep going! The key is making it a daily ritual. 15 min minimum every day.', type: 'text', isRead: true, createdAt: new Date(Date.now() - 4.6 * 3600 * 1000).toISOString() },
    { id: 'm10', senderId: CURRENT_USER_ID, content: 'That\'s great advice. I\'ve been doing that with the daily challenges.', type: 'text', isRead: true, createdAt: new Date(Date.now() - 4.4 * 3600 * 1000).toISOString() },
    { id: 'm11', senderId: 'u3', content: 'Perfect strategy. DM me when you hit 30 days — we should celebrate 🎉', type: 'text', isRead: true, createdAt: new Date(Date.now() - 4 * 3600 * 1000).toISOString() },
  ],
  conv_3: [
    { id: 'm12', senderId: 'u7', content: 'Hi! I saw your note on gradient descent. Very well explained for a beginner\'s perspective.', type: 'text', isRead: true, createdAt: new Date(Date.now() - 24 * 3600 * 1000).toISOString() },
    { id: 'm13', senderId: CURRENT_USER_ID, content: 'Thank you so much Priya! That really means a lot coming from you.', type: 'text', isRead: true, createdAt: new Date(Date.now() - 23.5 * 3600 * 1000).toISOString() },
    { id: 'm14', senderId: 'u7', content: 'Would you be interested in contributing to my upcoming course on ML foundations?', type: 'text', isRead: true, createdAt: new Date(Date.now() - 23 * 3600 * 1000).toISOString() },
    { id: 'm15', senderId: CURRENT_USER_ID, content: 'Absolutely! I\'d be honored. What would you need from me?', type: 'text', isRead: true, createdAt: new Date(Date.now() - 22.5 * 3600 * 1000).toISOString() },
    { id: 'm16', senderId: 'u7', content: 'Some example walkthroughs from a learner\'s POV. Let\'s schedule a call this week?', type: 'text', isRead: true, createdAt: new Date(Date.now() - 22 * 3600 * 1000).toISOString() },
    { id: 'm17', senderId: CURRENT_USER_ID, content: 'Definitely! How about Thursday at 3pm?', type: 'text', isRead: true, createdAt: new Date(Date.now() - 21 * 3600 * 1000).toISOString() },
    { id: 'm18', senderId: 'u7', content: 'Perfect. I\'ll send a calendar invite. Looking forward to it!', type: 'text', isRead: true, createdAt: new Date(Date.now() - 20 * 3600 * 1000).toISOString() },
  ],
  conv_4: [
    { id: 'm19', senderId: 'u8', content: 'Hey, loving your posts on LYO! Really solid content.', type: 'text', isRead: true, createdAt: new Date(Date.now() - 3 * 24 * 3600 * 1000).toISOString() },
    { id: 'm20', senderId: CURRENT_USER_ID, content: 'Thanks Marcus! I\'ve been following your clips — the React hooks one was fire 🔥', type: 'text', isRead: true, createdAt: new Date(Date.now() - 2.9 * 24 * 3600 * 1000).toISOString() },
    { id: 'm21', senderId: 'u8', content: 'Thanks! Working on a Next.js series now. Want to collab on a clip?', type: 'text', isRead: true, createdAt: new Date(Date.now() - 2.8 * 24 * 3600 * 1000).toISOString() },
    { id: 'm22', senderId: CURRENT_USER_ID, content: 'That sounds awesome! What topic are you thinking?', type: 'text', isRead: true, createdAt: new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString() },
    { id: 'm23', senderId: 'u8', content: 'Server components explained in under 60 seconds. You explain the "why", I\'ll do the code demo.', type: 'text', isRead: true, createdAt: new Date(Date.now() - 2 * 24 * 3600 * 1000 + 3600 * 1000).toISOString() },
  ],
};

const mockConversations: Conversation[] = [
  {
    id: 'conv_1',
    participants: [mockParticipants.u2 as Conversation['participants'][0]],
    lastMessage: mockMessages.conv_1[mockMessages.conv_1.length - 1],
    unreadCount: 2,
    updatedAt: mockMessages.conv_1[mockMessages.conv_1.length - 1].createdAt,
  },
  {
    id: 'conv_2',
    participants: [mockParticipants.u3 as Conversation['participants'][0]],
    lastMessage: mockMessages.conv_2[mockMessages.conv_2.length - 1],
    unreadCount: 0,
    updatedAt: mockMessages.conv_2[mockMessages.conv_2.length - 1].createdAt,
  },
  {
    id: 'conv_3',
    participants: [mockParticipants.u7 as Conversation['participants'][0]],
    lastMessage: mockMessages.conv_3[mockMessages.conv_3.length - 1],
    unreadCount: 0,
    updatedAt: mockMessages.conv_3[mockMessages.conv_3.length - 1].createdAt,
  },
  {
    id: 'conv_4',
    participants: [mockParticipants.u8 as Conversation['participants'][0]],
    lastMessage: mockMessages.conv_4[mockMessages.conv_4.length - 1],
    unreadCount: 0,
    updatedAt: mockMessages.conv_4[mockMessages.conv_4.length - 1].createdAt,
  },
];

// ── Conversation list item ─────────────────────────────────────────────────────

function ConvItem({
  conv,
  isActive,
  onClick,
}: {
  conv: Conversation;
  isActive: boolean;
  onClick: () => void;
}) {
  const other = conv.participants[0];
  return (
    <button
      onClick={onClick}
      className={cn(
        'w-full flex items-center gap-3 px-4 py-3 text-left transition-all duration-150 hover:bg-white/[0.04]',
        isActive && 'bg-[#6c63ff]/10'
      )}
    >
      <div
        className="w-11 h-11 rounded-full flex items-center justify-center shrink-0 font-bold text-white text-sm select-none"
        style={{ backgroundColor: avatarColor(other.id) }}
      >
        {getInitials(other.displayName)}
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-1">
          <span className={cn('text-sm font-semibold truncate', isActive ? 'text-primary' : 'text-primary')}>
            {other.displayName}
          </span>
          <span className="text-[10px] text-secondary shrink-0">
            {formatTimeAgo(conv.updatedAt)}
          </span>
        </div>
        <div className="flex items-center justify-between gap-1 mt-0.5">
          <p className="text-xs text-secondary truncate">{conv.lastMessage.content}</p>
          {conv.unreadCount > 0 && (
            <span
              className="text-[10px] font-bold text-white px-1.5 py-0.5 rounded-full shrink-0"
              style={{ background: '#6c63ff', minWidth: 18, textAlign: 'center' }}
            >
              {conv.unreadCount}
            </span>
          )}
        </div>
      </div>
    </button>
  );
}

// ── Message bubble ─────────────────────────────────────────────────────────────

function MsgBubble({ msg, isOwn }: { msg: DirectMessage; isOwn: boolean }) {
  return (
    <div className={cn('flex', isOwn ? 'justify-end' : 'justify-start')}>
      <div
        className={cn(
          'max-w-[72%] px-4 py-2.5 rounded-2xl text-sm leading-relaxed',
          isOwn
            ? 'rounded-br-sm text-white'
            : 'rounded-bl-sm text-primary'
        )}
        style={
          isOwn
            ? { background: 'linear-gradient(135deg, #6c63ff, #8b5cf6)' }
            : { background: 'rgba(255,255,255,0.07)', border: '1px solid rgba(255,255,255,0.08)' }
        }
      >
        {msg.content}
        <p className={cn('text-[10px] mt-1', isOwn ? 'text-white/60 text-right' : 'text-secondary')}>
          {formatTimeAgo(msg.createdAt)}
        </p>
      </div>
    </div>
  );
}

// ── Main Page ──────────────────────────────────────────────────────────────────

export default function MessagesPage() {
  const { user } = useAuthStore();
  const [activeConvId, setActiveConvId] = useState<string | null>(null);
  const [inputText, setInputText] = useState('');
  const [search, setSearch] = useState('');
  const [localMessages, setLocalMessages] = useState<MockMessages>(mockMessages);
  const bottomRef = useRef<HTMLDivElement>(null);

  // ── API data fetching ──────────────────────────────────────────────────
  const { data: convData, refetch: refetchConvs } = useApi(() => api.messages.conversations(), []);
  const { data: msgData, refetch: refetchMsgs } = useApi(
    activeConvId ? () => api.messages.getMessages(activeConvId) : null,
    [activeConvId]
  );

  // Live cross-device sync: when this account sends/receives a message on
  // another device (iOS/Android/another tab), refresh without a manual reload.
  useSyncEvents(() => {
    refetchConvs();
    refetchMsgs();
  }, ['message_sent', 'message_received', 'context_updated']);

  // Map API conversations to the frontend Conversation type
  const apiConversations: Conversation[] | null = convData?.conversations
    ? convData.conversations.map((conv) => {
        const participants = ((conv.participants as Record<string, unknown>[]) || []).map(
          (p): User => ({
            id: String(p.id ?? ''),
            email: '',
            displayName: (p.display_name as string) || (p.username as string) || 'User',
            username: (p.username as string) || '',
            avatar: (p.avatar_url as string) || '',
            bio: '',
            role: 'student',
            interests: [],
            learningGoals: [],
            streak: 0,
            xp: 0,
            level: 1,
            coursesCompleted: 0,
            followersCount: 0,
            followingCount: 0,
            createdAt: '',
            isPremium: false,
          })
        );
        const lm = conv.last_message as Record<string, unknown> | null;
        const lastMessage: DirectMessage = lm
          ? {
              id: String(lm.id ?? ''),
              senderId: String(lm.sender_id ?? ''),
              content: (lm.content as string) || '',
              type: ((lm.message_type as string) || 'text') as DirectMessage['type'],
              mediaUrl: (lm.media_url as string) || undefined,
              isRead: true,
              createdAt: (lm.created_at as string) || '',
            }
          : { id: '', senderId: '', content: '', type: 'text', isRead: true, createdAt: '' };
        return {
          id: String(conv.id ?? ''),
          participants,
          lastMessage,
          unreadCount: (conv.unread_count as number) || 0,
          updatedAt: (conv.updated_at as string) || '',
        };
      })
    : null;

  // Map API messages to the frontend DirectMessage type
  const apiMessages: DirectMessage[] | null = msgData?.messages
    ? (msgData.messages as Record<string, unknown>[]).map(
        (m): DirectMessage => ({
          id: String(m.id ?? ''),
          senderId: String(m.sender_id ?? ''),
          content: (m.content as string) || '',
          type: ((m.message_type as string) || 'text') as DirectMessage['type'],
          mediaUrl: (m.media_url as string) || undefined,
          isRead: true,
          createdAt: (m.created_at as string) || '',
        })
      )
    : null;

  // Use API data when available, fall back to mock data
  const conversations = apiConversations ?? mockConversations;
  const activeConv = conversations.find((c) => c.id === activeConvId) ?? null;
  const activeOther = activeConv?.participants[0] ?? null;
  const activeMessages = activeConvId
    ? apiMessages ?? localMessages[activeConvId] ?? []
    : [];

  const filteredConvs = conversations.filter((c) =>
    c.participants[0]?.displayName.toLowerCase().includes(search.toLowerCase())
  );

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [activeMessages.length]);

  // Mark conversation as read when opened
  useEffect(() => {
    if (activeConvId && apiConversations) {
      api.messages.markRead(activeConvId).catch(() => {});
    }
  }, [activeConvId, apiConversations]);

  const sendMessage = useCallback(async () => {
    if (!inputText.trim() || !activeConvId) return;
    const text = inputText.trim();
    setInputText('');

    if (apiConversations) {
      // Use real API
      try {
        await api.messages.sendMessage(activeConvId, text);
        refetchConvs();
      } catch {
        // Silently fail — user sees the input cleared
      }
    } else {
      // Local mock fallback
      const newMsg: DirectMessage = {
        id: `msg_${Date.now()}`,
        senderId: CURRENT_USER_ID,
        content: text,
        type: 'text',
        isRead: false,
        createdAt: new Date().toISOString(),
      };
      setLocalMessages((prev) => ({
        ...prev,
        [activeConvId]: [...(prev[activeConvId] ?? []), newMsg],
      }));
    }
  }, [inputText, activeConvId, apiConversations, refetchConvs]);

  return (
    <div className="h-[calc(100vh-120px)] max-w-5xl mx-auto flex rounded-2xl overflow-hidden" style={{ border: '1px solid rgba(255,255,255,0.07)' }}>
      {/* ── Conversation list ───────────────────────────────────── */}
      <div
        className={cn(
          'flex flex-col shrink-0 w-full md:w-80',
          activeConvId ? 'hidden md:flex' : 'flex'
        )}
        style={{ background: 'rgba(17,17,24,0.8)', borderRight: '1px solid rgba(255,255,255,0.07)' }}
      >
        {/* Header */}
        <div className="px-4 py-4 space-y-3" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
          <h2 className="text-base font-black text-primary">Messages</h2>
          <div
            className="flex items-center gap-2 px-3 py-2.5 rounded-xl"
            style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}
          >
            <Search size={14} className="text-secondary shrink-0" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search conversations"
              className="flex-1 bg-transparent text-sm text-primary placeholder:text-secondary outline-none"
            />
          </div>
        </div>

        {/* List */}
        <div className="flex-1 overflow-y-auto">
          {filteredConvs.map((conv) => (
            <ConvItem
              key={conv.id}
              conv={conv}
              isActive={activeConvId === conv.id}
              onClick={() => setActiveConvId(conv.id)}
            />
          ))}
        </div>
      </div>

      {/* ── Active chat ─────────────────────────────────────────── */}
      <div
        className={cn(
          'flex-1 flex-col',
          activeConvId ? 'flex' : 'hidden md:flex'
        )}
        style={{ background: 'rgba(10,10,15,0.9)' }}
      >
        <AnimatePresence mode="wait">
          {activeConv && activeOther ? (
            <motion.div
              key={activeConvId}
              initial={{ opacity: 0, x: 16 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0 }}
              className="flex flex-col h-full"
            >
              {/* Chat header */}
              <div
                className="flex items-center gap-3 px-4 py-3.5 shrink-0"
                style={{ borderBottom: '1px solid rgba(255,255,255,0.07)' }}
              >
                <button
                  onClick={() => setActiveConvId(null)}
                  className="md:hidden text-secondary hover:text-primary transition-colors mr-1"
                >
                  <ArrowLeft size={20} />
                </button>
                <div
                  className="w-9 h-9 rounded-full flex items-center justify-center shrink-0 font-bold text-white text-xs select-none"
                  style={{ backgroundColor: avatarColor(activeOther.id) }}
                >
                  {getInitials(activeOther.displayName)}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-bold text-primary">{activeOther.displayName}</p>
                  <p className="text-[11px] text-secondary">@{activeOther.username}</p>
                </div>
                <div className="flex items-center gap-2">
                  <button className="p-2 rounded-lg text-secondary hover:text-primary hover:bg-white/[0.05] transition-all duration-150">
                    <Phone size={16} />
                  </button>
                  <button className="p-2 rounded-lg text-secondary hover:text-primary hover:bg-white/[0.05] transition-all duration-150">
                    <Video size={16} />
                  </button>
                  <button className="p-2 rounded-lg text-secondary hover:text-primary hover:bg-white/[0.05] transition-all duration-150">
                    <MoreHorizontal size={16} />
                  </button>
                </div>
              </div>

              {/* Messages */}
              <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
                {activeMessages.map((msg) => (
                  <MsgBubble
                    key={msg.id}
                    msg={msg}
                    isOwn={msg.senderId === CURRENT_USER_ID || msg.senderId === (user?.id ?? '')}
                  />
                ))}
                <div ref={bottomRef} />
              </div>

              {/* Input bar */}
              <div
                className="px-4 py-3 shrink-0"
                style={{ borderTop: '1px solid rgba(255,255,255,0.07)' }}
              >
                <div
                  className="flex items-center gap-3 px-4 py-3 rounded-2xl"
                  style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}
                >
                  <input
                    value={inputText}
                    onChange={(e) => setInputText(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && sendMessage()}
                    placeholder={`Message ${activeOther.displayName}…`}
                    className="flex-1 bg-transparent text-sm text-primary placeholder:text-secondary outline-none"
                  />
                  <button
                    onClick={sendMessage}
                    disabled={!inputText.trim()}
                    className="w-8 h-8 rounded-xl flex items-center justify-center transition-all duration-200 disabled:opacity-40 hover:opacity-90 active:scale-95"
                    style={{ background: 'linear-gradient(135deg, #6c63ff, #8b5cf6)' }}
                  >
                    <Send size={14} className="text-white" />
                  </button>
                </div>
              </div>
            </motion.div>
          ) : (
            <motion.div
              key="empty"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex-1 flex flex-col items-center justify-center gap-4"
            >
              <div
                className="w-20 h-20 rounded-3xl flex items-center justify-center"
                style={{ background: 'rgba(108,99,255,0.12)', border: '1px solid rgba(108,99,255,0.2)' }}
              >
                <MessageSquare size={36} style={{ color: '#6c63ff' }} />
              </div>
              <div className="text-center">
                <p className="text-base font-bold text-primary">Your messages</p>
                <p className="text-sm text-secondary mt-1 max-w-[220px]">
                  Select a conversation to start chatting with your learning community.
                </p>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
