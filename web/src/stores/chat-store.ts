import { create } from 'zustand';
import type { ChatMessage, ChatConversation } from '@/types';
import { generateId } from '@/lib/utils';
import { api } from '@/lib/api';

interface ChatStore {
  conversations: ChatConversation[];
  activeConversationId: string | null;
  isGenerating: boolean;
  generationProgress: number;

  createConversation: () => string;
  setActiveConversation: (id: string | null) => void;
  sendMessage: (content: string) => Promise<void>;
  deleteConversation: (id: string) => void;
  getActiveConversation: () => ChatConversation | undefined;
}

export const useChatStore = create<ChatStore>((set, get) => ({
  conversations: [],
  activeConversationId: null,
  isGenerating: false,
  generationProgress: 0,

  createConversation: () => {
    const id = generateId();
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

  sendMessage: async (content: string) => {
    const state = get();
    let convoId = state.activeConversationId;

    if (!convoId) {
      convoId = get().createConversation();
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

    const conversation = get().conversations.find((c) => c.id === convoId);
    const history = conversation?.messages
      .filter((m) => m.role !== 'system')
      .map((m) => ({ role: m.role, content: m.content }));

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
          if (chunk.type === 'answer' || chunk.type === 'text') {
            const text = (chunk.payload as Record<string, unknown>)?.text as string
              || (chunk.content as string)
              || '';
            if (text) appendToAiMessage(text);
          } else if (chunk.type === 'open_classroom') {
            const courseData = chunk.block?.content?.course || chunk.block?.content;
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
            fallbackToSimpleChat(content, convoId!, aiMessageId);
          } else {
            set({ isGenerating: false, generationProgress: 0 });
          }
        },
        () => {
          fallbackToSimpleChat(content, convoId!, aiMessageId);
        }
      );
    } catch {
      fallbackToSimpleChat(content, convoId!, aiMessageId);
    }

    async function fallbackToSimpleChat(msg: string, cId: string, msgId: string) {
      try {
        const res = await api.chat.sendSimple(msg);
        const text = res.response || 'Sorry, I could not generate a response.';
        set((s) => ({
          conversations: s.conversations.map((c) => {
            if (c.id !== cId) return c;
            const existing = c.messages.find((m) => m.id === msgId);
            if (existing) {
              return {
                ...c,
                messages: c.messages.map((m) =>
                  m.id === msgId ? { ...m, content: text } : m
                ),
              };
            }
            return {
              ...c,
              messages: [
                ...c.messages,
                {
                  id: msgId,
                  role: 'assistant' as const,
                  content: text,
                  type: 'text' as const,
                  createdAt: new Date().toISOString(),
                },
              ],
            };
          }),
          isGenerating: false,
          generationProgress: 0,
        }));
      } catch {
        set((s) => ({
          conversations: s.conversations.map((c) => {
            if (c.id !== cId) return c;
            return {
              ...c,
              messages: [
                ...c.messages,
                {
                  id: msgId,
                  role: 'assistant' as const,
                  content:
                    'I apologize, but I\'m having trouble connecting right now. Please try again in a moment.',
                  type: 'text' as const,
                  createdAt: new Date().toISOString(),
                },
              ],
            };
          }),
          isGenerating: false,
          generationProgress: 0,
        }));
      }
    }
  },

  deleteConversation: (id) =>
    set((state) => ({
      conversations: state.conversations.filter((c) => c.id !== id),
      activeConversationId:
        state.activeConversationId === id ? null : state.activeConversationId,
    })),

  getActiveConversation: () => {
    const state = get();
    return state.conversations.find(
      (c) => c.id === state.activeConversationId
    );
  },
}));
