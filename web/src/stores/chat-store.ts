import { create } from 'zustand';
import toast from 'react-hot-toast';
import type { ChatMessage, ChatConversation } from '@/types';
import { generateId } from '@/lib/utils';
import { api } from '@/lib/api';

interface ChatStore {
  conversations: ChatConversation[];
  activeConversationId: string | null;
  isGenerating: boolean;
  generationProgress: number;
  isHydrating: boolean;

  createConversation: () => string;
  setActiveConversation: (id: string | null) => void;
  hydrate: () => Promise<void>;
  loadConversation: (id: string) => Promise<void>;
  sendMessage: (content: string) => Promise<void>;
  deleteConversation: (id: string) => void;
  getActiveConversation: () => ChatConversation | undefined;
}

export const useChatStore = create<ChatStore>((set, get) => ({
  conversations: [],
  activeConversationId: null,
  isGenerating: false,
  generationProgress: 0,
  isHydrating: false,

  createConversation: () => {
    const id = `local-${generateId()}`;
    const convo: ChatConversation = {
      id,
      title: 'New Chat',
      messages: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    set((state) => ({
      conversations: [convo, ...state.conversations],
      activeConversationId: id,
    }));
    return id;
  },

  setActiveConversation: (id) => set({ activeConversationId: id }),

  hydrate: async () => {
    if (get().isHydrating) return;
    set({ isHydrating: true });
    try {
      const result = await api.chat.conversations();
      const conversations: ChatConversation[] = result.conversations.map((conversation) => ({
        id: conversation.id,
        title: conversation.title,
        messages: [],
        createdAt: conversation.created_at,
        updatedAt: conversation.updated_at,
      }));
      const activeConversationId =
        get().activeConversationId && conversations.some((c) => c.id === get().activeConversationId)
          ? get().activeConversationId
          : conversations[0]?.id ?? null;
      set({ conversations, activeConversationId, isHydrating: false });
      if (activeConversationId) await get().loadConversation(activeConversationId);
    } catch {
      set({ isHydrating: false });
    }
  },

  loadConversation: async (id) => {
    if (id.startsWith('local-')) {
      set({ activeConversationId: id });
      return;
    }
    const detail = await api.chat.conversation(id);
    const messages: ChatMessage[] = detail.messages.map((message) => ({
      id: message.id,
      role: message.role,
      content: message.content,
      type: 'text',
      createdAt: message.created_at,
    }));
    set((state) => ({
      activeConversationId: id,
      conversations: state.conversations.map((conversation) =>
        conversation.id === id
          ? {
              ...conversation,
              title: detail.title,
              messages,
              createdAt: detail.created_at,
              updatedAt: detail.updated_at,
            }
          : conversation
      ),
    }));
  },

  sendMessage: async (content: string) => {
    const state = get();
    let convoId = state.activeConversationId;

    if (!convoId) {
      convoId = get().createConversation();
    }

    if (convoId.startsWith('local-')) {
      const localId = convoId;
      try {
        const remote = await api.chat.createConversation(content.slice(0, 80));
        convoId = remote.id;
        set((current) => ({
          activeConversationId: remote.id,
          conversations: current.conversations.map((conversation) =>
            conversation.id === localId
              ? {
                  ...conversation,
                  id: remote.id,
                  title: remote.title,
                  createdAt: remote.created_at,
                  updatedAt: remote.updated_at,
                }
              : conversation
          ),
        }));
      } catch {
        // Never fail the send silently: keep the device-local thread so the
        // user's message renders, and let the stream (or its error toast)
        // take it from here.
        toast.error("Couldn't sync this chat to your account—retrying with a local copy.");
        convoId = localId;
      }
    }

    const userMessage: ChatMessage = {
      id: generateId(),
      role: 'user',
      content,
      type: 'text',
      createdAt: new Date().toISOString(),
    };

    set((s) => ({
      conversations: s.conversations.map((c) =>
        c.id === convoId
          ? {
              ...c,
              title: c.messages.length === 0 ? content.slice(0, 50) : c.title,
              messages: [...c.messages, userMessage],
              updatedAt: new Date().toISOString(),
            }
          : c
      ),
      isGenerating: true,
      generationProgress: 10,
    }));

    // The server is the source of truth for history. Sending only the current
    // conversation ID prevents stale or truncated device-local context.
    const history = undefined;

    const aiMessageId = generateId();
    let accumulated = '';

    const appendToAiMessage = (text: string) => {
      accumulated += text;
      set((s) => ({
        conversations: s.conversations.map((c) => {
          if (c.id !== convoId) return c;
          const existing = c.messages.find((m) => m.id === aiMessageId);
          if (existing) {
            return {
              ...c,
              messages: c.messages.map((m) =>
                m.id === aiMessageId ? { ...m, content: accumulated } : m
              ),
              updatedAt: new Date().toISOString(),
            };
          }
          return {
            ...c,
            messages: [
              ...c.messages,
              {
                id: aiMessageId,
                role: 'assistant' as const,
                content: accumulated,
                type: 'text' as const,
                createdAt: new Date().toISOString(),
              },
            ],
            updatedAt: new Date().toISOString(),
          };
        }),
        generationProgress: Math.min(90, get().generationProgress + 5),
      }));
    };

    try {
      api.chat.stream(
        content,
        history,
        (chunk) => {
          const block = chunk.block as Record<string, unknown> | undefined;
          const blockContent = block?.content as Record<string, unknown> | undefined;
          if (chunk.type === 'answer' || chunk.type === 'text') {
            const text = blockContent?.text as string
              || (chunk.payload as Record<string, unknown>)?.text as string
              || (chunk.content as string)
              || '';
            if (text) appendToAiMessage(text);
          } else if (chunk.type === 'clarification' && typeof chunk.text === 'string') {
            appendToAiMessage(chunk.text);
          } else if (chunk.data) {
            const text = typeof chunk.data === 'string' ? chunk.data : '';
            if (text) appendToAiMessage(text);
          } else if (typeof chunk === 'object' && chunk.content) {
            appendToAiMessage(chunk.content as string);
          }
        },
        () => {
          if (!accumulated) {
            recoverCanonicalConversation(convoId!);
          } else {
            set({ isGenerating: false, generationProgress: 0 });
          }
        },
        () => {
          recoverCanonicalConversation(convoId!);
        },
        convoId,
        userMessage.id
      );
    } catch {
      recoverCanonicalConversation(convoId!);
    }

    async function recoverCanonicalConversation(cId: string) {
      set({ isGenerating: false, generationProgress: 0 });
      try {
        // A broken SSE connection does not imply the server failed. Reload the
        // canonical thread so a completed answer is recovered without creating
        // a second, device-only response.
        await get().loadConversation(cId);
      } catch {
        // Preserve the optimistic user turn until the next successful hydrate.
      }
      toast.error('The response was interrupted. Your conversation is saved—please retry.');
    }
  },

  deleteConversation: (id) => {
    if (!id.startsWith('local-')) api.chat.deleteConversation(id).catch(() => {});
    set((state) => ({
      conversations: state.conversations.filter((c) => c.id !== id),
      activeConversationId:
        state.activeConversationId === id ? null : state.activeConversationId,
    }));
  },

  getActiveConversation: () => {
    const state = get();
    return state.conversations.find(
      (c) => c.id === state.activeConversationId
    );
  },
}));
