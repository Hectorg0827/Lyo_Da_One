import { create } from 'zustand';
import toast from 'react-hot-toast';
import type {
  ChatMessage,
  ChatConversation,
  ChatAttachment,
  ChatBlock,
  CheckAnswerResult,
  SessionSummary,
  DueReviewItem,
} from '@/types';
import { generateId } from '@/lib/utils';
import { api } from '@/lib/api';
import { parseCanonicalChatContent } from '@/lib/chat-attachments';
import { publishVoiceStreamEvent } from '@/lib/conversational-voice';
import { reportActiveVoiceQuality, voiceQualityNow } from '@/lib/voice-quality';
import {
  emptyTeachingRuntimeState,
  reduceTeachingPolicy,
  teachingStateSummary,
} from '@/lib/teaching-runtime.mjs';

export type GenerationActivity = 'thinking' | 'searching' | 'response' | 'course';

export interface CourseGenerationState {
  phase: 'intent' | 'planning' | 'lessons' | 'practice' | 'finalizing' | 'ready' | string;
  progress: number;
  message?: string;
  completedLessons?: number;
  totalLessons?: number;
  outline?: Array<{ title: string; description?: string }>;
}

export interface CourseRevisionInput {
  topic?: string;
  difficulty?: 'beginner' | 'intermediate' | 'advanced';
  length?: 'short' | 'standard' | 'deep';
  teachingStyle?: 'guided' | 'conversational' | 'practice-heavy';
  focus?: string;
}

interface SendMessageOptions {
  forcedIntent?: 'COURSE';
  courseContext?: CourseRevisionInput;
  voiceSession?: boolean;
  voiceInterruptedPreviousTurn?: boolean;
  voiceTurnId?: string;
  voiceLocale?: string;
}

/**
 * Pull CTA labels out of an `actions` SSE event.
 *
 * The backend sends `{type:'actions', blocks:[{type:'CTARow',
 * content:{actions:[...]}}]}`. Web dropped this event entirely, so
 * server-suggested follow-ups never rendered.
 */
/**
 * Recover previously graded check verdicts from persisted block metadata.
 *
 * The server writes the verdict onto the block when it grades, so a reloaded
 * conversation can show an answered check as answered rather than re-offering
 * it and losing the learner's selection.
 */
function extractCheckResults(blocks: ChatBlock[]): Record<string, CheckAnswerResult> | undefined {
  const results: Record<string, CheckAnswerResult> = {};
  for (const block of blocks) {
    const stored = block?.metadata?.result;
    if (stored && typeof stored === 'object' && 'correct' in (stored as object)) {
      results[block.id] = stored as CheckAnswerResult;
    }
  }
  return Object.keys(results).length > 0 ? results : undefined;
}

function extractActionLabels(chunk: Record<string, unknown>): string[] {
  const blocks = Array.isArray(chunk.blocks) ? chunk.blocks : [];
  const labels: string[] = [];
  for (const block of blocks) {
    const actions = (block as { content?: { actions?: unknown } })?.content?.actions;
    if (Array.isArray(actions)) {
      labels.push(...actions.filter((a): a is string => typeof a === 'string'));
    }
  }
  return labels;
}

function normalizeCourseDuration(course?: Record<string, unknown>): number | undefined {
  const raw = course?.estimatedDuration ?? course?.estimated_duration ?? course?.duration;
  if (typeof raw === 'number' && Number.isFinite(raw)) return raw;
  if (typeof raw !== 'string') return undefined;

  const match = raw.match(/\d+(?:\.\d+)?/);
  if (!match) return undefined;
  const value = Number(match[0]);
  if (!Number.isFinite(value)) return undefined;
  return /\bhours?\b/i.test(raw) ? Math.round(value * 60) : Math.round(value);
}

// Module-scoped, not store state: this must survive ChatInterface
// remounting (tabbing away and back within the same app session) but reset
// to false whenever the app is actually reopened — a fresh page load/PWA
// launch re-evaluates this module from scratch, which is exactly the
// "was the app closed" signal ChatGPT/Claude-style "always open on a new
// chat" behavior needs. See hydrate() below.
let hasHydratedThisSession = false;

/** The in-flight hydrate(), so concurrent callers await one round trip. */
let hydrationInFlight: Promise<void> | null = null;

// The browser stream is intentionally kept outside React state. Course
// adjustments abort the in-flight build before starting the revised one, so
// two generators never race to update the same conversation.
let activeStreamController: AbortController | null = null;
// Every stream gets a monotonically increasing identity. Aborting a course
// build invalidates its identity before the replacement starts, so callbacks
// already queued by the old SSE reader cannot mutate the new generation.
let activeStreamToken = 0;

// Teaching state is scoped to the canonical conversation. A global counter
// would leak one chat's recent quiz/explanation cadence into another chat.
type TeachingRuntimeState = ReturnType<typeof emptyTeachingRuntimeState>;
const teachingRuntimeByConversation = new Map<string, TeachingRuntimeState>();

function teachingRuntimeFor(conversationId: string): TeachingRuntimeState {
  return teachingRuntimeByConversation.get(conversationId) ?? emptyTeachingRuntimeState();
}

// Module-scoped for the same reason as hasHydratedThisSession above:
// fetchDueReviews() replaces `dueReviews` wholesale from the server on
// every call (e.g. ChatInterface remounting when the learner tabs away and
// back), which would otherwise resurrect a chip the learner just tapped
// away — the schedule on the server doesn't move until the learner
// actually answers a fresh check for that skill. A dismissal only needs to
// survive the current app session, not a real reload.
const dismissedDueReviewSkillIds = new Set<string>();

// Module-scoped identity for "the current new-chat screen", separate from
// activeConversationId. sendMessage() promotes a fresh conversation's
// device-local id to a server-assigned one (see below) partway through
// sending the first message on it — activeConversationId legitimately
// changes at that point even though it's still the exact same screen.
// fetchSessionSummary's staleness guard needs to survive that promotion, so
// it compares against this generation counter (bumped only on a real
// navigation away — a new "new chat", loading a different conversation, or
// the active conversation being deleted) rather than against
// activeConversationId directly.
let newChatScreenGeneration = 0;

interface ChatStore {
  conversations: ChatConversation[];
  activeConversationId: string | null;
  isGenerating: boolean;
  generationProgress: number;
  generationActivity: GenerationActivity;
  courseGenerationState: CourseGenerationState | null;
  courseRevisionUndo: CourseRevisionInput | null;
  isHydrating: boolean;
  // Session-close recap of the conversation just left behind, and the
  // spaced-repetition items due for another look. Both null/empty until
  // fetched — see fetchSessionSummary / fetchDueReviews below.
  sessionSummary: SessionSummary | null;
  dueReviews: DueReviewItem[];
  voiceSessionActive: boolean;
  /**
   * How much of an assistant answer Lyo has actually said out loud.
   *
   * A streamed answer arrives far faster than it can be spoken, so during a
   * live conversation the message is shown only as far as the voice has read,
   * and the clamp is released (null) once the turn is over.
   */
  voiceSpokenText: { messageId: string; text: string } | null;

  createConversation: () => string;
  setActiveConversation: (id: string | null) => void;
  hydrate: () => Promise<void>;
  loadConversation: (id: string) => Promise<void>;
  sendMessage: (
    content: string,
    attachments?: ChatAttachment[],
    options?: SendMessageOptions
  ) => Promise<void>;
  reviseActiveCourse: (adjustment: string | CourseRevisionInput) => Promise<void>;
  undoCourseRevision: () => Promise<void>;
  updateVisual: (conversationId: string, messageId: string, blockId: string, values: Record<string, unknown>) => Promise<boolean>;
  answerCheck: (
    messageId: string,
    blockId: string,
    selectedIndex: number,
    timeTakenMs?: number,
    hintUsed?: boolean
  ) => Promise<CheckAnswerResult | null>;
  deleteConversation: (id: string) => void;
  getActiveConversation: () => ChatConversation | undefined;
  fetchSessionSummary: (conversationId: string, forScreenGeneration: number) => Promise<void>;
  dismissSessionSummary: () => void;
  fetchDueReviews: () => Promise<void>;
  dismissDueReview: (skillId: string) => void;
  setVoiceSessionActive: (active: boolean) => void;
  setVoiceSpokenText: (value: { messageId: string; text: string } | null) => void;
  interruptGeneration: () => void;
}

export const useChatStore = create<ChatStore>((set, get) => ({
  conversations: [],
  activeConversationId: null,
  isGenerating: false,
  generationProgress: 0,
  generationActivity: 'thinking',
  courseGenerationState: null,
  courseRevisionUndo: null,
  isHydrating: false,
  sessionSummary: null,
  dueReviews: [],
  voiceSessionActive: false,
  voiceSpokenText: null,

  setVoiceSessionActive: (active) => set({
    voiceSessionActive: active,
    ...(active ? {} : { voiceSpokenText: null }),
  }),
  setVoiceSpokenText: (value) => set({ voiceSpokenText: value }),
  interruptGeneration: () => {
    activeStreamToken += 1;
    activeStreamController?.abort();
    activeStreamController = null;
    set({
      isGenerating: false,
      generationProgress: 0,
      generationActivity: 'thinking',
      courseGenerationState: null,
    });
  },

  createConversation: () => {
    const state = get();
    const previous = state.conversations.find((c) => c.id === state.activeConversationId);
    // "Session close" = leaving a synced conversation that had at least one
    // graded check to start a new one — the same trigger that already
    // decides when a fresh chat opens (see hydrate()'s ChatGPT/Claude-style
    // note). A local-only conversation was never sent to the server, so
    // there is nothing for the summary endpoint to read.
    const hadAnsweredCheck = previous?.messages.some(
      (m) => m.checkResults && Object.keys(m.checkResults).length > 0
    );

    const id = `local-${generateId()}`;
    const convo: ChatConversation = {
      id,
      title: 'New Chat',
      messages: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    // A genuinely new screen — invalidate any recap fetch still in flight
    // for whatever new-chat screen preceded this one.
    const myScreenGeneration = ++newChatScreenGeneration;
    set((state) => ({
      conversations: [convo, ...state.conversations],
      activeConversationId: id,
      // Starting a fresh chat retires whatever recap was on screen — a
      // stale card from an earlier session must not linger on this new,
      // unrelated one while fetchSessionSummary (below) loads its own.
      sessionSummary: null,
    }));

    if (previous && hadAnsweredCheck && !previous.id.startsWith('local-')) {
      get().fetchSessionSummary(previous.id, myScreenGeneration);
    }

    return id;
  },

  setActiveConversation: (id) => {
    newChatScreenGeneration++;
    set({ activeConversationId: id });
  },

  hydrate: async () => {
    // Concurrent callers await the same work instead of returning early.
    // The early return was fine while every caller only wanted hydration to
    // have been *started*, but a caller that must act **after** it — the
    // seeded opening turn in ChatInterface — would be released while the
    // first call was still in flight. A fresh load ends hydrate() by
    // replacing the conversation list, clearing the active id and opening a
    // new chat, so a turn sent before that lands in a conversation that is
    // then discarded.
    if (hydrationInFlight) return hydrationInFlight;
    hydrationInFlight = (async () => {
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
    })();
    try {
      await hydrationInFlight;
    } finally {
      hydrationInFlight = null;
    }
  },

  loadConversation: async (id) => {
    // Switching conversations — a real navigation away from whatever
    // new-chat screen was previously active. See newChatScreenGeneration.
    // Re-selecting the conversation that's already active (the sidebar
    // re-clicking the current chat, or recoverCanonicalConversation
    // reloading the same id after a stream error) is not a navigation —
    // bumping here would fail an in-flight fetchSessionSummary for this
    // very screen and the recap would never show.
    if (get().activeConversationId !== id) newChatScreenGeneration++;
    if (id.startsWith('local-')) {
      set({ activeConversationId: id });
      return;
    }
    const detail = await api.chat.conversation(id);
    const messages: ChatMessage[] = detail.messages.map((message) => {
      const parsed = message.role === 'user'
        ? parseCanonicalChatContent(message.content)
        : { text: message.content, attachments: [] };
      // Restore structured lesson blocks. Without this a reloaded lesson
      // collapses to the plain-text fallback and its check stops being
      // answerable.
      const blocks = Array.isArray(message.blocks) ? message.blocks : undefined;
      // Graded verdicts ride on the block metadata, so an already-answered
      // check stays answered instead of being offered again after a reload.
      const checkResults = blocks ? extractCheckResults(blocks) : undefined;
      return {
        id: message.id,
        role: message.role,
        content: parsed.text,
        type: 'text',
        blocks,
        checkResults,
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

  sendMessage: async (
    content: string,
    attachments: ChatAttachment[] = [],
    options: SendMessageOptions = {}
  ) => {
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
      generationActivity: options.forcedIntent === 'COURSE' ? 'course' : 'thinking',
      courseGenerationState: options.forcedIntent === 'COURSE'
        ? {
            phase: 'intent',
            progress: 10,
            message: 'Understanding your changes',
          }
        : null,
      courseRevisionUndo:
        options.forcedIntent === 'COURSE' ? s.courseRevisionUndo : null,
    }));

    // The server is the source of truth for history. Sending only the current
    // conversation ID prevents stale or truncated device-local context.
    const history = undefined;

    const aiMessageId = generateId();
    let accumulated = '';

    // True once anything renderable has arrived — prose OR structured blocks.
    // `accumulated` alone is not a sufficient signal now that a turn can carry
    // its whole answer in blocks.
    let receivedContent = false;

    const appendToAiMessage = (text: string) => {
      accumulated += text;
      receivedContent = true;
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
        generationProgress:
          s.generationActivity === 'course'
            ? s.generationProgress
            : Math.min(90, s.generationProgress + 5),
        generationActivity: s.generationActivity === 'course' ? 'course' : 'response',
      }));
    };

    // Merge a patch into the streaming assistant message, creating it if the
    // structured event arrived before any text did.
    const patchAiMessage = (patch: Partial<ChatMessage>) => {
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
                      ...patch,
                      metadata: patch.metadata
                        ? { ...m.metadata, ...patch.metadata }
                        : m.metadata,
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
                content: accumulated,
                type: 'text' as const,
                createdAt: new Date().toISOString(),
                ...patch,
              },
            ],
            updatedAt: new Date().toISOString(),
          };
        }),
      }));
    };

    const attachBlocksToAiMessage = (blocks: ChatBlock[]) => {
      // Blocks are real content. Without this, a lesson delivered purely as
      // blocks looks like an empty response to the completion handler below
      // and gets wiped by the recovery path.
      receivedContent = true;
      patchAiMessage({ blocks });
    };
    const attachActionsToAiMessage = (labels: string[]) => {
      // Same reason as blocks: a turn that produced only follow-up chips is
      // still a real turn, and must not be wiped as an empty response.
      receivedContent = true;
      patchAiMessage({ suggestedActions: labels });
    };

    // Course-generation milestones can arrive before OPEN_CLASSROOM. Ensure
    // those milestones have a real proposal message to render into instead of
    // leaving the only progress surface absent during intent/planning.
    const ensureCourseProposal = (coursePatch: Record<string, unknown> = {}) => {
      set((s) => ({
        conversations: s.conversations.map((c) => {
          if (c.id !== convoId) return c;
          const existing = c.messages.find((m) => m.id === aiMessageId);
          const existingCourse = existing?.metadata?.course as Record<string, unknown> | undefined;
          const course = { ...coursePatch, ...(existingCourse || {}) };
          if (existing) {
            return {
              ...c,
              messages: c.messages.map((m) =>
                m.id === aiMessageId
                  ? {
                      ...m,
                      type: 'course_proposal' as const,
                      metadata: { ...m.metadata, course },
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
                content: accumulated,
                type: 'course_proposal' as const,
                metadata: { course },
                createdAt: new Date().toISOString(),
              },
            ],
            updatedAt: new Date().toISOString(),
          };
        }),
      }));
    };

    const streamToken = ++activeStreamToken;
    const streamStartedAt =
      typeof performance !== 'undefined' ? performance.now() : Date.now();
    let firstVisibleChunkRecorded = false;
    let receivedTextDelta = false;
    let voiceHandoffTarget: string | null = null;
    let voiceHandoffReadyReported = false;

    try {
      activeStreamController = api.chat.stream(
        trimmedContent,
        history,
        (chunk) => {
          if (streamToken !== activeStreamToken) return;
          const block = chunk.block as Record<string, unknown> | undefined;
          const blockContent = block?.content as Record<string, unknown> | undefined;
          if (chunk.type === 'voice_text_segment') {
            // These events are addressed to the message this client is
            // rendering, so they carry its id. The server's own id names a
            // row this client has never seen: anything matching on it — the
            // display following the voice, the guard against speaking a turn
            // twice — silently never matches.
            if (
              typeof chunk.text === 'string'
              && typeof chunk.sequence === 'number'
            ) {
              publishVoiceStreamEvent({
                type: 'voice_text_segment',
                text: chunk.text,
                sequence: chunk.sequence,
                messageId: aiMessageId,
              });
            }
          } else if (chunk.type === 'voice_ready') {
            if (typeof chunk.text === 'string') {
              publishVoiceStreamEvent({
                type: 'voice_ready',
                text: chunk.text,
                messageId: aiMessageId,
                speak: chunk.speak !== false,
              });
              if (
                voiceHandoffTarget
                && !voiceHandoffReadyReported
                && voiceHandoffTarget !== 'course'
              ) {
                voiceHandoffReadyReported = true;
                reportActiveVoiceQuality('voice_handoff_ready', {
                  target: voiceHandoffTarget,
                  stream_elapsed_ms: Math.max(
                    0,
                    Math.round(voiceQualityNow() - streamStartedAt),
                  ),
                }, { conversationId: convoId! });
              }
            }
          } else if (chunk.type === 'voice_incomplete') {
            publishVoiceStreamEvent({
              type: 'voice_incomplete',
              text: typeof chunk.text === 'string' ? chunk.text : '',
              messageId: aiMessageId,
            });
          } else if (chunk.type === 'interaction_contract') {
            patchAiMessage({
              metadata: {
                interactionContract: {
                  mode: chunk.mode,
                  depth: chunk.depth,
                  fastLane: chunk.fast_lane,
                  reasonCode: chunk.reason_code,
                },
              },
            });
            if (options.voiceSession || get().voiceSessionActive) {
              const workflow = typeof chunk.workflow_intent === 'string'
                ? chunk.workflow_intent
                : '';
              if (workflow) {
                voiceHandoffTarget = workflow.toLowerCase();
                reportActiveVoiceQuality('voice_handoff_requested', {
                  target: voiceHandoffTarget,
                  contract_mode: typeof chunk.mode === 'string' ? chunk.mode : 'unknown',
                }, { conversationId: convoId! });
              }
            }
          } else if (chunk.type === 'teaching_policy') {
            teachingRuntimeByConversation.set(
              convoId!,
              reduceTeachingPolicy(teachingRuntimeFor(convoId!), chunk)
            );
          } else if (chunk.type === 'sources') {
            const sources = Array.isArray(chunk.sources) ? chunk.sources : [];
            if (sources.length) {
              patchAiMessage({ metadata: { sources } });
            }
          } else if (chunk.type === 'course_generation') {
            const eventProgress =
              typeof chunk.progress === 'number'
                ? Math.max(0, Math.min(100, chunk.progress))
                : get().generationProgress;
            const phase =
              typeof chunk.phase === 'string' ? chunk.phase : 'planning';
            const message =
              typeof chunk.message === 'string' ? chunk.message : undefined;
            const completedLessons =
              typeof chunk.completed_lessons === 'number'
                ? chunk.completed_lessons
                : undefined;
            const totalLessons =
              typeof chunk.total_lessons === 'number'
                ? chunk.total_lessons
                : undefined;
            const outline = Array.isArray(chunk.outline)
              ? chunk.outline
                  .filter(
                    (item): item is Record<string, unknown> =>
                      Boolean(item) && typeof item === 'object'
                  )
                  .map((item) => ({
                    title: typeof item.title === 'string' ? item.title : 'Lesson',
                    description:
                      typeof item.description === 'string' ? item.description : undefined,
                  }))
              : undefined;

            ensureCourseProposal({
              topic: options.courseContext?.topic || trimmedContent || undefined,
              difficulty: options.courseContext?.difficulty,
            });

            set((state) => ({
              generationActivity: 'course',
              generationProgress: Math.max(state.generationProgress, eventProgress),
              courseGenerationState: {
                phase,
                progress: Math.max(state.generationProgress, eventProgress),
                message,
                completedLessons,
                totalLessons,
                outline: outline ?? state.courseGenerationState?.outline,
              },
            }));
          } else if (
            chunk.type === 'answer'
            || chunk.type === 'text'
            || chunk.type === 'text_delta'
          ) {
            const text = blockContent?.text as string
              || (chunk.payload as Record<string, unknown>)?.text as string
              || (chunk.content as string)
              || '';
            if (text) {
              if (!firstVisibleChunkRecorded) {
                firstVisibleChunkRecorded = true;
                const now =
                  typeof performance !== 'undefined' ? performance.now() : Date.now();
                patchAiMessage({
                  metadata: { clientTtftMs: Math.round(now - streamStartedAt) },
                });
              }

              if (chunk.type === 'text_delta') {
                receivedTextDelta = true;
                appendToAiMessage(text);
              } else if (chunk.type === 'answer' && receivedTextDelta) {
                // The verified final snapshot can correct streamed draft text.
                // Reconcile it in place so copy, history and rendered text agree.
                accumulated = text;
                patchAiMessage({ content: accumulated });
              } else {
                appendToAiMessage(text);
              }
            }
          } else if (chunk.type === 'latency') {
            const metrics =
              chunk.metrics && typeof chunk.metrics === 'object'
                ? chunk.metrics as Record<string, unknown>
                : undefined;
            if (metrics) patchAiMessage({ metadata: { latency: metrics } });
          } else if (chunk.type === 'search_status') {
            set({ generationActivity: 'searching' });
            patchAiMessage({
              metadata: {
                liveSearchStatus:
                  typeof chunk.status === 'string' ? chunk.status : 'searching',
              },
            });
          } else if (chunk.type === 'clarification' && typeof chunk.text === 'string') {
            appendToAiMessage(chunk.text);
          } else if (chunk.type === 'open_classroom') {
            receivedContent = true;
            if (options.voiceSession || get().voiceSessionActive) {
              if (!voiceHandoffReadyReported) {
                voiceHandoffReadyReported = true;
                reportActiveVoiceQuality('voice_handoff_ready', {
                  target: 'classroom',
                  preview: chunk.preview === true,
                  stream_elapsed_ms: Math.max(
                    0,
                    Math.round(voiceQualityNow() - streamStartedAt),
                  ),
                }, { conversationId: convoId! });
              }
            }
            const isPreview = chunk.preview === true;
            const classroomBlock = chunk.block as { content?: Record<string, any> } | undefined;
            const courseData = (classroomBlock?.content?.course || classroomBlock?.content) as
              Record<string, any> | undefined;
            if (courseData) {
              // Normalize difficulty
              if (courseData.difficulty) {
                courseData.difficulty = courseData.difficulty.toLowerCase();
              }
              // Normalize every supported duration alias to minutes.
              const normalizedDuration = normalizeCourseDuration(courseData);
              if (normalizedDuration != null) {
                courseData.estimatedDuration = normalizedDuration;
              }

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
                generationProgress: isPreview
                  ? s.generationProgress
                  : Math.max(s.generationProgress, 80),
                courseGenerationState: isPreview
                  ? (
                      s.courseGenerationState || {
                        phase: 'intent',
                        progress: s.generationProgress,
                        message: 'Understanding your request',
                      }
                    )
                  : {
                      ...(s.courseGenerationState || {}),
                      phase: 'lessons',
                      progress: Math.max(
                        s.courseGenerationState?.progress ?? 0,
                        s.generationProgress,
                        80
                      ),
                      message: 'Creating the course outline',
                      totalLessons: Array.isArray(courseData.modules)
                        ? courseData.modules.length
                        : s.courseGenerationState?.totalLessons,
                    },
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
          } else if (chunk.type === 'smart_blocks') {
            // Structured lesson content. Previously fell through every branch
            // and was silently dropped, so lessons rendered as plain prose.
            const blocks = Array.isArray(chunk.blocks) ? (chunk.blocks as ChatBlock[]) : [];
            if (blocks.length) attachBlocksToAiMessage(blocks);
          } else if (chunk.type === 'actions') {
            const labels = extractActionLabels(chunk);
            if (labels.length) attachActionsToAiMessage(labels);
          } else if (chunk.data) {
            const text = typeof chunk.data === 'string' ? chunk.data : '';
            if (text) appendToAiMessage(text);
          } else if (typeof chunk === 'object' && chunk.content) {
            appendToAiMessage(chunk.content as string);
          }
        },
        () => {
          if (streamToken !== activeStreamToken) return;
          activeStreamController = null;
          if (!receivedContent) {
            recoverCanonicalConversation(convoId!);
          } else {
            set((state) => ({
              isGenerating: false,
              generationProgress: 0,
              generationActivity: 'thinking',
              courseGenerationState:
                state.generationActivity === 'course'
                  ? {
                      ...(state.courseGenerationState || {
                        phase: 'ready',
                        progress: 100,
                      }),
                      phase: 'ready',
                      progress: 100,
                      message: 'Course ready',
                    }
                  : null,
            }));
          }
        },
        () => {
          if (streamToken !== activeStreamToken) return;
          activeStreamController = null;
          if (options.voiceSession || get().voiceSessionActive) {
            reportActiveVoiceQuality('stream_disconnected', {
              stream_elapsed_ms: Math.max(
                0,
                Math.round(voiceQualityNow() - streamStartedAt),
              ),
            }, { conversationId: convoId! });
          }
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
        })),
        options.forcedIntent,
        {
          ...(
            (
              teachingStateSummary(
                teachingRuntimeFor(convoId),
                options.courseContext
              ) as Record<string, unknown> | undefined
            ) ?? {}
          ),
          stream_capabilities: { text_delta: true },
        },
        options.voiceSession || get().voiceSessionActive
          ? {
              active: true,
              transport: 'client_stt_tts',
              locale: options.voiceLocale || (
                typeof navigator !== 'undefined' ? navigator.language : 'auto'
              ),
              turn_id: options.voiceTurnId || userMessage.id,
              interrupted_previous_turn: Boolean(options.voiceInterruptedPreviousTurn),
              delivery: 'segments',
              hands_free: true,
            }
          : undefined
      );
    } catch {
      if (streamToken === activeStreamToken) {
        recoverCanonicalConversation(convoId!);
      }
    }

    async function recoverCanonicalConversation(cId: string) {
      activeStreamController = null;
      set({
        isGenerating: false,
        generationProgress: 0,
        generationActivity: 'thinking',
        courseGenerationState: null,
      });
      const recoveryStartedAt = voiceQualityNow();
      try {
        // A broken SSE connection does not imply the server failed. Reload the
        // canonical thread so a completed answer is recovered without creating
        // a second, device-only response.
        await get().loadConversation(cId);
        if (options.voiceSession || get().voiceSessionActive) {
          reportActiveVoiceQuality('stream_recovered', {
            recovery_ms: Math.max(
              0,
              Math.round(voiceQualityNow() - recoveryStartedAt),
            ),
            canonical_reload: true,
          }, { conversationId: cId });
        }
      } catch {
        if (options.voiceSession || get().voiceSessionActive) {
          reportActiveVoiceQuality('stream_recovery_failed', {
            recovery_ms: Math.max(
              0,
              Math.round(voiceQualityNow() - recoveryStartedAt),
            ),
          }, { conversationId: cId });
        }
        // Preserve the optimistic user turn until the next successful hydrate.
      }
      toast.error('The response was interrupted. Your conversation is saved—please retry.');
    }
  },

  reviseActiveCourse: async (adjustment) => {
    const state = get();
    const conversation = state.getActiveConversation();
    if (!conversation) return;

    const latestCourseMessage = [...conversation.messages]
      .reverse()
      .find((message) => message.role === 'assistant' && message.type === 'course_proposal');
    const latestUserMessage = [...conversation.messages]
      .reverse()
      .find((message) => message.role === 'user');

    const course = latestCourseMessage?.metadata?.course as Record<string, unknown> | undefined;
    const rawTopic =
      (typeof course?.topic === 'string' && course.topic)
      || (typeof course?.title === 'string' && course.title)
      || latestUserMessage?.content
      || '';
    const safeTopic = /(proactive\s+(context|system|nudge)|system\s+nudges?)/i.test(rawTopic)
      ? latestUserMessage?.content || ''
      : rawTopic;
    const previousDifficultyRaw =
      (typeof course?.difficulty === 'string' && course.difficulty)
      || (typeof course?.level === 'string' && course.level)
      || '';
    const previousDifficulty = previousDifficultyRaw.toLowerCase();
    const previousDuration = normalizeCourseDuration(course);
    const undoTarget: CourseRevisionInput = {
      topic: safeTopic || undefined,
      difficulty: ['beginner', 'intermediate', 'advanced'].includes(previousDifficulty)
        ? previousDifficulty as CourseRevisionInput['difficulty']
        : undefined,
      length:
        previousDuration == null
          ? undefined
          : previousDuration <= 20
          ? 'short'
          : previousDuration >= 45
          ? 'deep'
          : 'standard',
    };

    set({
      courseRevisionUndo:
        undoTarget.topic || undoTarget.difficulty || undoTarget.length ? undoTarget : null,
    });

    // Invalidate first: AbortController.abort() can race with callbacks that
    // were already queued by the old stream.
    activeStreamToken += 1;
    if (activeStreamController) {
      activeStreamController.abort();
      activeStreamController = null;
    }

    // A preview from the abandoned build is device-local and incomplete. Drop
    // only that live preview; completed historical course cards remain intact.
    if (state.isGenerating && latestCourseMessage) {
      set((current) => ({
        conversations: current.conversations.map((item) =>
          item.id === conversation.id
            ? {
                ...item,
                messages: item.messages.filter((message) => message.id !== latestCourseMessage.id),
              }
            : item
        ),
        isGenerating: false,
        generationProgress: 0,
        generationActivity: 'thinking',
        courseGenerationState: null,
      }));
    } else {
      set({
        isGenerating: false,
        generationProgress: 0,
        generationActivity: 'thinking',
        courseGenerationState: null,
      });
    }

    let message: string;
    if (typeof adjustment === 'string') {
      const trimmed = adjustment.trim();
      if (!trimmed) return;
      message = trimmed;
    } else {
      const topic = adjustment.topic?.trim() || safeTopic || 'the current topic';
      const level = adjustment.difficulty || 'beginner';
      const lengthLabels: Record<NonNullable<CourseRevisionInput['length']>, string> = {
        short: 'short',
        standard: 'standard length',
        deep: 'a deep dive',
      };
      const styleLabels: Record<NonNullable<CourseRevisionInput['teachingStyle']>, string> = {
        guided: 'guided',
        conversational: 'conversational',
        'practice-heavy': 'practice-heavy',
      };
      const length = lengthLabels[adjustment.length || 'standard'];
      const style = styleLabels[adjustment.teachingStyle || 'guided'];
      message = `Adjust this course to ${topic}. Make it ${level}, ${length}, and ${style}.`;
      if (adjustment.focus?.trim()) {
        message += ` Focus on: ${adjustment.focus.trim()}.`;
      }
    }

    await get().sendMessage(message, [], {
      forcedIntent: 'COURSE',
      courseContext: undoTarget,
    });
  },

  undoCourseRevision: async () => {
    const previous = get().courseRevisionUndo;
    if (!previous) return;
    // Clear first so the restored build does not present an endless undo loop.
    set({ courseRevisionUndo: null });
    await get().reviseActiveCourse(previous);
    set({ courseRevisionUndo: null });
  },

  updateVisual: async (conversationId, messageId, blockId, values) => {
    if (!conversationId || conversationId.startsWith('local-')) return false;
    try {
      const { block } = await api.chat.updateVisual({ conversationId, blockId, values });
      set(state => ({ conversations: state.conversations.map(conversation => conversation.id === conversationId
        ? { ...conversation, messages: conversation.messages.map(message => message.id === messageId
          ? { ...message, blocks: message.blocks?.map(existing => existing.id === blockId ? block : existing) }
          : message) }
        : conversation) }));
      return true;
    } catch {
      return false;
    }
  },

  answerCheck: async (messageId, blockId, selectedIndex, timeTakenMs = 0, hintUsed = false) => {
    const conversationId = get().activeConversationId;
    // A check on a not-yet-synced local conversation has nothing to grade
    // against server-side.
    if (!conversationId || conversationId.startsWith('local-')) {
      toast.error("This chat isn't synced yet—send a message first.");
      return null;
    }

    try {
      const result = await api.chat.checkAnswer({
        conversationId,
        blockId,
        selectedIndex,
        timeTakenMs,
        // Feeds LearnerMastery.hints_used, which damps the mastery gain — an
        // assisted answer recorded as unassisted overstates what was learned.
        hintUsed,
      });

      set((state) => ({
        conversations: state.conversations.map((conversation) =>
          conversation.id === conversationId
            ? {
                ...conversation,
                messages: conversation.messages.map((message) =>
                  message.id === messageId
                    ? {
                        ...message,
                        checkResults: { ...(message.checkResults || {}), [blockId]: result },
                      }
                    : message
                ),
              }
            : conversation
        ),
      }));

      return result;
    } catch {
      // Never fake a verdict on the client: say we couldn't check rather than
      // guessing, which is the whole failure mode this feature exists to fix.
      toast.error("Couldn't check that answer—try again.");
      return null;
    }
  },

  deleteConversation: (id) => {
    if (!id.startsWith('local-')) api.chat.deleteConversation(id).catch(() => {});
    set((state) => {
      // Deleting the active screen is a real navigation away from it too.
      if (state.activeConversationId === id) newChatScreenGeneration++;
      return {
        conversations: state.conversations.filter((c) => c.id !== id),
        activeConversationId:
          state.activeConversationId === id ? null : state.activeConversationId,
      };
    });
  },

  getActiveConversation: () => {
    const state = get();
    return state.conversations.find(
      (c) => c.id === state.activeConversationId
    );
  },

  fetchSessionSummary: async (conversationId, forScreenGeneration) => {
    try {
      const summary = await api.chat.sessionSummary(conversationId);
      // Stale guard: if the learner has already moved past the empty chat
      // this recap was meant for — started yet another new chat, or
      // switched to a different conversation entirely — while the request
      // was in flight, applying it now would attach the wrong session's
      // recap to whatever screen happens to be open. Compared against the
      // screen generation rather than activeConversationId directly: the
      // latter also changes when sendMessage promotes this same screen's
      // device-local id to a server-assigned one, which must NOT count as
      // "moved on" — the recap still belongs on that screen.
      if (newChatScreenGeneration !== forScreenGeneration) return;
      // Nothing was graded in that conversation — a recap with nothing to
      // say is not worth interrupting the new chat for.
      if (summary.nailed.length > 0 || summary.shaky.length > 0) {
        set({ sessionSummary: summary });
      }
    } catch {
      // Best-effort: a recap that fails to load must never block starting
      // (or using) a new conversation.
    }
  },

  dismissSessionSummary: () => set({ sessionSummary: null }),

  fetchDueReviews: async () => {
    try {
      const { items } = await api.chat.dueReviews();
      set({
        dueReviews: items.filter((item) => !dismissedDueReviewSkillIds.has(item.skill_id)),
      });
    } catch {
      // Best-effort — same reasoning as fetchSessionSummary.
    }
  },

  dismissDueReview: (skillId) => {
    dismissedDueReviewSkillIds.add(skillId);
    set((state) => ({
      dueReviews: state.dueReviews.filter((item) => item.skill_id !== skillId),
    }));
  },
}));

