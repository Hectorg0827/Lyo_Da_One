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

const AVATAR_COLORS = ['#6c63ff', '#22c55e', '#ec4899', '#f59e0b', '#3b82f6'];

function avatarColor(id: string) {
  return AVATAR_COLORS[id.charCodeAt(id.length - 1) % AVATAR_COLORS.length];
}

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

  const conversations = apiConversations ?? [];
  const activeConv = conversations.find((c) => c.id === activeConvId) ?? null;
  const activeOther = activeConv?.participants[0] ?? null;
  const activeMessages = activeConvId ? apiMessages ?? [] : [];

  const filteredConvs = conversations.filter((c) =>
    c.participants[0]?.displayName.toLowerCase().includes(search.toLowerCase())
  );

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [activeMessages.length]);

  // Mark conversation as read when opened
  useEffect(() => {
    if (activeConvId) {
      api.messages.markRead(activeConvId).catch(() => {});
    }
  }, [activeConvId]);

  const sendMessage = useCallback(async () => {
    if (!inputText.trim() || !activeConvId) return;
    const text = inputText.trim();
    setInputText('');

    try {
      await api.messages.sendMessage(activeConvId, text);
      refetchConvs();
      refetchMsgs();
    } catch {
      // Silently fail — user sees the input cleared
    }
  }, [inputText, activeConvId, refetchConvs, refetchMsgs]);

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
                    isOwn={msg.senderId === (user?.id ?? '')}
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
