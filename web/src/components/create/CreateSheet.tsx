'use client';

/**
 * Create sheet — the web counterpart to iOS `CreateHubView`.
 *
 * iOS presents a full-screen creation studio with six modes. This ships the
 * four the web can actually complete: Post, Clip, Course and Event/Group.
 * Mode pills and editor cards follow the iOS CreateModePicker /
 * createEditorCard styling.
 *
 * Clip used to be left out here as "camera-only, no web equivalent". That was
 * not true — the web could upload and publish a clip, but only from the old
 * `/clips` page, which the mobile nav never linked. So on a phone the feed
 * built for clips had no reachable way to add one. The composer lives in
 * `components/clips/CreateClipModal` now and Discover and this sheet share it.
 */

import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';
import Image from 'next/image';
import { X, Loader2, BookOpen, Camera, Clapperboard, Users, Sparkles, Lightbulb, ArrowRight, type LucideIcon } from 'lucide-react';
import toast from 'react-hot-toast';
import { useRouter } from 'next/navigation';
import { cn } from '@/lib/utils';
import { api } from '@/lib/api';
import CreateClipModal from '@/components/clips/CreateClipModal';
import { PostComposer, type PostFormData } from '@/components/community/CreatePostModal';
import { COMMUNITY_LAUNCH_ENABLED, DISCOVER_LAUNCH_ENABLED } from '@/lib/launch-features';

type Mode = 'post' | 'clip' | 'course' | 'event';

// Colors and copy from iOS CreateViewModel
const MODES: { id: Mode; icon: LucideIcon; label: string; color: string; description: string }[] = [
  { id: 'post', icon: Camera, label: 'Post', color: '#3b82f6', description: 'Photos, thoughts and questions' },
  { id: 'clip', icon: Clapperboard, label: 'Clip', color: '#8b5cf6', description: 'Record or upload a learning video' },
  { id: 'course', icon: BookOpen, label: 'Course', color: '#10b981', description: 'Build a course with Lyo' },
  { id: 'event', icon: Users, label: 'Community', color: '#ec4899', description: 'Plan an event or group' },
];

function EditorCard({ children }: { children: React.ReactNode }) {
  // iOS `.createEditorCard()`: padding 20, glass, r24, white/12 hairline
  return (
    <div className="rounded-[28px] border border-white/[0.12] bg-[#111e26]/90 p-5 text-white shadow-[0_24px_80px_rgba(0,0,0,.25)] backdrop-blur-2xl sm:p-7">
      <div className="flex flex-col gap-5">{children}</div>
    </div>
  );
}

function EditorTitle({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <div className="flex flex-col gap-[5px]">
      <h2 className="font-rounded text-2xl font-bold tracking-tight text-white sm:text-3xl">{title}</h2>
      <p className="text-sm leading-relaxed text-white/60 sm:text-[15px]">{subtitle}</p>
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
      className="flex min-h-12 w-full items-center justify-center gap-2 rounded-[14px] px-[18px] py-3.5 text-[15px] font-bold text-white transition-all duration-200 active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-40"
      style={{ backgroundColor: color }}
    >
      {busy && <Loader2 className="w-4 h-4 animate-spin" />}
      {label}
    </button>
  );
}

const fieldClass =
  'min-h-12 w-full rounded-[13px] border border-white/10 bg-white/[0.08] p-3.5 text-[15px] text-white placeholder-white/40 focus:border-cyan-400 focus:outline-none';

export default function CreateSheet({
  isOpen,
  onClose,
}: {
  isOpen: boolean;
  onClose: () => void;
}) {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>('course');
  const visibleModes = MODES.filter(item => item.id === 'course' || (item.id === 'clip' && DISCOVER_LAUNCH_ENABLED) || ((item.id === 'post' || item.id === 'event') && COMMUNITY_LAUNCH_ENABLED));
  const [composingClip, setComposingClip] = useState(false);
  const [busy, setBusy] = useState(false);
  const [mounted, setMounted] = useState(false);

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

  const active = visibleModes.find((m) => m.id === mode) ?? visibleModes[0];

  const finish = (message: string, destination?: string) => {
    toast.success(message);
    setCourseTopic('');
    setEventTitle('');
    setEventDescription('');
    setEventStart('');
    onClose();
    if (destination) router.push(destination);
  };

  const submitPost = async (data: PostFormData) => {
    setBusy(true);
    try {
      await api.community.createPost({
        content: data.content,
        tags: data.tags,
        media_urls: data.mediaUrls,
        post_type: data.type === 'text' && data.mediaUrls.length ? 'image' : data.type,
      });
      finish('Post published', '/community');
    } catch (reason) {
      throw reason;
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
        // Events need a place on the map (or a link), so the quick sheet
        // hands its draft to the full event editor instead of publishing an
        // event nobody nearby could ever find.
        const draft = new URLSearchParams({ title: eventTitle.trim() });
        if (eventDescription.trim()) draft.set('description', eventDescription.trim());
        if (eventStart) draft.set('start', new Date(eventStart).toISOString());
        onClose();
        router.push(`/community/events/new?${draft}`);
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

          {/* Brand-led studio header. The logo is quiet; the creator's work is the hero. */}
          <div className="relative mx-auto flex w-full max-w-5xl items-center justify-between px-4 pb-3 pt-4 sm:px-6">
            <button
              onClick={onClose}
              aria-label="Close"
              className="flex h-11 w-11 items-center justify-center rounded-full border border-white/10 bg-white/10 text-white backdrop-blur-xl hover:bg-white/20"
            >
              <X className="w-[17px] h-[17px]" strokeWidth={2.5} />
            </button>
            <div className="flex items-center gap-2.5">
              <Image src="/brand/lyo-logo.png" alt="LYO" width={42} height={42} className="h-9 w-9 object-contain" />
              <div className="flex flex-col gap-0.5">
                <span className="font-rounded text-lg font-bold text-white">Create</span>
                <span className="text-[11px] text-white/60">Make something worth sharing</span>
              </div>
            </div>
            <span className="h-11 w-11" aria-hidden="true" />
          </div>

          {composingClip && (
            <CreateClipModal
              onClose={() => setComposingClip(false)}
              onCreated={() => {
                setComposingClip(false);
                onClose();
                router.push('/discover');
              }}
            />
          )}

          <div className="relative flex-1 overflow-y-auto px-4 pb-[calc(1.5rem+env(safe-area-inset-bottom))] pt-4 sm:px-6">
            <div className="mx-auto max-w-5xl space-y-5">
              <div className="text-center sm:pb-1">
                <p className="text-xs font-semibold uppercase tracking-[0.2em] text-cyan-300">LYO Create Studio</p>
                <h1 className="mt-2 font-rounded text-3xl font-bold tracking-tight text-white sm:text-4xl">What will you create today?</h1>
                <p className="mt-2 text-sm text-white/60">Choose a format and bring your ideas to life.</p>
              </div>
              {/* Familiar + Create switch: all available formats are together, within thumb reach. */}
              <div className="mx-auto flex w-full max-w-3xl gap-2 overflow-x-auto rounded-2xl border border-white/10 bg-white/[0.06] p-1.5 no-scrollbar" role="group" aria-label="Choose what to create">
                {visibleModes.map((item) => {
                  const Icon = item.icon;
                  return <button key={item.id} type="button" onClick={() => setMode(item.id)} aria-pressed={active.id === item.id} className={cn('flex min-h-12 flex-1 shrink-0 items-center justify-center gap-2 rounded-xl px-3 text-sm font-bold transition-all duration-200', active.id === item.id ? 'bg-gradient-to-r from-blue-500 to-cyan-500 text-white shadow-lg shadow-cyan-500/15' : 'text-white/65 hover:bg-white/10 hover:text-white')}>
                    <Icon className="h-4 w-4" aria-hidden="true" /> {item.label}
                  </button>;
                })}
              </div>

              <div className="mx-auto grid max-w-4xl gap-5 lg:grid-cols-[minmax(0,1fr)_260px] lg:items-start">
              <div>
              {mode === 'clip' && (
                <EditorCard>
                  <EditorTitle
                    title="Share what you know"
                    subtitle="Record with your camera or upload an educational video to Discover."
                  />
                  <button
                    onClick={() => setComposingClip(true)}
                    className="flex min-h-24 w-full items-center justify-center gap-3 rounded-2xl border border-cyan-400/30 bg-cyan-400/10 px-4 font-rounded text-base font-bold text-white transition-transform hover:bg-cyan-400/15 active:scale-[0.98]"
                  >
                    <Camera className="h-6 w-6 text-cyan-300" aria-hidden="true" /> Record or upload a video <ArrowRight className="h-5 w-5" aria-hidden="true" />
                  </button>
                  <p className="text-xs text-white/50">Camera recording is available on supported devices. You can preview before publishing.</p>
                </EditorCard>
              )}

              {mode === 'post' && (
                <EditorCard>
                  <EditorTitle title="Share with the community" subtitle="Write a thought, ask a question, or post photos from your learning journey." />
                  <PostComposer onSubmit={submitPost} />
                </EditorCard>
              )}

              {mode === 'course' && (
                <EditorCard>
                  <EditorTitle
                    title="What will you teach today?"
                    subtitle="Give Lyo a topic and build a personalized course together."
                  />
                  <input
                    value={courseTopic}
                    onChange={(e) => setCourseTopic(e.target.value)}
                    placeholder="e.g. The Solar System"
                    aria-label="Course topic"
                    className={fieldClass}
                  />
                  <div className="flex flex-wrap gap-2" aria-label="Suggested course topics">
                    {['Algebra', 'Biology', 'World History'].map((topic) => <button key={topic} onClick={() => setCourseTopic(topic)} className="min-h-9 rounded-full border border-white/15 bg-white/[0.05] px-3 text-xs font-semibold text-white/75 hover:bg-white/10">{topic}</button>)}
                  </div>
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
                              ? 'bg-cyan-500/20 text-cyan-100 ring-1 ring-cyan-400/70'
                              : 'bg-white/[0.08] text-white/70 hover:bg-white/[0.14]'
                          )}
                        >
                          {d}
                        </button>
                      ))}
                    </div>
                  </div>
                  <p className="text-[13px] text-white/[0.58]">
                    Lyo will open a chat and help you shape the course step by step.
                  </p>
                  <PrimaryButton
                    label="Build with Lyo →"
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
                    label={eventKind === 'event' ? 'Continue' : 'Create Study Group'}
                    color={active.color}
                    busy={busy}
                    disabled={!eventTitle.trim() || (eventKind === 'event' && !eventStart)}
                    onClick={submitEvent}
                  />
                </EditorCard>
              )}
              </div>
              <aside className="hidden rounded-[28px] border border-white/10 bg-gradient-to-b from-cyan-400/10 to-white/[0.03] p-5 text-white lg:block">
                <Image src="/mascot/mascot_standing.png" alt="Lyo, your learning companion" width={180} height={180} className="mx-auto h-40 w-40 object-contain" />
                <p className="mt-3 flex items-center gap-2 text-sm font-bold"><Sparkles className="h-4 w-4 text-cyan-300" aria-hidden="true" /> Create with Lyo</p>
                <p className="mt-2 text-sm leading-relaxed text-white/60">{active.description}. Bring your curiosity; Lyo will help you make something meaningful.</p>
                <div className="mt-4 flex items-start gap-2 rounded-xl bg-white/[0.05] p-3 text-xs leading-relaxed text-white/60"><Lightbulb className="h-4 w-4 shrink-0 text-cyan-300" aria-hidden="true" /> Start small. Great learning content begins with one useful idea.</div>
              </aside>
              </div>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body
  );
}
