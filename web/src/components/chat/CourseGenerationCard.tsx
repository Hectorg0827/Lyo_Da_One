'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  BookOpen,
  CheckCircle2,
  Clock,
  Loader2,
  Play,
  Settings2,
  X,
} from 'lucide-react';
import { cn, formatDuration } from '@/lib/utils';
import type { Course } from '@/types';
import {
  useChatStore,
  type CourseGenerationState,
  type CourseRevisionInput,
} from '@/stores/chat-store';

type DisplayCourse = Partial<Course> & {
  topic?: string;
  level?: string;
  objectives?: string[];
  duration?: string | number;
  estimated_duration?: string | number;
};

interface CourseGenerationCardProps {
  course?: DisplayCourse;
  isGenerating?: boolean;
  generationProgress?: number;
  generationState?: CourseGenerationState | null;
}

const DIFFICULTY_COLORS: Record<string, string> = {
  beginner: 'bg-green-500/15 text-green-300 border-green-500/25',
  intermediate: 'bg-yellow-500/15 text-yellow-300 border-yellow-500/25',
  advanced: 'bg-red-500/15 text-red-300 border-red-500/25',
};

const PHASE_LABELS: Record<string, string> = {
  intent: 'Understanding your request',
  planning: 'Planning your course',
  lessons: 'Creating the course outline',
  practice: 'Adding practice',
  finalizing: 'Preparing your classroom',
  ready: 'Course ready',
};

const LENGTH_OPTIONS = [
  { value: 'short', label: 'Short' },
  { value: 'standard', label: 'Standard' },
  { value: 'deep', label: 'Deep dive' },
] as const;

const STYLE_OPTIONS = [
  { value: 'guided', label: 'Guided' },
  { value: 'conversational', label: 'Conversational' },
  { value: 'practice-heavy', label: 'Practice-heavy' },
] as const;

function hasInternalPromptText(value?: string | null) {
  return Boolean(value && /(proactive\s+(context|system|nudge)|system\s+nudges?)/i.test(value));
}

function safeCourseTitle(course?: DisplayCourse) {
  const rawTitle = course?.title?.trim();
  if (rawTitle && !hasInternalPromptText(rawTitle)) return rawTitle;

  const topic = course?.topic?.trim();
  if (topic && !hasInternalPromptText(topic)) {
    return topic.length > 70 ? topic.slice(0, 67) + '…' : topic;
  }

  return 'Creating your course…';
}

function safeCourseTopic(course?: DisplayCourse) {
  const topic = course?.topic?.trim();
  if (topic && !hasInternalPromptText(topic)) return topic;

  const title = course?.title?.trim();
  if (title && !hasInternalPromptText(title) && !/^creating your course/i.test(title)) {
    return title;
  }

  return '';
}

function normalizedDifficulty(course?: DisplayCourse) {
  const value = (course?.difficulty || course?.level || '').toLowerCase();
  return ['beginner', 'intermediate', 'advanced'].includes(value) ? value : '';
}

function normalizedDuration(course?: DisplayCourse): number | undefined {
  const raw = course?.estimatedDuration ?? course?.estimated_duration ?? course?.duration;
  if (typeof raw === 'number' && Number.isFinite(raw)) return raw;
  if (typeof raw !== 'string') return undefined;

  const match = raw.match(/\d+(?:\.\d+)?/);
  if (!match) return undefined;
  const value = Number(match[0]);
  if (!Number.isFinite(value)) return undefined;
  return /\bhours?\b/i.test(raw) ? Math.round(value * 60) : Math.round(value);
}

function AdjustmentSheet({
  course,
  onClose,
}: {
  course?: DisplayCourse;
  onClose: () => void;
}) {
  const reviseActiveCourse = useChatStore((state) => state.reviseActiveCourse);
  const initialTopic = safeCourseTopic(course);
  const initialDifficulty = normalizedDifficulty(course) || 'beginner';

  const [topic, setTopic] = useState(initialTopic);
  const [difficulty, setDifficulty] = useState(initialDifficulty);
  const [length, setLength] = useState<CourseRevisionInput['length']>('standard');
  const [teachingStyle, setTeachingStyle] =
    useState<CourseRevisionInput['teachingStyle']>('guided');
  const [focus, setFocus] = useState('');

  useEffect(() => {
    setTopic(initialTopic);
    setDifficulty(initialDifficulty);
  }, [initialTopic, initialDifficulty]);

  const apply = () => {
    void reviseActiveCourse({
      topic: topic.trim() || undefined,
      difficulty: difficulty as CourseRevisionInput['difficulty'],
      length,
      teachingStyle,
      focus: focus.trim() || undefined,
    });
    onClose();
  };

  return (
    <motion.div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      onMouseDown={(event) => {
        if (event.currentTarget === event.target) onClose();
      }}
    >
      <motion.div
        role="dialog"
        aria-modal="true"
        aria-label="Adjust course"
        initial={{ y: 36, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        exit={{ y: 36, opacity: 0 }}
        transition={{ duration: 0.2, ease: 'easeOut' }}
        className="w-full sm:max-w-md rounded-t-3xl sm:rounded-3xl border border-white/10 bg-[#111225] shadow-2xl p-5 space-y-5"
      >
        <div className="flex items-center justify-between">
          <div>
            <p className="text-xs uppercase tracking-[0.16em] text-lyo-300/80">Course settings</p>
            <h4 className="text-lg font-semibold text-white mt-1">Adjust while Lyo builds</h4>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="w-9 h-9 rounded-full bg-white/5 hover:bg-white/10 flex items-center justify-center text-white/60 hover:text-white transition-colors"
            aria-label="Close course settings"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <label className="block space-y-2">
          <span className="text-xs font-medium text-white/55">Topic</span>
          <input
            value={topic}
            onChange={(event) => setTopic(event.target.value)}
            placeholder="e.g. Geometry"
            className="w-full rounded-xl border border-white/10 bg-white/5 px-3.5 py-3 text-sm text-white placeholder-white/25 outline-none focus:border-lyo-400/60"
          />
        </label>

        <div className="space-y-2">
          <span className="text-xs font-medium text-white/55">Level</span>
          <div className="grid grid-cols-3 gap-2">
            {(['beginner', 'intermediate', 'advanced'] as const).map((level) => (
              <button
                key={level}
                type="button"
                onClick={() => setDifficulty(level)}
                className={cn(
                  'rounded-xl border px-2 py-2.5 text-xs font-medium capitalize transition-colors',
                  difficulty === level
                    ? 'border-lyo-400/60 bg-lyo-500/15 text-white'
                    : 'border-white/10 bg-white/5 text-white/50 hover:text-white/80'
                )}
              >
                {level}
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-2">
          <span className="text-xs font-medium text-white/55">Length</span>
          <div className="grid grid-cols-3 gap-2">
            {LENGTH_OPTIONS.map((option) => (
              <button
                key={option.value}
                type="button"
                onClick={() => setLength(option.value)}
                className={cn(
                  'rounded-xl border px-2 py-2.5 text-xs font-medium transition-colors',
                  length === option.value
                    ? 'border-lyo-400/60 bg-lyo-500/15 text-white'
                    : 'border-white/10 bg-white/5 text-white/50 hover:text-white/80'
                )}
              >
                {option.label}
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-2">
          <span className="text-xs font-medium text-white/55">Teaching style</span>
          <div className="grid grid-cols-3 gap-2">
            {STYLE_OPTIONS.map((option) => (
              <button
                key={option.value}
                type="button"
                onClick={() => setTeachingStyle(option.value)}
                className={cn(
                  'rounded-xl border px-2 py-2.5 text-[11px] font-medium transition-colors',
                  teachingStyle === option.value
                    ? 'border-lyo-400/60 bg-lyo-500/15 text-white'
                    : 'border-white/10 bg-white/5 text-white/50 hover:text-white/80'
                )}
              >
                {option.label}
              </button>
            ))}
          </div>
        </div>

        <label className="block space-y-2">
          <span className="text-xs font-medium text-white/55">Focus (optional)</span>
          <textarea
            value={focus}
            onChange={(event) => setFocus(event.target.value)}
            rows={2}
            placeholder="e.g. More proofs and harder practice problems"
            className="w-full resize-none rounded-xl border border-white/10 bg-white/5 px-3.5 py-3 text-sm text-white placeholder-white/25 outline-none focus:border-lyo-400/60"
          />
        </label>

        <button
          type="button"
          onClick={apply}
          className="w-full rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple py-3 text-sm font-semibold text-white hover:opacity-90 active:scale-[0.99] transition-all"
        >
          Apply changes
        </button>
      </motion.div>
    </motion.div>
  );
}

export default function CourseGenerationCard({
  course,
  isGenerating = false,
  generationProgress = 0,
  generationState,
}: CourseGenerationCardProps) {
  const router = useRouter();
  const courseRevisionUndo = useChatStore((state) => state.courseRevisionUndo);
  const undoCourseRevision = useChatStore((state) => state.undoCourseRevision);
  const [adjustOpen, setAdjustOpen] = useState(false);

  const title = useMemo(() => safeCourseTitle(course), [course]);
  const difficulty = normalizedDifficulty(course);
  const durationMinutes = normalizedDuration(course);
  const modules = course?.modules ?? [];
  const outlineItems = modules.length > 0
    ? modules.map((module, index) => ({
        id: module.id || `module-${index}`,
        title: module.title,
        description: module.description,
      }))
    : (generationState?.outline ?? []).map((item, index) => ({
        id: `streamed-${index}`,
        title: item.title,
        description: item.description || '',
      }));
  const progress = Math.max(
    0,
    Math.min(100, generationState?.progress ?? generationProgress ?? 0)
  );
  const phase = generationState?.phase || (progress >= 90 ? 'finalizing' : 'planning');
  const statusLabel =
    generationState?.message || PHASE_LABELS[phase] || 'Building your course';
  const completedLessons =
    generationState?.completedLessons
    ?? (phase === 'finalizing' || phase === 'ready' ? outlineItems.length : 0);
  const totalLessons = generationState?.totalLessons ?? outlineItems.length;

  const handleStart = () => {
    const topic = safeCourseTopic(course) || title || 'General Learning';
    const objective = (
      course?.modules?.[0]?.description
      || course?.description
      || `Understand and apply ${topic}`
    ).slice(0, 240);
    const query = new URLSearchParams({ topic, objective });
    if (course?.id) query.set('courseId', course.id);
    if (difficulty) query.set('difficulty', difficulty);
    query.set('language', course?.language || 'auto');
    router.push(`/classroom?${query.toString()}`);
  };

  const handleQuickAdjust = () => setAdjustOpen(true);

  return (
    <>
      <motion.div
        initial={{ opacity: 0, scale: 0.98, y: 8 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ duration: 0.3, ease: 'easeOut' }}
        className="rounded-3xl border border-white/10 bg-[#17182b]/95 backdrop-blur-xl overflow-hidden w-full max-w-lg shadow-xl shadow-black/20"
      >
        <div className="h-1 w-full bg-gradient-to-r from-lyo-500 via-accent-purple to-accent-pink" />

        <div className="p-5 space-y-4">
          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-2xl bg-lyo-600/15 border border-lyo-500/20 shrink-0">
              <BookOpen className="w-5 h-5 text-lyo-300" />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-[11px] uppercase tracking-[0.14em] text-white/35 font-semibold">
                {isGenerating
                  ? courseRevisionUndo
                    ? 'Updating your course'
                    : 'Creating your course'
                  : 'Course ready'}
              </p>
              <h3 className="font-semibold text-white text-lg leading-snug mt-1 break-words">
                {title}
              </h3>
              {course?.description && !hasInternalPromptText(course.description) && (
                <p className="text-sm text-white/50 mt-1 line-clamp-2">
                  {course.description}
                </p>
              )}
            </div>
            <button
              type="button"
              onClick={handleQuickAdjust}
              className="shrink-0 flex items-center gap-1.5 rounded-xl border border-white/10 bg-white/5 px-2.5 py-2 text-xs font-semibold text-white/65 hover:bg-white/10 hover:text-white transition-colors"
            >
              <Settings2 className="w-3.5 h-3.5" />
              Adjust
            </button>
          </div>

          {(difficulty || durationMinutes != null || outlineItems.length > 0) && (
            <div className="flex items-center gap-2 flex-wrap">
              {difficulty && (
                <span
                  className={cn(
                    'px-2.5 py-1 rounded-full text-xs font-medium border capitalize',
                    DIFFICULTY_COLORS[difficulty] ?? DIFFICULTY_COLORS.beginner
                  )}
                >
                  {difficulty}
                </span>
              )}
              {durationMinutes != null ? (
                <span className="flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-white/5 border border-white/10 text-white/55">
                  <Clock className="w-3 h-3" />
                  {formatDuration(durationMinutes)}
                </span>
              ) : null}
              {outlineItems.length > 0 && (
                <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-white/5 border border-white/10 text-white/55">
                  {outlineItems.length} lessons
                </span>
              )}
            </div>
          )}

          {isGenerating && (
            <div className="rounded-2xl border border-white/10 bg-black/15 p-4 space-y-3">
              <div className="flex items-center gap-2">
                <Loader2 className="w-4 h-4 animate-spin text-lyo-300 shrink-0" />
                <div className="min-w-0">
                  <p className="text-sm font-medium text-white/80">{statusLabel}</p>
                  {totalLessons > 0 && phase === 'lessons' && (
                    <p className="text-xs text-white/35 mt-0.5">
                      {Math.min(completedLessons, totalLessons)} of {totalLessons} lessons built
                    </p>
                  )}
                </div>
                <span className="ml-auto text-sm font-semibold text-lyo-300">{progress}%</span>
              </div>
              <div
                className="h-1.5 w-full rounded-full bg-white/10 overflow-hidden"
                role="progressbar"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={progress}
                aria-label="Course generation progress"
              >
                <motion.div
                  className="h-full rounded-full bg-gradient-to-r from-lyo-500 via-accent-purple to-accent-pink"
                  initial={false}
                  animate={{ width: `${progress}%` }}
                  transition={{ duration: 0.35, ease: 'easeOut' }}
                />
              </div>
            </div>
          )}

          {outlineItems.length > 0 ? (
            <div className="space-y-2.5">
              <div className="flex items-center justify-between">
                <span className="text-xs uppercase tracking-[0.12em] font-semibold text-white/35">
                  Course outline
                </span>
                {isGenerating && (
                  <span className="text-xs text-white/30">
                    {completedLessons}/{totalLessons || outlineItems.length} ready
                  </span>
                )}
              </div>
              <div className="space-y-1.5">
                {outlineItems.map((mod, index) => {
                  const done = !isGenerating || index < completedLessons;
                  const active = isGenerating && index === completedLessons && phase === 'lessons';
                  return (
                    <div
                      key={mod.id ?? index}
                      className={cn(
                        'flex items-center gap-3 rounded-xl border px-3 py-2.5 transition-colors',
                        active
                          ? 'border-lyo-500/25 bg-lyo-500/10'
                          : 'border-white/5 bg-white/[0.025]'
                      )}
                    >
                      <div className="w-6 h-6 rounded-full border border-white/10 bg-white/5 flex items-center justify-center shrink-0">
                        {done ? (
                          <CheckCircle2 className="w-3.5 h-3.5 text-green-400" />
                        ) : active ? (
                          <Loader2 className="w-3.5 h-3.5 animate-spin text-lyo-300" />
                        ) : (
                          <span className="text-[10px] font-bold text-white/35">{index + 1}</span>
                        )}
                      </div>
                      <div className="min-w-0">
                        <p className={cn('text-sm truncate', done ? 'text-white/70' : 'text-white/45')}>
                          {mod.title}
                        </p>
                        {mod.description && (
                          <p className="text-[11px] text-white/30 truncate mt-0.5">{mod.description}</p>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ) : isGenerating ? (
            <div className="rounded-2xl border border-dashed border-white/10 px-4 py-3">
              <p className="text-xs text-white/35">
                The course outline will appear here as soon as Lyo finishes the structure.
              </p>
            </div>
          ) : null}

          {!isGenerating && (
            <div className="flex gap-2 pt-1">
              <button
                onClick={handleStart}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl font-semibold text-sm text-white bg-gradient-to-r from-lyo-600 to-accent-purple hover:opacity-90 active:scale-[0.98] transition-all duration-200"
              >
                <Play className="w-4 h-4" />
                Start course
              </button>
            </div>
          )}

          {isGenerating && courseRevisionUndo && (
            <div className="flex items-center justify-between gap-3 rounded-xl border border-lyo-500/15 bg-lyo-500/5 px-3 py-2">
              <span className="text-xs text-white/45">Course settings updated</span>
              <button
                type="button"
                onClick={() => void undoCourseRevision()}
                className="text-xs font-semibold text-lyo-300 hover:text-white transition-colors"
              >
                Undo
              </button>
            </div>
          )}

          {isGenerating && (
            <p className="text-xs text-white/30">
              You can also type a change below — for example, “make it advanced” or “focus on geometry.”
            </p>
          )}
        </div>
      </motion.div>

      <AnimatePresence>
        {adjustOpen && <AdjustmentSheet course={course} onClose={() => setAdjustOpen(false)} />}
      </AnimatePresence>
    </>
  );
}
