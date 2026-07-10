'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import ReactMarkdown from 'react-markdown';
import { Copy, Check } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { ChatMessage } from '@/types';
import CourseGenerationCard from './CourseGenerationCard';
import { useChatStore } from '@/stores/chat-store';

interface MessageBubbleProps {
  message: ChatMessage;
}

function LYOAvatar() {
  return (
    <div className="relative shrink-0 w-8 h-8">
      <div className="absolute inset-0 rounded-full bg-gradient-to-br from-lyo-500 via-accent-purple to-accent-pink animate-pulse-slow blur-sm opacity-60" />
      <div className="relative w-8 h-8 rounded-full bg-gradient-to-br from-lyo-500 via-accent-purple to-accent-pink flex items-center justify-center shadow-lg">
        <span className="text-[11px] font-bold text-white tracking-tight">LYO</span>
      </div>
    </div>
  );
}

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

const markdownComponents = {
  // Paragraphs
  p: ({ children }: { children?: React.ReactNode }) => (
    <p className="mb-3 last:mb-0 leading-relaxed">{children}</p>
  ),
  // Headings
  h1: ({ children }: { children?: React.ReactNode }) => (
    <h1 className="text-xl font-bold text-white mb-3 mt-4 first:mt-0">{children}</h1>
  ),
  h2: ({ children }: { children?: React.ReactNode }) => (
    <h2 className="text-lg font-semibold text-white mb-2 mt-4 first:mt-0">{children}</h2>
  ),
  h3: ({ children }: { children?: React.ReactNode }) => (
    <h3 className="text-base font-semibold text-white/90 mb-2 mt-3 first:mt-0">{children}</h3>
  ),
  // Lists
  ul: ({ children }: { children?: React.ReactNode }) => (
    <ul className="mb-3 space-y-1 pl-4">{children}</ul>
  ),
  ol: ({ children }: { children?: React.ReactNode }) => (
    <ol className="mb-3 space-y-1 pl-4 list-decimal">{children}</ol>
  ),
  li: ({ children }: { children?: React.ReactNode }) => (
    <li className="flex items-start gap-2 text-white/80">
      <span className="mt-1.5 w-1.5 h-1.5 rounded-full bg-lyo-400 shrink-0" />
      <span>{children}</span>
    </li>
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
        <code className="px-1.5 py-0.5 rounded-md bg-white/10 text-lyo-300 font-mono text-[0.85em]">
          {children}
        </code>
      );
    }
    return (
      <code className="block w-full overflow-x-auto p-3 rounded-xl bg-black/40 border border-white/10 text-lyo-300 font-mono text-sm leading-relaxed">
        {children}
      </code>
    );
  },
  pre: ({ children }: { children?: React.ReactNode }) => (
    <pre className="mb-3 rounded-xl overflow-hidden">{children}</pre>
  ),
  // Blockquote
  blockquote: ({ children }: { children?: React.ReactNode }) => (
    <blockquote className="border-l-2 border-lyo-500 pl-3 my-2 text-white/60 italic">
      {children}
    </blockquote>
  ),
  // HR
  hr: () => <hr className="border-white/10 my-4" />,
};

export default function MessageBubble({ message }: MessageBubbleProps) {
  const isUser = message.role === 'user';
  const [hovered, setHovered] = useState(false);
  
  const { isGenerating, generationProgress, getActiveConversation } = useChatStore();

  // Helper to extract OPEN_CLASSROOM JSON block from assistant messages
  const getOpenClassroomData = (content: string) => {
    if (isUser) return null;
    
    // Pattern to look for JSON block that has "type": "OPEN_CLASSROOM"
    const jsonRegex = /(?:```json\s*)?(\{\s*"type"\s*:\s*"OPEN_CLASSROOM"[\s\S]*?\})(?:\s*```)?/i;
    const match = content.match(jsonRegex);
    if (match) {
      try {
        const parsed = JSON.parse(match[1]);
        const cleanText = content.replace(match[0], '').trim();
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
      } catch (e) {
        console.error("Failed to parse OPEN_CLASSROOM JSON:", e);
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
        'flex items-end gap-3 w-full group',
        isUser ? 'flex-row-reverse' : 'flex-row'
      )}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {/* Avatar – assistant only */}
      {!isUser && <LYOAvatar />}

      {/* Bubble */}
      <div
        className={cn(
          'relative max-w-[78%] md:max-w-[68%]',
          isUser ? 'items-end' : 'items-start',
          'flex flex-col gap-1'
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
        {(displayType === 'text' || !displayType) && displayContent && (
          <div
            className={cn(
              'px-4 py-3 rounded-2xl text-sm leading-relaxed',
              isUser
                ? 'bg-gradient-to-br from-lyo-600 to-accent-purple text-white rounded-br-sm shadow-lg shadow-lyo-900/30'
                : 'bg-white/5 border border-white/10 text-white/80 rounded-bl-sm backdrop-blur-sm'
            )}
          >
            {isUser ? (
              <p className="whitespace-pre-wrap">{displayContent}</p>
            ) : (
              <div className="prose-invert prose-sm max-w-none">
                <ReactMarkdown components={markdownComponents}>
                  {displayContent}
                </ReactMarkdown>
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
              <ReactMarkdown components={markdownComponents}>
                {message.content}
              </ReactMarkdown>
            </div>
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
