'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, Send, MessageSquare, ArrowLeft, PenSquare, X, Loader2, AlertCircle } from 'lucide-react';
import { cn, getInitials, formatTimeAgo } from '@/lib/utils';
import { useAuthStore } from '@/stores/auth-store';
import { useApi } from '@/hooks/use-api';
import { useSyncEvents } from '@/hooks/use-sync';
import { api } from '@/lib/api';
import type { Conversation, DirectMessage, User } from '@/types';
import { conversationIdFromSearch, conversationListState } from '@/lib/messages-view.mjs';
import { UNREAD_CHANGED_EVENT } from '@/lib/unread.mjs';

type Person = { id: number; username: string; name: string; avatar_url: string | null };

const AVATAR_COLORS = ['#6366f1', '#22c55e', '#ec4899', '#f59e0b', '#3b82f6'];

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
        isActive && 'bg-[#6366f1]/10'
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
              style={{ background: '#6366f1', minWidth: 18, textAlign: 'center' }}
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
            ? { background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }
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
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [composing, setComposing] = useState(false);
  const [peopleQuery, setPeopleQuery] = useState('');
  const [people, setPeople] = useState<Person[]>([]);
  const [peopleSearching, setPeopleSearching] = useState(false);
  const [startError, setStartError] = useState<string | null>(null);
  const [starting, setStarting] = useState<number | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  // ── API data fetching ──────────────────────────────────────────────────
  const {
    data: convData,
    isLoading: convLoading,
    error: convError,
    refetch: refetchConvs,
  } = useApi(() => api.messages.conversations(), []);
  const {
    data: msgData,
    isLoading: msgLoading,
    error: msgError,
    refetch: refetchMsgs,
  } = useApi(activeConvId ? () => api.messages.getMessages(activeConvId) : null, [activeConvId]);

  // A notification link (/messages?conversation=12) opens that conversation.
  useEffect(() => {
    const linked = conversationIdFromSearch(window.location.search);
    if (linked) setActiveConvId(linked);
  }, []);

  // New message: find a Lyo member by name.
  useEffect(() => {
    const text = peopleQuery.trim();
    if (!composing || text.length < 2) {
      setPeople([]);
      return;
    }
    let cancelled = false;
    const timer = setTimeout(async () => {
      setPeopleSearching(true);
      try {
        const found = await api.search.query(text, 'users', 8);
        if (!cancelled) setPeople(found.users.filter((person) => String(person.id) !== String(user?.id ?? '')));
      } catch {
        if (!cancelled) setPeople([]);
      } finally {
        if (!cancelled) setPeopleSearching(false);
      }
    }, 300);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [composing, peopleQuery, user?.id]);

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
  const listState = conversationListState({
    loading: convLoading,
    error: convError,
    loaded: apiConversations !== null,
    total: conversations.length,
    shown: filteredConvs.length,
  });

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [activeMessages.length]);

  // Mark conversation as read when opened, then let the top bar's count catch up
  useEffect(() => {
    if (activeConvId) {
      api.messages
        .markRead(activeConvId)
        .then(() => window.dispatchEvent(new Event(UNREAD_CHANGED_EVENT)))
        .catch(() => {});
    }
  }, [activeConvId]);

  const sendMessage = useCallback(async () => {
    if (!inputText.trim() || !activeConvId || sending) return;
    const text = inputText.trim();
    setInputText('');
    setSendError(null);
    setSending(true);

    try {
      await api.messages.sendMessage(activeConvId, text);
      refetchConvs();
      refetchMsgs();
    } catch {
      // Never lose what they wrote: put it back and say it didn't send.
      setInputText((current) => current || text);
      setSendError("Your message wasn't sent. Check your connection and try again.");
    } finally {
      setSending(false);
    }
  }, [inputText, activeConvId, sending, refetchConvs, refetchMsgs]);

  const startConversation = useCallback(
    async (person: Person) => {
      setStartError(null);
      setStarting(person.id);
      try {
        const created = await api.messages.createConversation([person.id]);
        refetchConvs();
        setComposing(false);
        setPeopleQuery('');
        setActiveConvId(String(created.id ?? ''));
      } catch {
        setStartError(`We couldn't start a conversation with ${person.name || person.username}. Please try again.`);
      } finally {
        setStarting(null);
      }
    },
    [refetchConvs]
  );

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
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-base font-black text-primary">Messages</h2>
            <button
              type="button"
              onClick={() => {
                setComposing((open) => !open);
                setPeopleQuery('');
                setStartError(null);
              }}
              aria-label={composing ? 'Cancel new message' : 'New message'}
              aria-expanded={composing}
              className="flex h-9 w-9 items-center justify-center rounded-xl text-secondary transition-colors hover:bg-white/[0.06] hover:text-primary"
            >
              {composing ? <X size={18} /> : <PenSquare size={18} />}
            </button>
          </div>
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

        {/* New message: pick a person */}
        {composing && (
          <div className="space-y-2 px-4 py-3" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
            <label htmlFor="new-message-person" className="text-xs font-semibold text-secondary">
              New message to
            </label>
            <input
              id="new-message-person"
              autoFocus
              value={peopleQuery}
              onChange={(e) => setPeopleQuery(e.target.value)}
              placeholder="Name or username"
              autoComplete="off"
              className="w-full rounded-xl px-3 py-2.5 text-sm text-primary placeholder:text-secondary outline-none"
              style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}
            />
            {peopleSearching && <p className="text-xs text-secondary">Searching…</p>}
            {!peopleSearching && peopleQuery.trim().length >= 2 && people.length === 0 && (
              <p className="text-xs text-secondary">No Lyo members match “{peopleQuery.trim()}”.</p>
            )}
            {people.length > 0 && (
              <ul aria-label="People" className="space-y-1">
                {people.map((person) => (
                  <li key={person.id}>
                    <button
                      type="button"
                      onClick={() => void startConversation(person)}
                      disabled={starting !== null}
                      className="flex w-full items-center gap-3 rounded-xl px-2 py-2 text-left hover:bg-white/[0.05] disabled:opacity-60"
                    >
                      <span
                        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white"
                        style={{ backgroundColor: avatarColor(String(person.id)) }}
                        aria-hidden="true"
                      >
                        {getInitials(person.name || person.username)}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-semibold text-primary">{person.name || person.username}</span>
                        <span className="block truncate text-xs text-secondary">@{person.username}</span>
                      </span>
                      {starting === person.id && <Loader2 size={14} className="animate-spin text-secondary" aria-hidden="true" />}
                    </button>
                  </li>
                ))}
              </ul>
            )}
            {startError && (
              <p role="alert" className="text-xs text-red-400">
                {startError}
              </p>
            )}
          </div>
        )}

        {/* List */}
        <div className="flex-1 overflow-y-auto" aria-busy={listState === 'loading'}>
          {listState === 'loading' && (
            <div role="status" className="space-y-1 px-4 py-3">
              <span className="sr-only">Loading your conversations…</span>
              {[0, 1, 2].map((row) => (
                <div key={row} className="flex items-center gap-3 py-2" aria-hidden="true">
                  <div className="h-11 w-11 rounded-full bg-white/[0.06]" />
                  <div className="flex-1 space-y-2">
                    <div className="h-3 w-2/3 rounded bg-white/[0.08]" />
                    <div className="h-2.5 w-1/2 rounded bg-white/[0.05]" />
                  </div>
                </div>
              ))}
            </div>
          )}
          {listState === 'error' && (
            <div role="alert" className="flex flex-col items-center gap-3 px-6 py-10 text-center">
              <AlertCircle size={28} className="text-red-400" aria-hidden="true" />
              <p className="text-sm font-semibold text-primary">We couldn&apos;t load your messages.</p>
              <p className="text-xs text-secondary">Please check your connection and try again.</p>
              <button
                type="button"
                onClick={refetchConvs}
                className="rounded-xl px-4 py-2 text-sm font-semibold text-white"
                style={{ background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }}
              >
                Try again
              </button>
            </div>
          )}
          {listState === 'empty' && (
            <div className="flex flex-col items-center gap-2 px-6 py-10 text-center">
              <p className="text-sm font-semibold text-primary">No conversations yet</p>
              <p className="text-xs text-secondary">Tap the pencil above to message someone from your learning community.</p>
            </div>
          )}
          {listState === 'no-match' && (
            <p className="px-4 py-6 text-center text-xs text-secondary">No conversations match “{search}”.</p>
          )}
          {listState === 'list' &&
            filteredConvs.map((conv) => (
              <ConvItem
                key={conv.id}
                conv={conv}
                isActive={activeConvId === conv.id}
                onClick={() => {
                  setActiveConvId(conv.id);
                  setSendError(null);
                }}
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
              </div>

              {/* Messages */}
              <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
                {msgLoading && !msgData && (
                  <p role="status" className="py-6 text-center text-xs text-secondary">
                    Loading messages…
                  </p>
                )}
                {msgError && !msgData && (
                  <div role="alert" className="flex flex-col items-center gap-2 py-6 text-center">
                    <p className="text-sm text-primary">We couldn&apos;t load this conversation.</p>
                    <button type="button" onClick={refetchMsgs} className="text-xs font-semibold text-[#a78bfa] hover:underline">
                      Try again
                    </button>
                  </div>
                )}
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
                {sendError && (
                  <p role="alert" className="mb-2 text-xs text-red-400">
                    {sendError}
                  </p>
                )}
                <div
                  className="flex items-center gap-3 px-4 py-3 rounded-2xl"
                  style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}
                >
                  <input
                    value={inputText}
                    aria-label={`Message ${activeOther.displayName}`}
                    onChange={(e) => {
                      setInputText(e.target.value);
                      if (sendError) setSendError(null);
                    }}
                    onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && sendMessage()}
                    placeholder={`Message ${activeOther.displayName}…`}
                    className="flex-1 bg-transparent text-sm text-primary placeholder:text-secondary outline-none"
                  />
                  <button
                    onClick={sendMessage}
                    disabled={!inputText.trim() || sending}
                    aria-label="Send message"
                    className="w-8 h-8 rounded-xl flex items-center justify-center transition-all duration-200 disabled:opacity-40 hover:opacity-90 active:scale-95"
                    style={{ background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }}
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
                style={{ background: 'rgba(99,102,241,0.12)', border: '1px solid rgba(99,102,241,0.2)' }}
              >
                <MessageSquare size={36} style={{ color: '#6366f1' }} />
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
