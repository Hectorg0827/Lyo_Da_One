'use client';

/**
 * Create sheet — the web counterpart to iOS `CreateHubView`.
 *
 * iOS presents a full-screen creation studio with six modes; the camera-only
 * ones (Clip, Story) have no web equivalent, so this ships the three the web
 * can actually complete: Post, Course and Event/Group. Mode pills and editor
 * cards follow the iOS CreateModePicker / createEditorCard styling.
 */

import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { X, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { useRouter } from 'next/navigation';
import { cn } from '@/lib/utils';
import { api } from '@/lib/api';

type Mode = 'post' | 'course' | 'event';

// Colors and copy from iOS CreateViewModel
const MODES: { id: Mode; emoji: string; label: string; color: string; description: string }[] = [
  { id: 'post', emoji: '✏️', label: 'Post', color: '#3b82f6', description: 'Share to your feed' },
  { id: 'course', emoji: '📚', label: 'Course', color: '#10b981', description: 'AI-generated course' },
  { id: 'event', emoji: '🎉', label: 'Event/Group', color: '#ec4899', description: 'Create event or group' },
];

const MAX_POST_CHARS = 2000;

function EditorCard({ children }: { children: React.ReactNode }) {
  // iOS `.createEditorCard()`: padding 20, glass, r24, white/12 hairline
  return (
    <div className="p-5 rounded-3xl bg-white/[0.07] backdrop-blur-2xl border border-white/[0.12] text-white">
      <div className="flex flex-col gap-4">{children}</div>
    </div>
  );
}

function EditorTitle({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <div className="flex flex-col gap-[5px]">
      <h2 className="font-rounded text-xl font-bold text-white">{title}</h2>
      <p className="text-[15px] text-white/60">{subtitle}</p>
    </div>
  );
}

function PrimaryButton({
  label,
  color,
  busy,
  disabled,
  onClick,
}: {
  label: string;
  color: string;
  busy: boolean;
  disabled: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled || busy}
      className="flex items-center justify-center gap-2 w-full py-3.5 px-[18px] rounded-[14px] text-[15px] font-bold text-white transition-all duration-200 active:scale-[0.98] disabled:opacity-40 disabled:cursor-not-allowed"
      style={{ backgroundColor: color }}
    >
      {busy && <Loader2 className="w-4 h-4 animate-spin" />}
      {label}
    </button>
  );
}

const fieldClass =
  'w-full p-3 rounded-[13px] bg-white/[0.08] text-white placeholder-white/40 text-[15px] focus:outline-none focus:ring-1 focus:ring-white/30';

export default function CreateSheet({
  isOpen,
  onClose,
}: {
  isOpen: boolean;
  onClose: () => void;
}) {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>('post');
  const [busy, setBusy] = useState(false);
  const [mounted, setMounted] = useState(false);

  // Post
  const [postContent, setPostContent] = useState('');
  const [postTags, setPostTags] = useState('');

  // Course
  const [courseTopic, setCourseTopic] = useState('');
  const [difficulty, setDifficulty] = useState<'beginner' | 'intermediate' | 'advanced'>('beginner');

  // Event / group
  const [eventKind, setEventKind] = useState<'event' | 'group'>('event');
  const [eventTitle, setEventTitle] = useState('');
  const [eventDescription, setEventDescription] = useState('');
  const [eventStart, setEventStart] = useState('');

  useEffect(() => setMounted(true), []);

  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [isOpen, onClose]);

  const active = MODES.find((m) => m.id === mode)!;

  const finish = (message: string, destination?: string) => {
    toast.success(message);
    setPostContent('');
    setPostTags('');
    setCourseTopic('');
    setEventTitle('');
    setEventDescription('');
    setEventStart('');
    onClose();
    if (destination) router.push(destination);
  };

  const submitPost = async () => {
    setBusy(true);
    try {
      await api.community.createPost({
        content: postContent.trim(),
        tags: postTags
          .split(',')
          .map((t) => t.trim())
          .filter(Boolean),
        post_type: 'text',
      });
      finish('Post published', '/community');
    } catch {
      toast.error("Couldn't publish that post. Please try again.");
    } finally {
      setBusy(false);
    }
  };

  const submitCourse = () => {
    // Course generation lives in the chat agent — hand the topic over rather
    // than duplicating the generation flow here.
    const prompt = `Create a ${difficulty} course on ${courseTopic.trim()}`;
    onClose();
    router.push(`/chat?prompt=${encodeURIComponent(prompt)}`);
  };

  const submitEvent = async () => {
    setBusy(true);
    try {
      if (eventKind === 'group') {
        await api.community.createGroup({
          name: eventTitle.trim(),
          description: eventDescription.trim() || undefined,
          privacy: 'public',
        });
        finish('Study group created', '/community/groups');
      } else {
        const start = new Date(eventStart);
        const end = new Date(start.getTime() + 60 * 60 * 1000);
        await api.community.createEvent({
          title: eventTitle.trim(),
          description: eventDescription.trim() || undefined,
          event_type: 'study_session',
          start_time: start.toISOString(),
          end_time: end.toISOString(),
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        });
        finish('Event created', '/community');
      }
    } catch {
      toast.error(`Couldn't create that ${eventKind}. Please try again.`);
    } finally {
      setBusy(false);
    }
  };

  if (!mounted) return null;

  return createPortal(
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[100] flex flex-col"
          role="dialog"
          aria-modal="true"
          aria-label="Create"
        >
          {/* Backdrop — iOS tints a near-black base with the mode color at
              34%. The tint is translucent, so it needs an opaque base under
              it or the page behind shows through. */}
          <button
            aria-label="Close create"
            onClick={onClose}
            className="absolute inset-0 cursor-default"
            style={{
              backgroundColor: '#07080f',
              backgroundImage: `linear-gradient(135deg, #07080f, ${active.color}57)`,
            }}
          />

          {/* Top bar */}
          <div className="relative flex items-center justify-between px-4 pt-3 pb-2">
            <button
              onClick={onClose}
              aria-label="Close"
              className="w-[42px] h-[42px] rounded-full bg-white/10 backdrop-blur-xl flex items-center justify-center text-white"
            >
              <X className="w-[17px] h-[17px]" strokeWidth={2.5} />
            </button>
            <div className="flex flex-col items-center gap-0.5">
              <span className="text-[17px] font-bold text-white">Create</span>
              <span className="text-xs text-white/[0.66]">{active.description}</span>
            </div>
            <span className="w-[42px] h-[42px]" />
          </div>

          {/* Editor */}
          <div className="relative flex-1 overflow-y-auto px-[18px] py-3">
            <div className="max-w-xl mx-auto">
              {mode === 'post' && (
                <EditorCard>
                  <EditorTitle
                    title="Share a useful idea"
                    subtitle="Your post will be saved to the shared Community feed."
                  />
                  <div className="relative">
                    <textarea
                      value={postContent}
                      onChange={(e) => setPostContent(e.target.value.slice(0, MAX_POST_CHARS))}
                      placeholder="What have you been learning?"
                      aria-label="Post content"
                      className={cn(fieldClass, 'min-h-[190px] resize-none')}
                    />
                    <span className="absolute bottom-2.5 right-2.5 text-[11px] font-mono text-white/45">
                      {MAX_POST_CHARS - postContent.length}
                    </span>
                  </div>
                  <input
                    value={postTags}
                    onChange={(e) => setPostTags(e.target.value)}
                    placeholder="Tags, comma separated"
                    aria-label="Post tags"
                    className={fieldClass}
                  />
                  <PrimaryButton
                    label="Publish Post"
                    color={active.color}
                    busy={busy}
                    disabled={!postContent.trim()}
                    onClick={submitPost}
                  />
                </EditorCard>
              )}

              {mode === 'course' && (
                <EditorCard>
                  <EditorTitle
                    title="Build an AI course"
                    subtitle="LYO will generate the curriculum through the course-generation service."
                  />
                  <input
                    value={courseTopic}
                    onChange={(e) => setCourseTopic(e.target.value)}
                    placeholder="Course topic"
                    aria-label="Course topic"
                    className={fieldClass}
                  />
                  <div className="flex flex-col gap-2">
                    <span className="text-xs font-semibold text-white/65">Difficulty</span>
                    <div className="flex gap-2">
                      {(['beginner', 'intermediate', 'advanced'] as const).map((d) => (
                        <button
                          key={d}
                          onClick={() => setDifficulty(d)}
                          className={cn(
                            'flex-1 py-2 rounded-[10px] text-[13px] font-semibold capitalize transition-colors duration-200',
                            difficulty === d
                              ? 'bg-white text-black'
                              : 'bg-white/[0.08] text-white/70 hover:bg-white/[0.14]'
                          )}
                        >
                          {d}
                        </button>
                      ))}
                    </div>
                  </div>
                  <p className="text-[13px] text-white/[0.58]">
                    This opens a chat with Lyo, who builds the course with you.
                  </p>
                  <PrimaryButton
                    label="Generate Course"
                    color={active.color}
                    busy={false}
                    disabled={!courseTopic.trim()}
                    onClick={submitCourse}
                  />
                </EditorCard>
              )}

              {mode === 'event' && (
                <EditorCard>
                  <EditorTitle
                    title="Create a learning gathering"
                    subtitle="Create a real virtual event or study group in Community."
                  />
                  <div className="flex gap-2">
                    {(['event', 'group'] as const).map((k) => (
                      <button
                        key={k}
                        onClick={() => setEventKind(k)}
                        className={cn(
                          'flex-1 py-2 rounded-[10px] text-[13px] font-semibold transition-colors duration-200',
                          eventKind === k
                            ? 'bg-white text-black'
                            : 'bg-white/[0.08] text-white/70 hover:bg-white/[0.14]'
                        )}
                      >
                        {k === 'event' ? 'Event' : 'Study Group'}
                      </button>
                    ))}
                  </div>
                  <input
                    value={eventTitle}
                    onChange={(e) => setEventTitle(e.target.value)}
                    placeholder={eventKind === 'event' ? 'Event title' : 'Group name'}
                    aria-label={eventKind === 'event' ? 'Event title' : 'Group name'}
                    className={fieldClass}
                  />
                  <textarea
                    value={eventDescription}
                    onChange={(e) => setEventDescription(e.target.value)}
                    placeholder="Description"
                    aria-label="Description"
                    className={cn(fieldClass, 'min-h-[110px] resize-none')}
                  />
                  {eventKind === 'event' && (
                    <label className="flex flex-col gap-2">
                      <span className="text-xs font-semibold text-white/65">Starts</span>
                      <input
                        type="datetime-local"
                        value={eventStart}
                        onChange={(e) => setEventStart(e.target.value)}
                        className={cn(fieldClass, '[color-scheme:dark]')}
                      />
                    </label>
                  )}
                  <PrimaryButton
                    label={eventKind === 'event' ? 'Create Event' : 'Create Study Group'}
                    color={active.color}
                    busy={busy}
                    disabled={!eventTitle.trim() || (eventKind === 'event' && !eventStart)}
                    onClick={submitEvent}
                  />
                </EditorCard>
              )}
            </div>
          </div>

          {/* Mode picker — iOS CreateModePicker */}
          <div
            className="relative h-[120px] flex items-center px-4 pb-6"
            style={{ background: 'linear-gradient(to bottom, transparent, rgba(0,0,0,0.9))' }}
          >
            <div className="flex gap-2 overflow-x-auto no-scrollbar w-full max-w-xl mx-auto">
              {MODES.map((m) => {
                const selected = m.id === mode;
                return (
                  <button
                    key={m.id}
                    onClick={() => setMode(m.id)}
                    aria-pressed={selected}
                    className={cn(
                      'flex items-center gap-1.5 shrink-0 px-4 py-2 rounded-full text-[13px] font-bold transition-all duration-200',
                      selected ? 'text-white scale-105' : 'bg-white/10 text-white/60'
                    )}
                    style={
                      selected
                        ? {
                            background: 'linear-gradient(135deg, #3b82f6, #06b6d4)',
                            boxShadow: '0 0 20px rgba(59,130,246,0.5)',
                          }
                        : undefined
                    }
                  >
                    <span className="text-sm">{m.emoji}</span>
                    {m.label}
                  </button>
                );
              })}
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body
  );
}
