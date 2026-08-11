'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import ReactMarkdown from 'react-markdown';
import { Copy, Check, FileText } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { ChatMessage } from '@/types';
import CourseGenerationCard from './CourseGenerationCard';
import MascotAvatar from './MascotAvatar';
import BlockRenderer from './blocks/BlockRenderer';
import { markdownComponents, MARKDOWN_MATH_PLUGINS } from './markdown-config';
import { useChatStore } from '@/stores/chat-store';

interface MessageBubbleProps {
  message: ChatMessage;
}

const ASSISTANT_RESPONSE_WIDTH_CLASS = 'w-[99%]';

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <button
      onClick={handleCopy}
      className="p-1.5 rounded-lg bg-white/5 border border-white/10 text-white/40 hover:text-white/80 hover:bg-white/10 transition-all duration-200"
      title="Copy message"
    >
      {copied ? (
        <Check className="w-3.5 h-3.5 text-green-400" />
      ) : (
        <Copy className="w-3.5 h-3.5" />
      )}
    </button>
  );
}


export default function MessageBubble({ message }: MessageBubbleProps) {
  const isUser = message.role === 'user';
  const [hovered, setHovered] = useState(false);
  const attachments = message.attachments ?? [];
  
  const { isGenerating, generationProgress, getActiveConversation, sendMessage } = useChatStore();

  // A structured lesson renders as blocks; message.content still holds the
  // plain-text version of the same lesson for clients that cannot.
  const hasBlocks = !isUser && Array.isArray(message.blocks) && message.blocks.length > 0;

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
            <BlockRenderer blocks={message.blocks!} message={message} />
          </div>
        )}

        {/* Regular text bubble */}
        {!hasBlocks && (displayType === 'text' || !displayType) && (displayContent || (isUser && attachments.length > 0)) && (
          <div
            className={cn(
              'px-4 py-3 rounded-2xl text-sm leading-relaxed',
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
              <div className="prose-invert prose-sm max-w-none">
                <ReactMarkdown components={markdownComponents} {...MARKDOWN_MATH_PLUGINS}>
                  {displayContent}
                </ReactMarkdown>
              </div>
            )}
          </div>
        )}

        {/* Server-suggested follow-up directions for this turn. */}
        {!isUser && message.suggestedActions && message.suggestedActions.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {message.suggestedActions.map((label) => (
              <button
                key={label}
                type="button"
                onClick={() => sendMessage(label)}
                className="px-3 py-1.5 rounded-full border border-white/10 bg-white/5 hover:bg-white/10 hover:border-white/20 text-xs text-white/70 hover:text-white transition-colors"
              >
                {label}
              </button>
            ))}
          </div>
        )}

        {/* Timestamp + copy row */}
        <div
          className={cn(
            'flex items-center gap-2 px-1 transition-opacity duration-200',
            isUser ? 'flex-row-reverse' : 'flex-row',
            hovered ? 'opacity-100' : 'opacity-0'
          )}
        >
          <span className="text-[11px] text-white/30">
            {new Date(message.createdAt).toLocaleTimeString([], {
              hour: '2-digit',
              minute: '2-digit',
            })}
          </span>
          {!isUser && <CopyButton text={message.content} />}
        </div>
      </div>
    </motion.div>
  );
}
