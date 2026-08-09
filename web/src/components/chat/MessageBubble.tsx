'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import {
  Check,
  Copy,
  Download,
  FileText,
  LoaderCircle,
  RotateCcw,
  Square,
  Volume2,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { cn } from '@/lib/utils';
import { api } from '@/lib/api';
import type { ChatMessage } from '@/types';
import CourseGenerationCard from './CourseGenerationCard';
import MascotAvatar from './MascotAvatar';
import { useChatStore } from '@/stores/chat-store';

interface MessageBubbleProps {
  message: ChatMessage;
}

const ASSISTANT_RESPONSE_WIDTH_CLASS = 'w-[99%]';
const RESPONSE_SPEECH_EVENT = 'lyo-response-speech-state';
const MAX_SPEECH_CHUNK_LENGTH = 1100;

type SpeechState = 'idle' | 'loading' | 'playing';

let activeSpeechAudio: HTMLAudioElement | null = null;
let activeSpeechAbort: AbortController | null = null;
let activeSpeechOwner: string | null = null;

function announceSpeechState(owner: string, state: SpeechState) {
  window.dispatchEvent(
    new CustomEvent(RESPONSE_SPEECH_EVENT, { detail: { owner, state } })
  );
}

function stopActiveSpeech() {
  const owner = activeSpeechOwner;
  activeSpeechAbort?.abort();
  activeSpeechAbort = null;
  if (activeSpeechAudio) {
    activeSpeechAudio.pause();
    activeSpeechAudio.src = '';
    activeSpeechAudio = null;
  }
  activeSpeechOwner = null;
  if (owner) announceSpeechState(owner, 'idle');
}

function prepareSpeechText(raw: string) {
  return raw
    .replace(/```[\s\S]*?```/g, ' Code example omitted. ')
    .replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/^\s*[-*+]\s+/gm, '')
    .replace(/^\s*\d+\.\s+/gm, '')
    .replace(/[*_`~>|]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function splitSpeechText(raw: string) {
  const clean = prepareSpeechText(raw);
  if (!clean) return [];

  const sentences = clean.match(/[^.!?]+(?:[.!?]+|$)/g) ?? [clean];
  const chunks: string[] = [];
  let current = '';

  const pushLongSentence = (sentence: string) => {
    let remaining = sentence.trim();
    while (remaining.length > MAX_SPEECH_CHUNK_LENGTH) {
      const candidate = remaining.slice(0, MAX_SPEECH_CHUNK_LENGTH + 1);
      const splitAt = Math.max(candidate.lastIndexOf(' '), MAX_SPEECH_CHUNK_LENGTH / 2);
      chunks.push(remaining.slice(0, splitAt).trim());
      remaining = remaining.slice(splitAt).trim();
    }
    return remaining;
  };

  for (const sentence of sentences) {
    const part = sentence.trim();
    if (!part) continue;
    if (part.length > MAX_SPEECH_CHUNK_LENGTH) {
      if (current) chunks.push(current);
      current = pushLongSentence(part);
    } else if (!current || `${current} ${part}`.length <= MAX_SPEECH_CHUNK_LENGTH) {
      current = current ? `${current} ${part}` : part;
    } else {
      chunks.push(current);
      current = part;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

function playAudioBlob(blob: Blob, owner: string, signal: AbortSignal) {
  return new Promise<void>((resolve, reject) => {
    if (signal.aborted) {
      reject(new DOMException('Speech cancelled', 'AbortError'));
      return;
    }

    const url = URL.createObjectURL(blob);
    const audio = new Audio(url);
    activeSpeechAudio = audio;
    announceSpeechState(owner, 'playing');

    const cleanup = () => {
      URL.revokeObjectURL(url);
      if (activeSpeechAudio === audio) activeSpeechAudio = null;
    };
    const abort = () => {
      audio.pause();
      cleanup();
      reject(new DOMException('Speech cancelled', 'AbortError'));
    };

    signal.addEventListener('abort', abort, { once: true });
    audio.onended = () => {
      signal.removeEventListener('abort', abort);
      cleanup();
      resolve();
    };
    audio.onerror = () => {
      signal.removeEventListener('abort', abort);
      cleanup();
      reject(new Error('Audio playback failed'));
    };
    audio.play().catch((error) => {
      signal.removeEventListener('abort', abort);
      cleanup();
      reject(error);
    });
  });
}

interface ResponseActionButtonProps {
  label: string;
  icon: React.ReactNode;
  onClick: () => void;
  active?: boolean;
  disabled?: boolean;
}

function ResponseActionButton({
  label,
  icon,
  onClick,
  active = false,
  disabled = false,
}: ResponseActionButtonProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={cn(
        'inline-flex min-h-9 shrink-0 items-center gap-1.5 rounded-xl border px-2.5 py-2',
        'text-[11px] font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-lyo-400/70',
        active
          ? 'border-lyo-400/35 bg-lyo-500/15 text-lyo-200'
          : 'border-white/[0.08] bg-white/[0.035] text-white/55 hover:bg-white/[0.08] hover:text-white/90',
        disabled && 'cursor-not-allowed opacity-35 hover:bg-white/[0.035] hover:text-white/55'
      )}
      aria-pressed={active || undefined}
      aria-label={label}
      title={label}
    >
      {icon}
      <span>{label}</span>
    </button>
  );
}

const markdownComponents = {
  // Paragraphs
  p: ({ children }: { children?: React.ReactNode }) => (
    <p className="mb-4 last:mb-0 leading-7 text-white/85">{children}</p>
  ),
  // Headings
  h1: ({ children }: { children?: React.ReactNode }) => (
    <h1 className="mb-3 mt-7 text-2xl font-bold tracking-tight text-white first:mt-0">{children}</h1>
  ),
  h2: ({ children }: { children?: React.ReactNode }) => (
    <h2 className="mb-3 mt-6 text-xl font-semibold tracking-tight text-white first:mt-0">{children}</h2>
  ),
  h3: ({ children }: { children?: React.ReactNode }) => (
    <h3 className="mb-2 mt-5 text-lg font-semibold text-white/95 first:mt-0">{children}</h3>
  ),
  // Lists
  ul: ({ children }: { children?: React.ReactNode }) => (
    <ul className="mb-4 list-disc space-y-2 pl-6 marker:text-lyo-400">{children}</ul>
  ),
  ol: ({ children }: { children?: React.ReactNode }) => (
    <ol className="mb-4 list-decimal space-y-2 pl-6 marker:font-semibold marker:text-lyo-300">{children}</ol>
  ),
  li: ({ children }: { children?: React.ReactNode }) => (
    <li className="pl-1 leading-7 text-white/80">{children}</li>
  ),
  // Bold / italic
  strong: ({ children }: { children?: React.ReactNode }) => (
    <strong className="font-semibold text-white">{children}</strong>
  ),
  em: ({ children }: { children?: React.ReactNode }) => (
    <em className="italic text-white/70">{children}</em>
  ),
  // Code
  code: ({ inline, children }: { inline?: boolean; children?: React.ReactNode }) => {
    if (inline) {
      return (
        <code className="rounded-md border border-white/[0.08] bg-black/30 px-1.5 py-0.5 font-mono text-[0.85em] text-lyo-200">
          {children}
        </code>
      );
    }
    return (
      <code className="block w-full overflow-x-auto rounded-2xl border border-white/10 bg-black/45 p-4 font-mono text-sm leading-6 text-lyo-200">
        {children}
      </code>
    );
  },
  pre: ({ children }: { children?: React.ReactNode }) => (
    <pre className="mb-5 overflow-hidden rounded-2xl">{children}</pre>
  ),
  // Blockquote
  blockquote: ({ children }: { children?: React.ReactNode }) => (
    <blockquote className="my-5 rounded-r-xl border-l-2 border-lyo-400 bg-lyo-500/[0.06] py-2 pl-4 pr-3 italic text-white/65">
      {children}
    </blockquote>
  ),
  // HR
  hr: () => <hr className="border-white/10 my-4" />,
  a: ({ href, children }: { href?: string; children?: React.ReactNode }) => (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      className="font-medium text-lyo-300 underline decoration-lyo-400/40 underline-offset-4 hover:text-lyo-200"
    >
      {children}
    </a>
  ),
  table: ({ children }: { children?: React.ReactNode }) => (
    <div className="mb-5 w-full overflow-x-auto rounded-2xl border border-white/10">
      <table className="min-w-full border-collapse text-left text-sm">{children}</table>
    </div>
  ),
  thead: ({ children }: { children?: React.ReactNode }) => (
    <thead className="bg-white/[0.07] text-white/90">{children}</thead>
  ),
  th: ({ children }: { children?: React.ReactNode }) => (
    <th className="whitespace-nowrap border-b border-white/10 px-3 py-2.5 font-semibold">{children}</th>
  ),
  td: ({ children }: { children?: React.ReactNode }) => (
    <td className="border-b border-white/[0.06] px-3 py-2.5 align-top text-white/75 last:border-b-0">{children}</td>
  ),
};

export default function MessageBubble({ message }: MessageBubbleProps) {
  const isUser = message.role === 'user';
  const [hovered, setHovered] = useState(false);
  const [copied, setCopied] = useState(false);
  const [speechState, setSpeechState] = useState<SpeechState>('idle');
  const attachments = message.attachments ?? [];
  
  const { isGenerating, generationProgress, getActiveConversation, sendMessage } = useChatStore();

  useEffect(() => {
    const onSpeechState = (event: Event) => {
      const detail = (event as CustomEvent<{ owner: string; state: SpeechState }>).detail;
      if (detail.owner === message.id) setSpeechState(detail.state);
    };
    window.addEventListener(RESPONSE_SPEECH_EVENT, onSpeechState);
    return () => {
      window.removeEventListener(RESPONSE_SPEECH_EVENT, onSpeechState);
      if (activeSpeechOwner === message.id) stopActiveSpeech();
    };
  }, [message.id]);

  // Helper to extract OPEN_CLASSROOM JSON block from assistant messages.
  // Uses string-aware brace counting — a lazy regex stops at the FIRST '}',
  // which breaks on the (always-nested) payload and left raw JSON on screen.
  const getOpenClassroomData = (content: string) => {
    if (isUser) return null;

    const marker = content.search(/\{\s*"type"\s*:\s*"OPEN_CLASSROOM"/i);
    if (marker === -1) return null;

    let depth = 0;
    let end = -1;
    let inString = false;
    let escaped = false;
    for (let i = marker; i < content.length; i++) {
      const ch = content[i];
      if (escaped) { escaped = false; continue; }
      if (ch === '\\') { escaped = true; continue; }
      if (ch === '"') { inString = !inString; continue; }
      if (inString) continue;
      if (ch === '{') depth++;
      else if (ch === '}') {
        depth--;
        if (depth === 0) { end = i; break; }
      }
    }
    // Unbalanced braces = the command is still streaming in; wait for more.
    if (end === -1) return null;

    {
      try {
        const parsed = JSON.parse(content.slice(marker, end + 1));
        const cleanText = (content.slice(0, marker) + content.slice(end + 1))
          .replace(/```json/gi, '')
          .replace(/```/g, '')
          .trim();
        const courseData = parsed.payload?.course || parsed.course;
        
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
        }
        
        return {
          course: courseData,
          cleanText
        };
      } catch {
        // Mid-stream the braces can balance before the JSON is complete —
        // expected transient state; the card renders once the stream finishes.
      }
    }
    return null;
  };

  const ocData = getOpenClassroomData(message.content);
  const displayContent = ocData ? ocData.cleanText : message.content;
  const displayCourse = ocData ? ocData.course : (message.type === 'course_proposal' ? message.metadata?.course : null);
  const displayType = ocData ? 'course_proposal' : message.type;

  // Determine if this specific card is active and currently generating in the store
  const activeConvo = getActiveConversation();
  const isLatestMessage = activeConvo?.messages[activeConvo.messages.length - 1]?.id === message.id;
  const isCurrentlyGeneratingThis = isLatestMessage && isGenerating && displayType === 'course_proposal';
  const handleCopy = async () => {
    await navigator.clipboard.writeText(displayContent);
    setCopied(true);
    setTimeout(() => setCopied(false), 1800);
  };

  const handleListen = async () => {
    if (activeSpeechOwner === message.id) {
      stopActiveSpeech();
      return;
    }

    stopActiveSpeech();
    const chunks = splitSpeechText(displayContent);
    if (chunks.length === 0) return;

    const controller = new AbortController();
    activeSpeechOwner = message.id;
    activeSpeechAbort = controller;
    announceSpeechState(message.id, 'loading');

    try {
      for (const chunk of chunks) {
        const audio = await api.tts.synthesize(chunk, controller.signal);
        await playAudioBlob(audio, message.id, controller.signal);
      }
      if (activeSpeechOwner === message.id) {
        activeSpeechOwner = null;
        activeSpeechAbort = null;
        announceSpeechState(message.id, 'idle');
      }
    } catch (error) {
      if ((error as Error).name !== 'AbortError') {
        stopActiveSpeech();
        toast.error('Lyo voice is temporarily unavailable.');
      }
    }
  };

  const handleRegenerate = () => {
    if (!isLatestMessage || isGenerating) return;
    void sendMessage('Please try that again with a fresh, clearer explanation.');
  };

  const handleSave = () => {
    const markdown = `# Lyo response\n\n${displayContent.trim()}\n`;
    const blob = new Blob([markdown], { type: 'text/markdown;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `lyo-response-${message.id.slice(0, 8)}.md`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
    toast.success('Response saved.');
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, ease: 'easeOut' }}
      className={cn(
        'flex w-full group',
        isUser ? 'flex-row-reverse items-end gap-3 px-4' : 'flex-col'
      )}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {/* Header – assistant only (mirrors iOS: mascot + "Lyo" name) */}
      {!isUser && (
        <div className={cn('flex items-center gap-2 mb-1.5 mx-auto', ASSISTANT_RESPONSE_WIDTH_CLASS)}>
          <MascotAvatar
            thinking={isLatestMessage && isGenerating}
            size={32}
          />
          <span className="text-xs font-bold text-white/90">Lyo</span>
        </div>
      )}

      {/* Bubble */}
      <div
        className={cn(
          'relative flex flex-col gap-1',
          isUser
            ? 'max-w-[78%] md:max-w-[68%] items-end'
            : cn(ASSISTANT_RESPONSE_WIDTH_CLASS, 'max-w-none mx-auto items-start')
        )}
      >
        {/* Course proposal card */}
        {displayType === 'course_proposal' && !isUser && (
          <CourseGenerationCard
            course={displayCourse as any}
            isGenerating={isCurrentlyGeneratingThis}
            generationProgress={generationProgress}
          />
        )}

        {/* Regular text bubble */}
        {(displayType === 'text' || !displayType) && (displayContent || (isUser && attachments.length > 0)) && (
          <div
            className={cn(
              'rounded-2xl text-sm leading-relaxed',
              !isUser && 'w-full',
              isUser
                ? 'bg-gradient-to-br from-accent-purple to-lyo-500 px-4 py-3 text-white rounded-br-sm shadow-lg shadow-lyo-900/30'
                : 'rounded-[24px] border border-white/[0.11] bg-gradient-to-br from-white/[0.075] via-white/[0.045] to-lyo-950/20 px-5 py-5 text-white/80 shadow-[0_18px_55px_rgba(0,0,0,0.18)] backdrop-blur-md sm:px-7 sm:py-6 md:px-8'
            )}
          >
            {isUser ? (
              <div className="space-y-2.5">
                {attachments.length > 0 && (
                  <div className={cn(
                    'grid gap-2',
                    attachments.length > 1 ? 'grid-cols-2' : 'grid-cols-1'
                  )}>
                    {attachments.map((attachment) => (
                      <a
                        key={`${attachment.url}-${attachment.name}`}
                        href={attachment.url}
                        target="_blank"
                        rel="noreferrer"
                        className="block min-w-0 rounded-xl overflow-hidden bg-black/20 border border-white/15 hover:border-white/30 transition-colors"
                        title={`Open ${attachment.name}`}
                      >
                        {attachment.kind === 'image' ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={attachment.url}
                            alt={attachment.name}
                            className="w-full max-h-64 object-cover"
                          />
                        ) : (
                          <span className="flex items-center gap-2 px-3 py-3 min-w-0">
                            <FileText className="w-5 h-5 shrink-0" />
                            <span className="text-xs font-medium truncate">{attachment.name}</span>
                          </span>
                        )}
                      </a>
                    ))}
                  </div>
                )}
                {displayContent && <p className="whitespace-pre-wrap">{displayContent}</p>}
              </div>
            ) : (
              <div className="w-full">
                <div className="max-w-[88ch] text-[15px] sm:text-base">
                  <ReactMarkdown remarkPlugins={[remarkGfm]} components={markdownComponents}>
                    {displayContent}
                  </ReactMarkdown>
                </div>

                <div className="mt-5 flex items-center gap-1.5 overflow-x-auto border-t border-white/[0.08] pt-3 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
                  <ResponseActionButton
                    label={copied ? 'Copied' : 'Copy'}
                    icon={copied ? <Check className="h-3.5 w-3.5 text-emerald-300" /> : <Copy className="h-3.5 w-3.5" />}
                    onClick={() => void handleCopy()}
                  />
                  <ResponseActionButton
                    label={speechState === 'playing' ? 'Stop' : 'Listen'}
                    icon={
                      speechState === 'loading'
                        ? <LoaderCircle className="h-3.5 w-3.5 animate-spin" />
                        : speechState === 'playing'
                          ? <Square className="h-3.5 w-3.5 fill-current" />
                          : <Volume2 className="h-3.5 w-3.5" />
                    }
                    active={speechState !== 'idle'}
                    onClick={() => void handleListen()}
                  />
                  <ResponseActionButton
                    label="Try again"
                    icon={<RotateCcw className="h-3.5 w-3.5" />}
                    onClick={handleRegenerate}
                    disabled={!isLatestMessage || isGenerating}
                  />
                  <ResponseActionButton
                    label="Save"
                    icon={<Download className="h-3.5 w-3.5" />}
                    onClick={handleSave}
                  />
                  <span className="ml-auto shrink-0 pl-2 text-[10px] text-white/25">
                    {new Date(message.createdAt).toLocaleTimeString([], {
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </span>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Flashcard carousel placeholder */}
        {message.type === 'flashcard' && !isUser && (
          <div className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm p-4 w-72">
            <p className="text-sm text-white/60 mb-2 font-medium">Flashcard Set</p>
            <div className="rounded-xl bg-gradient-to-br from-lyo-600/20 to-accent-purple/20 border border-lyo-500/20 p-4 text-center text-white/80 text-sm">
              {message.content}
            </div>
          </div>
        )}

        {/* Quiz inline placeholder */}
        {message.type === 'quiz' && !isUser && (
          <div className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm p-4 w-80">
            <p className="text-sm text-white/60 mb-2 font-medium">Quick Quiz</p>
            <div className="text-white/80 text-sm">
              <ReactMarkdown remarkPlugins={[remarkGfm]} components={markdownComponents}>
                {message.content}
              </ReactMarkdown>
            </div>
          </div>
        )}

        {/* User timestamp. Assistant metadata lives in the persistent action bar. */}
        {isUser && (
          <div
            className={cn(
              'flex flex-row-reverse items-center gap-2 px-1 transition-opacity duration-200',
              hovered ? 'opacity-100' : 'opacity-40'
            )}
          >
            <span className="text-[11px] text-white/30">
              {new Date(message.createdAt).toLocaleTimeString([], {
                hour: '2-digit',
                minute: '2-digit',
              })}
            </span>
          </div>
        )}
      </div>
    </motion.div>
  );
}
