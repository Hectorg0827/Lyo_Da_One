import { create } from 'zustand';
import toast from 'react-hot-toast';
import type { ChatMessage, ChatConversation, ChatAttachment } from '@/types';
import { generateId } from '@/lib/utils';
import { api } from '@/lib/api';
import { parseCanonicalChatContent } from '@/lib/chat-attachments';

export type GenerationActivity = 'thinking' | 'response' | 'course';

// Module-scoped, not store state: this must survive ChatInterface
// remounting (tabbing away and back within the same app session) but reset
// to false whenever the app is actually reopened — a fresh page load/PWA
// launch re-evaluates this module from scratch, which is exactly the
// "was the app closed" signal ChatGPT/Claude-style "always open on a new
// chat" behavior needs. See hydrate() below.
let hasHydratedThisSession = false;

interface ChatStore {
  conversations: ChatConversation[];
  activeConversationId: string | null;
  isGenerating: boolean;
  generationProgress: number;
  generationActivity: GenerationActivity;
  isHydrating: boolean;

  createConversation: () => string;
  setActiveConversation: (id: string | null) => void;
  hydrate: () => Promise<void>;
  loadConversation: (id: string) => Promise<void>;
  sendMessage: (content: string, attachments?: ChatAttachment[]) => Promise<void>;
  deleteConversation: (id: string) => void;
  getActiveConversation: () => ChatConversation | undefined;
}

export const useChatStore = create<ChatStore>((set, get) => ({
  conversations: [],
  activeConversationId: null,
  isGenerating: false,
  generationProgress: 0,
  generationActivity: 'thinking',
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

      if (hasHydratedThisSession) {
        // hydrate() runs again every time ChatInterface remounts (e.g. the
        // learner tabs away to Community and back) — that must not disturb
        // whatever conversation is currently open, only refresh the
        // sidebar's history list. A not-yet-synced "New Chat" (a local-
        // only id, absent from the server's list) is kept in front of it.
        const active = get().conversations.find((c) => c.id === get().activeConversationId);
        set({
          conversations: active?.id.startsWith('local-') ? [active, ...conversations] : conversations,
          isHydrating: false,
        });
        return;
      }
      hasHydratedThisSession = true;

      // The first hydrate since the app was actually opened (a fresh page
      // load — reopening a closed tab/PWA re-runs this module from
      // scratch): behave like ChatGPT/Claude and land on a brand-new
      // conversation rather than silently resuming whatever was last open.
      // Nothing is deleted — every past conversation is fetched above and
      // stays one click away in the sidebar.
      set({ conversations, activeConversationId: null, isHydrating: false });
      get().createConversation();
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
    const messages: ChatMessage[] = detail.messages.map((message) => {
      const parsed = message.role === 'user'
        ? parseCanonicalChatContent(message.content)
        : { text: message.content, attachments: [] };
      return {
        id: message.id,
        role: message.role,
        content: parsed.text,
        type: 'text',
        attachments: parsed.attachments,
        createdAt: message.created_at,
      };
    });
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

  sendMessage: async (content: string, attachments: ChatAttachment[] = []) => {
    const state = get();
    let convoId = state.activeConversationId;
    const trimmedContent = content.trim();
    const titleSeed = trimmedContent || attachments[0]?.name || 'New Chat';

    if (!convoId) {
      convoId = get().createConversation();
    }

    if (convoId.startsWith('local-')) {
      const localId = convoId;
      try {
        const remote = await api.chat.createConversation(titleSeed.slice(0, 80));
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
      content: trimmedContent,
      type: 'text',
      attachments,
      createdAt: new Date().toISOString(),
    };

    set((s) => ({
      conversations: s.conversations.map((c) =>
        c.id === convoId
          ? {
              ...c,
              title: c.messages.length === 0 ? titleSeed.slice(0, 50) : c.title,
              messages: [...c.messages, userMessage],
              updatedAt: new Date().toISOString(),
            }
          : c
      ),
      isGenerating: true,
      generationProgress: 10,
      generationActivity: 'thinking',
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
        generationActivity: s.generationActivity === 'course' ? 'course' : 'response',
      }));
    };

    try {
      api.chat.stream(
        trimmedContent,
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
          } else if (chunk.type === 'open_classroom') {
            const classroomBlock = chunk.block as { content?: Record<string, any> } | undefined;
            const courseData = (classroomBlock?.content?.course || classroomBlock?.content) as
              Record<string, any> | undefined;
            if (courseData) {
              // Normalize difficulty
              if (courseData.difficulty) {
                courseData.difficulty = courseData.difficulty.toLowerCase();
              }
              // Normalize duration string/number
              const rawDuration = courseData.estimated_duration || courseData.duration;
              let sanitizedDuration = 60; // fallback to 60 mins
              if (typeof rawDuration === 'number') {
                sanitizedDuration = rawDuration;
              } else if (typeof rawDuration === 'string') {
                const numMatch = rawDuration.match(/\d+/);
                if (numMatch) {
                  const num = parseInt(numMatch[0]);
                  if (rawDuration.toLowerCase().includes('hour')) {
                    sanitizedDuration = num * 60;
                  } else {
                    sanitizedDuration = num;
                  }
                }
              }
              courseData.estimatedDuration = sanitizedDuration;

              // Normalize lessons to modules
              if (!courseData.modules && courseData.lessons) {
                courseData.modules = courseData.lessons.map((lesson: any, index: number) => ({
                  id: lesson.id || `l-${index}`,
                  title: lesson.title,
                  description: lesson.description || '',
                  order: index + 1,
                  lessons: [lesson]
                }));
              }

              set((s) => ({
                generationActivity: 'course',
                conversations: s.conversations.map((c) => {
                  if (c.id !== convoId) return c;
                  const existing = c.messages.find((m) => m.id === aiMessageId);
                  if (existing) {
                    return {
                      ...c,
                      messages: c.messages.map((m) =>
                        m.id === aiMessageId
                          ? {
                              ...m,
                              type: 'course_proposal' as const,
                              metadata: { ...m.metadata, course: courseData },
                            }
                          : m
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
                        content: '',
                        type: 'course_proposal' as const,
                        metadata: { course: courseData },
                        createdAt: new Date().toISOString(),
                      },
                    ],
                    updatedAt: new Date().toISOString(),
                  };
                }),
              }));
            }
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
            set({
              isGenerating: false,
              generationProgress: 0,
              generationActivity: 'thinking',
            });
          }
        },
        () => {
          recoverCanonicalConversation(convoId!);
        },
        convoId,
        userMessage.id,
        attachments.map((attachment) => ({
          modality: attachment.kind === 'image' ? 'IMAGE' as const : 'DOCUMENT' as const,
          uri: attachment.url,
          mime_type: attachment.mimeType,
          name: attachment.name,
          size_bytes: attachment.size,
        }))
      );
    } catch {
      recoverCanonicalConversation(convoId!);
    }

    async function recoverCanonicalConversation(cId: string) {
      set({
        isGenerating: false,
        generationProgress: 0,
        generationActivity: 'thinking',
      });
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

