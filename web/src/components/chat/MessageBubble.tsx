'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import ReactMarkdown from 'react-markdown';
import {
  Check, Copy, Download, FileText, Globe2, BookOpen, Sparkles,
  LoaderCircle, RotateCcw, Square, Volume2,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import type { ChatMessage } from '@/types';
import CourseGenerationCard from './CourseGenerationCard';
import MascotAvatar from './MascotAvatar';
import BlockRenderer from './blocks/BlockRenderer';
import { canRenderBlock } from './blocks/can-render';
import {
  markdownComponents,
  MARKDOWN_MATH_PLUGINS,
  normalizeLatexDelimiters,
} from './markdown-config';
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

function safeWebUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.toString() : null;
  } catch { return null; }
}

export default function MessageBubble({ message }: MessageBubbleProps) {
  const isUser = message.role === 'user';
  const [hovered, setHovered] = useState(false);
  const [copied, setCopied] = useState(false);
  const [speechState, setSpeechState] = useState<SpeechState>('idle');
  const attachments = message.attachments ?? [];
  // Source and interaction events are stored on message metadata by the current
  // streaming client; do not overwrite the newer teaching, voice or visual contracts.
  const sourceItems = Array.isArray(message.metadata?.sources)
    ? message.metadata.sources.filter(
        (value): value is Record<string, unknown> =>
          value !== null && typeof value === 'object' && !Array.isArray(value)
      ).slice(0, 6)
    : [];
  const rawContract = message.metadata?.interactionContract;
  const contract = rawContract && typeof rawContract === 'object'
    ? rawContract as Record<string, unknown> : null;
  const workspaceLabel = contract?.depth === 'deep' ? 'Deep explanation'
    : contract?.mode === 'COMPARE' ? 'Comparison'
    : contract?.mode === 'ANALYZE' ? 'Analysis'
    : contract?.mode === 'EXPLAIN' ? 'Explanation'
    : contract?.mode === 'SEARCH' ? 'Grounded search' : null;
  
  const {
    isGenerating,
    generationProgress,
    courseGenerationState,
    getActiveConversation,
    sendMessage,
  } = useChatStore();
  const voiceSpokenText = useChatStore((state) => state.voiceSpokenText);

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



  // A structured lesson renders as blocks; message.content still holds the
  // plain-text version of the same lesson. Only hide that fallback when the
  // blocks will actually show something — otherwise a turn whose blocks this
  // client cannot render would collapse to an empty bubble.
  const supplementalBlocks =
    !isUser && Array.isArray(message.blocks)
      ? message.blocks.filter(
          (block) => block.type === 'interactive' && block.subtype === 'sourceNavigator'
        )
      : [];
  const primaryBlocks =
    !isUser && Array.isArray(message.blocks)
      ? message.blocks.filter(
          (block) => !(block.type === 'interactive' && block.subtype === 'sourceNavigator')
        )
      : [];
  const hasBlocks = primaryBlocks.some(canRenderBlock);

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
  // While Lyo is reading this answer aloud, show only as far as it has read.
  // The written answer arrives far ahead of the voice, and seeing it whole
  // before the first word is spoken leaves nothing to follow.
  const spokenSoFar = voiceSpokenText?.messageId === message.id
    ? voiceSpokenText.text
    : null;
  const writtenContent = ocData ? ocData.cleanText : message.content;
  const displayContent = !isUser && spokenSoFar !== null ? spokenSoFar : writtenContent;
  const normalizedAssistantContent = isUser ? displayContent : normalizeLatexDelimiters(displayContent);
  const displayCourse = ocData ? ocData.course : (message.type === 'course_proposal' ? message.metadata?.course : null);
  const displayType = ocData ? 'course_proposal' : message.type;

  // Determine if this specific card is active and currently generating in the store
  const activeConvo = getActiveConversation();
  const isLatestMessage = activeConvo?.messages[activeConvo.messages.length - 1]?.id === message.id;
  const isCurrentlyGeneratingThis = isLatestMessage && isGenerating && displayType === 'course_proposal';
  const handleCopy = async () => {
    await navigator.clipboard.writeText(writtenContent);
    setCopied(true);
    setTimeout(() => setCopied(false), 1800);
  };

  const handleListen = async () => {
    if (activeSpeechOwner === message.id) {
      stopActiveSpeech();
      return;
    }

    stopActiveSpeech();
    const chunks = splitSpeechText(writtenContent);
    if (chunks.length === 0) return;

    const controller = new AbortController();
    activeSpeechOwner = message.id;
    activeSpeechAbort = controller;
    announceSpeechState(message.id, 'loading');

    try {
      for (const chunk of chunks) {
        const audio = await api.tts.synthesizeStream(chunk, { signal: controller.signal });
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
    const markdown = `# Lyo response\n\n${writtenContent.trim()}\n`;
    const blob = new Blob([markdown], { type: 'text/markdown;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `lyo-response-${message.id.slice(0, 8)}.md`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
    toast.success('Response downloaded as Markdown.');
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
            generationState={isCurrentlyGeneratingThis ? courseGenerationState : null}
          />
        )}

        {/* Structured lesson. When present it replaces the prose bubble —
            the plain text is the same content, kept only as the fallback for
            clients that cannot render blocks. */}
        {!isUser && hasBlocks && (
          <div
            className={cn(
              'px-4 py-3 rounded-2xl text-sm leading-relaxed w-full',
              'bg-white/5 border border-white/10 text-white/80 rounded-bl-sm backdrop-blur-sm'
            )}
          >
            <BlockRenderer blocks={primaryBlocks} message={message} />
          </div>
        )}

        {!isUser && workspaceLabel && (
          <div className="flex items-center gap-1.5 px-1 text-[11px] text-white/45">
            <Sparkles className="h-3 w-3" aria-hidden="true" />
            <span>{workspaceLabel}</span>
          </div>
        )}

        {/* Regular text bubble */}
        {!hasBlocks && (displayType === 'text' || !displayType) && (displayContent || (isUser && attachments.length > 0)) && (
          <div
            className={cn(
              'px-4 py-3 sm:px-5 sm:py-4 rounded-2xl text-[15px] leading-7',
              !isUser && 'w-full',
              isUser
                ? 'bg-gradient-to-br from-accent-purple to-lyo-500 text-white rounded-br-sm shadow-lg shadow-lyo-900/30'
                : 'bg-white/5 border border-white/10 text-white/80 rounded-bl-sm backdrop-blur-sm'
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
              <div className="prose-invert prose-sm w-full max-w-[88ch]">
                <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
                  {normalizedAssistantContent}
                </ReactMarkdown>
              </div>
            )}
          </div>
        )}


        {!isUser && sourceItems.length > 0 && (
          <div className="w-full rounded-xl border border-white/10 bg-white/[0.035] px-3 py-2.5">
            <div className="mb-2 text-[10px] uppercase tracking-[0.12em] text-white/45">Sources</div>
            <div className="flex flex-wrap gap-2">
              {sourceItems.map((source, index) => {
                const name = String(source.title || source.name || source.label || 'Source');
                const kind = typeof source.kind === 'string' ? source.kind : 'document';
                const url = safeWebUrl(source.url);
                const content = (
                  <>
                    {kind === 'web' ? <Globe2 className="h-3.5 w-3.5" aria-hidden="true" /> : <BookOpen className="h-3.5 w-3.5" aria-hidden="true" />}
                    <span className="max-w-[220px] truncate">{name}</span>
                    {typeof source.page_count === 'number' && source.page_count > 0 && (
                      <span className="text-white/40">{source.page_count} pages</span>
                    )}
                  </>
                );
                const className = "inline-flex min-w-0 items-center gap-1.5 rounded-full border border-white/10 bg-white/5 px-2.5 py-1.5 text-xs text-white/70 transition-colors hover:bg-white/10";
                return url ? (
                  <a key={index} href={url} target="_blank" rel="noopener noreferrer" className={className}>{content}</a>
                ) : (
                  <span key={index} className={className}>{content}</span>
                );
              })}
            </div>
          </div>
        )}

        {/* Server-suggested follow-up directions for this turn. */}
        {!isUser && message.suggestedActions && message.suggestedActions.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {message.suggestedActions.map((label) => (
              <button
                key={label}
                type="button"
                // Chips can arrive mid-stream. Sending while a response is
                // still generating would open a second stream on the same
                // conversation, same guard the composer already applies.
                disabled={isGenerating}
                onClick={() => sendMessage(label)}
                className="px-3 py-1.5 rounded-full border border-white/10 bg-white/5 hover:bg-white/10 hover:border-white/20 text-xs text-white/70 hover:text-white transition-colors disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:bg-white/5"
              >
                {label}
              </button>
            ))}
          </div>
        )}

        {!isUser && supplementalBlocks.length > 0 && (
          <div className="w-full mt-2">
            <BlockRenderer blocks={supplementalBlocks} message={message} />
          </div>
        )}

        {!isUser && displayType === 'text' && writtenContent.trim() && (
          <div className="flex w-full flex-wrap items-center gap-1.5 border-t border-white/10 px-1 pt-3" role="group" aria-label="Response actions">
            <ResponseActionButton label={copied ? 'Copied' : 'Copy'} icon={copied ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />} onClick={() => void handleCopy()} />
            <ResponseActionButton
              label={speechState === 'playing' ? 'Stop' : 'Listen'}
              icon={speechState === 'loading' ? <LoaderCircle className="h-3.5 w-3.5 animate-spin" /> : speechState === 'playing' ? <Square className="h-3.5 w-3.5" /> : <Volume2 className="h-3.5 w-3.5" />}
              active={speechState !== 'idle'}
              onClick={() => void handleListen()}
            />
            <ResponseActionButton label="Try again" icon={<RotateCcw className="h-3.5 w-3.5" />} disabled={!isLatestMessage || isGenerating} onClick={handleRegenerate} />
            <ResponseActionButton label="Save" icon={<Download className="h-3.5 w-3.5" />} onClick={handleSave} />
            <span className="ml-auto text-[10px] text-white/40">{new Date(message.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
          </div>
        )}
      </div>
    </motion.div>
  );
}
