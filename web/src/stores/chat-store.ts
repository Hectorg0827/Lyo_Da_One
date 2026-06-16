import { create } from 'zustand';
import type { ChatMessage, ChatConversation } from '@/types';
import { generateId } from '@/lib/utils';

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

const AI_RESPONSES: Record<string, string> = {
  default: `Great question! Let me create a comprehensive learning path for you.

I'll design a course that covers the fundamentals, practical exercises, and real-world applications. Here's what I'm thinking:

**Course Outline:**
1. Introduction & Core Concepts
2. Hands-on Practice
3. Advanced Techniques
4. Real-World Projects
5. Assessment & Certification

Would you like me to generate this course for you? I can customize the difficulty level and learning style to match your preferences.`,
};

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
      generationProgress: 0,
    }));

    // Simulate AI streaming response
    const progressSteps = [10, 25, 40, 55, 70, 85, 95, 100];
    for (const p of progressSteps) {
      await new Promise((r) => setTimeout(r, 200));
      set({ generationProgress: p });
    }

    const aiMessage: ChatMessage = {
      id: generateId(),
      role: 'assistant',
      content: AI_RESPONSES.default,
      type: 'text',
      createdAt: new Date().toISOString(),
    };

    set((s) => ({
      conversations: s.conversations.map((c) =>
        c.id === convoId
          ? {
              ...c,
              messages: [...c.messages, aiMessage],
              updatedAt: new Date().toISOString(),
            }
          : c
      ),
      isGenerating: false,
      generationProgress: 0,
    }));
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
