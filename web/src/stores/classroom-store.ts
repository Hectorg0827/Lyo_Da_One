'use client';

import { create } from 'zustand';

// ─── Wire types (match backend lyo_app/ai_classroom exactly) ─────────────────

export interface QuizOption {
  id: string;
  label: string;
  is_correct?: boolean;
  feedback_correct?: string | null;
  feedback_incorrect?: string | null;
}

export interface ClassroomComponent {
  component_id: string;
  type: string; // "TeacherMessage" | "StudentPrompt" | "QuizCard" | "CTAButton" | ...
  text?: string;
  label?: string;
  student_name?: string;
  question?: string;
  options?: QuizOption[];
  action_intent?: string;
  concept_id?: string | null;
  [key: string]: unknown;
}

/** One director turn inside a TeacherMessage's JSON script. */
export interface DirectorTurn {
  type: 'speech' | 'user_prompt' | 'lyo_state' | 'board' | 'ambient' | 'pause' | 'session_end';
  speaker?: string;
  text?: string;
  input?: 'voice' | 'tap';
  options?: string[];
  beat_seconds?: number;
  state?: string;
  action?: 'write' | 'draw' | 'highlight';
  content?: string;
  seconds?: number;
  homework?: string;
  next_hook?: string;
  lyo_state?: string;
}

/** An item in the visible classroom feed. */
export interface FeedItem {
  id: string;
  kind: 'speech' | 'prompt' | 'board' | 'quiz' | 'session_end' | 'info';
  speaker?: string;
  text?: string;
  options?: string[];        // prompt options
  quiz?: ClassroomComponent; // quiz card
  answered?: string;         // chosen option / answer label
  wasCorrect?: boolean;
  homework?: string;
  nextHook?: string;
}

type Status = 'idle' | 'connecting' | 'live' | 'ended' | 'error';

interface ClassroomStore {
  status: Status;
  topic: string;
  feed: FeedItem[];
  lyoState: string;           // reading | thinking | celebrating | ...
  boardLines: string[];       // whiteboard content (latest at end)
  waitingForScene: boolean;   // between scenes / generation in flight
  canContinue: boolean;
  error: string | null;

  connect: (topic: string) => void;
  disconnect: () => void;
  answerPrompt: (itemId: string, option: string) => void;
  answerQuiz: (itemId: string, option: QuizOption) => void;
  askQuestion: (text: string) => void;
  signal: (kind: 'confused' | 'too_easy') => void;
  continueLesson: () => void;
}

// ─── Internals (module-level, not in state) ──────────────────────────────────

let ws: WebSocket | null = null;
let turnQueue: DirectorTurn[] = [];
let playing = false;
let playTimer: ReturnType<typeof setTimeout> | null = null;
let idCounter = 0;
const nextId = () => `cf_${++idCounter}`;

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.lyoapp.com';

function wsUrl(topic: string, token: string | null): string {
  const base = API_URL.replace(/^http/, 'ws').replace(/\/$/, '');
  const params = new URLSearchParams({ session_id: topic, topic });
  // Logged-in learners get the full mastery loop; guests still get the class.
  if (token) params.set('token', token);
  else params.set('api_key', 'web_guest');
  return `${base}/api/v1/classroom/ws/connect?${params}`;
}

/** Reading-time pacing for a speech turn. */
function speechDelay(text: string): number {
  return Math.min(Math.max(text.length * 32, 1200), 6500);
}

export const useClassroomStore = create<ClassroomStore>((set, get) => {
  // ── Turn player: reveals director turns one by one with natural pacing ──

  function stopPlayer() {
    playing = false;
    if (playTimer) { clearTimeout(playTimer); playTimer = null; }
  }

  function playNext() {
    if (!playing) return;
    const turn = turnQueue.shift();
    if (!turn) { playing = false; return; }

    switch (turn.type) {
      case 'speech': {
        const text = (turn.text ?? '').trim();
        if (text) {
          set((s) => ({
            feed: [...s.feed, { id: nextId(), kind: 'speech', speaker: turn.speaker || 'Teacher', text }],
          }));
          playTimer = setTimeout(playNext, speechDelay(text));
          return;
        }
        break;
      }
      case 'user_prompt': {
        const text = (turn.text ?? '').trim();
        set((s) => ({
          feed: [...s.feed, {
            id: nextId(), kind: 'prompt', speaker: turn.speaker || 'Teacher',
            text, options: turn.options?.length ? turn.options : ['Yes', 'No'],
          }],
        }));
        // Pause the player — resumes when the learner answers (or the
        // classmate-jumps-in timeout below fires).
        playing = false;
        const beat = (turn.beat_seconds ?? 5) + 6;
        playTimer = setTimeout(() => {
          const st = get();
          const last = st.feed[st.feed.length - 1];
          if (last?.kind === 'prompt' && !last.answered) resumePlayer();
        }, beat * 1000);
        return;
      }
      case 'lyo_state':
        if (turn.state) set({ lyoState: turn.state });
        break;
      case 'board': {
        const content = (turn.content ?? '').trim();
        if (content) {
          set((s) => ({
            boardLines: [...s.boardLines.slice(-4), content],
            feed: [...s.feed, { id: nextId(), kind: 'board', text: content }],
          }));
          playTimer = setTimeout(playNext, 2200);
          return;
        }
        break;
      }
      case 'pause':
        playTimer = setTimeout(playNext, Math.min((turn.seconds ?? 1), 5) * 1000);
        return;
      case 'session_end':
        set((s) => ({
          feed: [...s.feed, {
            id: nextId(), kind: 'session_end',
            homework: turn.homework, nextHook: turn.next_hook,
          }],
          lyoState: turn.lyo_state || 'celebrating',
          canContinue: true,
        }));
        break;
      default:
        break; // ambient etc. — no visual
    }
    // Zero-cost turns fall through to the next immediately.
    playTimer = setTimeout(playNext, 60);
  }

  function resumePlayer() {
    if (playing) return;
    playing = true;
    playNext();
  }

  function enqueueTurns(turns: DirectorTurn[]) {
    turnQueue.push(...turns);
    set({ waitingForScene: false });
    resumePlayer();
  }

  // ── Incoming component handling ──

  function handleComponent(comp: ClassroomComponent) {
    switch (comp.type) {
      case 'TeacherMessage': {
        const text = (comp.text ?? '').trim();
        if (!text) return;
        if (text.startsWith('[')) {
          try {
            const turns = JSON.parse(text) as DirectorTurn[];
            if (Array.isArray(turns)) { enqueueTurns(turns); return; }
          } catch { /* fall through to plain text */ }
        }
        enqueueTurns([{ type: 'speech', speaker: 'Teacher', text }]);
        break;
      }
      case 'StudentPrompt':
        enqueueTurns([{ type: 'speech', speaker: comp.student_name || 'Classmate', text: comp.text ?? '' }]);
        break;
      case 'QuizCard':
        set((s) => ({
          feed: [...s.feed, { id: nextId(), kind: 'quiz', quiz: comp }],
          waitingForScene: false,
        }));
        break;
      case 'CTAButton':
        if ((comp.action_intent ?? 'continue') === 'continue') {
          set({ canContinue: true, waitingForScene: false });
        }
        break;
      default:
        break;
    }
  }

  function handleMessage(raw: string) {
    let msg: Record<string, unknown>;
    try { msg = JSON.parse(raw); } catch { return; }
    const et = (msg.event_type as string) || (msg.type as string) || '';

    switch (et) {
      case 'component_render': {
        const comp = (msg.component ?? (msg.data as Record<string, unknown>)?.component ?? msg.data) as ClassroomComponent | undefined;
        if (comp?.type) handleComponent(comp);
        break;
      }
      case 'scene_start':
        set({ waitingForScene: true, canContinue: false });
        break;
      case 'scene_complete':
        set({ waitingForScene: false });
        break;
      case 'error': {
        const detail = (msg.message as string) || 'The classroom hit a snag.';
        set((s) => ({ feed: [...s.feed, { id: nextId(), kind: 'info', text: detail }] }));
        break;
      }
      default:
        break; // system_state, scene_stream envelope, typing indicators…
    }
  }

  function sendAction(actionIntent: string, componentId: string, answerData?: Record<string, unknown>) {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    const payload: Record<string, unknown> = {
      event_type: 'user_action',
      session_id: get().topic,
      action_intent: actionIntent,
      component_id: componentId,
      timestamp: new Date().toISOString(),
    };
    if (answerData) payload.answer_data = answerData;
    ws.send(JSON.stringify(payload));
  }

  /** Persist quiz outcomes to the shared mastery profile (same loop as iOS). */
  async function traceQuiz(skill: string, itemId: string, correct: boolean) {
    try {
      const token = localStorage.getItem('lyo_token');
      if (!token) return;
      const claims = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      const learnerId = String(claims.sub ?? claims.user_id ?? '');
      if (!learnerId) return;
      await fetch(`${API_URL}/api/v1/personalization/trace`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({
          learner_id: learnerId,
          skill_id: skill,
          item_id: itemId,
          correct,
          time_taken_seconds: 15,
        }),
      });
    } catch { /* mastery tracing must never disturb the lesson */ }
  }

  return {
    status: 'idle',
    topic: '',
    feed: [],
    lyoState: 'reading',
    boardLines: [],
    waitingForScene: false,
    canContinue: false,
    error: null,

    connect: (topic: string) => {
      get().disconnect();
      const token = typeof window !== 'undefined' ? localStorage.getItem('lyo_token') : null;
      idCounter = 0;
      turnQueue = [];
      set({
        status: 'connecting', topic, feed: [], boardLines: [],
        lyoState: 'reading', waitingForScene: true, canContinue: false, error: null,
      });

      const socket = new WebSocket(wsUrl(topic, token));
      ws = socket;
      socket.onopen = () => set({ status: 'live' });
      socket.onmessage = (e) => handleMessage(String(e.data));
      socket.onerror = () => {
        if (ws === socket) set({ status: 'error', error: 'Connection to the classroom failed.' });
      };
      socket.onclose = () => {
        if (ws === socket) {
          const st = get();
          set({ status: st.feed.length > 0 ? 'ended' : st.status === 'error' ? 'error' : 'ended' });
          ws = null;
        }
      };
    },

    disconnect: () => {
      stopPlayer();
      turnQueue = [];
      if (ws) { try { ws.close(); } catch { /* noop */ } ws = null; }
      set({ status: 'idle' });
    },

    answerPrompt: (itemId, option) => {
      set((s) => ({
        feed: s.feed.map((f) => (f.id === itemId ? { ...f, answered: option } : f)),
        lyoState: 'listening',
      }));
      sendAction('user_message', itemId, { message: option });
      resumePlayer();
    },

    answerQuiz: (itemId, option) => {
      const item = get().feed.find((f) => f.id === itemId);
      const quiz = item?.quiz;
      if (!quiz || item?.answered) return;
      const correct = option.is_correct === true;
      set((s) => ({
        feed: s.feed.map((f) =>
          f.id === itemId ? { ...f, answered: option.label, wasCorrect: correct } : f),
        lyoState: correct ? 'celebrating' : 'thinking',
      }));
      sendAction('quiz_answer', quiz.component_id, {
        selected_option_id: option.id,
        selected_option_label: option.label,
      });
      void traceQuiz(quiz.concept_id || get().topic, quiz.component_id, correct);
      resumePlayer();
    },

    askQuestion: (text: string) => {
      const trimmed = text.trim();
      if (!trimmed) return;
      set((s) => ({
        feed: [...s.feed, { id: nextId(), kind: 'speech', speaker: 'You', text: trimmed }],
        waitingForScene: true,
        lyoState: 'curious',
      }));
      sendAction('user_message', 'web_ask', { message: trimmed });
    },

    signal: (kind) => {
      set({ waitingForScene: true, lyoState: kind === 'confused' ? 'thinking' : 'curious' });
      sendAction(kind === 'confused' ? 'confused' : 'too_easy', 'web_signal');
    },

    continueLesson: () => {
      set({ canContinue: false, waitingForScene: true });
      sendAction('continue', 'web_continue');
    },
  };
});
