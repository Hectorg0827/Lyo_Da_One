'use client';

import { useMemo, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  AlertCircle,
  ChevronLeft,
  ChevronRight,
  CheckCircle,
  BookOpen,
  Play,
  FileText,
  HelpCircle,
  Loader2,
  Zap,
} from 'lucide-react';
import { Course, Lesson } from '@/types';
import { cn, formatDuration } from '@/lib/utils';
import {
  getCourseProgress,
  markLessonComplete,
  normalizeProgressPercent,
} from '@/lib/learning-progress';
import LessonView from './LessonView';

interface CoursePlayerProps {
  course: Course;
  onBack?: () => void;
}

interface FlatLesson {
  lesson: Lesson;
  moduleIndex: number;
  lessonIndex: number;
}

const lessonTypeIcon = (type: Lesson['type']) => {
  switch (type) {
    case 'video':
      return <Play className="w-3.5 h-3.5" />;
    case 'quiz':
      return <HelpCircle className="w-3.5 h-3.5" />;
    case 'exercise':
    case 'interactive':
      return <Zap className="w-3.5 h-3.5" />;
    case 'flashcard':
      return <BookOpen className="w-3.5 h-3.5" />;
    case 'text':
    default:
      return <FileText className="w-3.5 h-3.5" />;
  }
};

function errorMessage(reason: unknown): string {
  if (reason instanceof Error && reason.message) return reason.message;
  return 'Unable to save lesson progress. Try again.';
}

export default function CoursePlayer({ course, onBack }: CoursePlayerProps) {
  const [activeModuleIndex, setActiveModuleIndex] = useState(0);
  const [activeLessonIndex, setActiveLessonIndex] = useState(0);
  const [expandedModules, setExpandedModules] = useState<Set<number>>(
    () => new Set(course.modules.map((_, index) => index)),
  );
  const [completedLessonIds, setCompletedLessonIds] = useState<Set<string>>(
    () =>
      new Set(
        course.modules.flatMap((module) =>
          module.lessons.filter((lesson) => lesson.isCompleted).map((lesson) => lesson.id),
        ),
      ),
  );
  const [serverProgressPercent, setServerProgressPercent] = useState<number | null>(
    typeof course.progress === 'number' ? Math.max(0, Math.min(course.progress, 100)) : null,
  );
  const [isCompleting, setIsCompleting] = useState(false);
  const [completionError, setCompletionError] = useState<string | null>(null);

  const flatLessons = useMemo<FlatLesson[]>(() => {
    const list: FlatLesson[] = [];
    course.modules.forEach((module, moduleIndex) => {
      module.lessons.forEach((lesson, lessonIndex) => {
        list.push({ lesson, moduleIndex, lessonIndex });
      });
    });
    return list;
  }, [course]);

  const currentFlatIndex = useMemo(
    () =>
      flatLessons.findIndex(
        (item) =>
          item.moduleIndex === activeModuleIndex && item.lessonIndex === activeLessonIndex,
      ),
    [flatLessons, activeModuleIndex, activeLessonIndex],
  );

  const activeLesson = course.modules[activeModuleIndex]?.lessons[activeLessonIndex];
  const activeLessonCompleted = activeLesson
    ? completedLessonIds.has(activeLesson.id)
    : false;

  const localProgressPercent = useMemo(() => {
    if (flatLessons.length === 0) return 0;
    return Math.round((completedLessonIds.size / flatLessons.length) * 100);
  }, [completedLessonIds, flatLessons.length]);

  const overallProgress = Math.max(localProgressPercent, serverProgressPercent ?? 0);

  const goToLesson = (moduleIndex: number, lessonIndex: number) => {
    setActiveModuleIndex(moduleIndex);
    setActiveLessonIndex(lessonIndex);
    setCompletionError(null);
  };

  const goPrev = () => {
    if (currentFlatIndex <= 0) return;
    const previous = flatLessons[currentFlatIndex - 1];
    goToLesson(previous.moduleIndex, previous.lessonIndex);
  };

  const goNext = () => {
    if (currentFlatIndex >= flatLessons.length - 1) return;
    const next = flatLessons[currentFlatIndex + 1];
    goToLesson(next.moduleIndex, next.lessonIndex);
  };

  const completeAndAdvance = async () => {
    if (!activeLesson || isCompleting) return;

    if (completedLessonIds.has(activeLesson.id)) {
      if (currentFlatIndex < flatLessons.length - 1) goNext();
      return;
    }

    const previousCompletedIds = new Set(completedLessonIds);
    const optimisticCompletedIds = new Set(previousCompletedIds);
    optimisticCompletedIds.add(activeLesson.id);

    setCompletedLessonIds(optimisticCompletedIds);
    setCompletionError(null);
    setIsCompleting(true);

    try {
      await markLessonComplete(activeLesson.id);

      try {
        const progress = await getCourseProgress(course.id);
        setServerProgressPercent(normalizeProgressPercent(progress.progress_percent));
      } catch {
        // The completion write is authoritative. A temporary hydration failure
        // must not roll back a lesson that the backend already accepted.
      }

      if (currentFlatIndex < flatLessons.length - 1) goNext();
    } catch (reason) {
      setCompletedLessonIds(previousCompletedIds);
      setCompletionError(errorMessage(reason));
    } finally {
      setIsCompleting(false);
    }
  };

  const toggleModule = (index: number) => {
    setExpandedModules((previous) => {
      const next = new Set(previous);
      if (next.has(index)) next.delete(index);
      else next.add(index);
      return next;
    });
  };

  const isFirst = currentFlatIndex <= 0;
  const isLast = currentFlatIndex >= flatLessons.length - 1;
  const nextButtonDisabled = isCompleting || (isLast && activeLessonCompleted);

  return (
    <div className="flex h-full w-full overflow-hidden bg-[#0a0a0f] text-white">
      <div className="flex min-w-0 flex-1 flex-col overflow-hidden">
        <div className="flex flex-shrink-0 items-center gap-4 border-b border-white/10 bg-white/3 px-4 py-3 backdrop-blur-sm">
          <button
            type="button"
            onClick={onBack}
            className="flex items-center gap-1.5 text-sm text-white/60 transition-colors hover:text-white"
          >
            <ChevronLeft className="h-4 w-4" />
            Back to courses
          </button>

          <div className="h-4 w-px bg-white/10" />
          <h1 className="flex-1 truncate text-sm font-semibold text-white">{course.title}</h1>

          <div className="flex flex-shrink-0 items-center gap-2">
            <span className="text-xs text-white/40">{overallProgress}%</span>
            <div className="h-1.5 w-24 overflow-hidden rounded-full bg-white/10">
              <div
                className="h-full rounded-full bg-lyo-500 transition-all duration-500"
                style={{ width: `${overallProgress}%` }}
              />
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-6 py-8">
          <AnimatePresence mode="wait">
            {activeLesson ? (
              <motion.div
                key={`${activeModuleIndex}-${activeLessonIndex}`}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.2 }}
                className="mx-auto max-w-3xl"
              >
                <LessonView lesson={activeLesson} />
              </motion.div>
            ) : (
              <div className="flex h-full items-center justify-center text-sm text-white/30">
                No lesson selected
              </div>
            )}
          </AnimatePresence>
        </div>

        {completionError && (
          <div
            role="alert"
            className="mx-4 mb-2 flex items-start gap-2 rounded-lg border border-red-400/20 bg-red-400/10 px-3 py-2 text-xs text-red-100"
          >
            <AlertCircle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            <span>{completionError}</span>
          </div>
        )}

        <div className="flex flex-shrink-0 items-center gap-3 border-t border-white/10 bg-white/3 px-4 py-3 backdrop-blur-sm">
          <button
            type="button"
            onClick={goPrev}
            disabled={isFirst || isCompleting}
            className={cn(
              'flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium transition-all',
              isFirst || isCompleting
                ? 'cursor-not-allowed text-white/20'
                : 'text-white/60 hover:bg-white/10 hover:text-white',
            )}
          >
            <ChevronLeft className="h-4 w-4" />
            Previous
          </button>

          <div className="flex-1 text-center text-xs text-white/40">
            Lesson {Math.max(currentFlatIndex + 1, 0)} of {flatLessons.length}
          </div>

          <button
            type="button"
            onClick={completeAndAdvance}
            disabled={nextButtonDisabled}
            className={cn(
              'flex items-center gap-1.5 rounded-lg px-4 py-1.5 text-sm font-semibold transition-all',
              nextButtonDisabled
                ? 'cursor-not-allowed bg-white/5 text-white/20'
                : 'bg-lyo-600 text-white hover:bg-lyo-500',
            )}
          >
            {isCompleting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                Saving…
              </>
            ) : isLast && activeLessonCompleted ? (
              <>
                <CheckCircle className="h-4 w-4" />
                Course Complete
              </>
            ) : activeLessonCompleted ? (
              <>
                Next Lesson
                <ChevronRight className="h-4 w-4" />
              </>
            ) : isLast ? (
              <>
                Complete Course
                <CheckCircle className="h-4 w-4" />
              </>
            ) : (
              <>
                Mark Complete & Next
                <ChevronRight className="h-4 w-4" />
              </>
            )}
          </button>
        </div>
      </div>

      <aside className="hidden w-72 flex-shrink-0 flex-col overflow-y-auto border-l border-white/10 bg-white/3 md:flex xl:w-80">
        <div className="flex-shrink-0 border-b border-white/10 px-4 py-4">
          <h2 className="text-sm font-semibold text-white">Course Content</h2>
          <p className="mt-0.5 text-xs text-white/40">
            {flatLessons.length} lessons · {formatDuration(course.estimatedDuration)}
          </p>
        </div>

        <div className="flex-1 overflow-y-auto py-2">
          {course.modules.map((module, moduleIndex) => {
            const isExpanded = expandedModules.has(moduleIndex);
            const completedCount = module.lessons.filter((lesson) =>
              completedLessonIds.has(lesson.id),
            ).length;
            const moduleCompleted =
              module.lessons.length > 0 && completedCount === module.lessons.length;

            return (
              <div key={module.id} className="border-b border-white/5 last:border-0">
                <button
                  type="button"
                  onClick={() => toggleModule(moduleIndex)}
                  className="flex w-full items-start gap-3 px-4 py-3 text-left transition-colors hover:bg-white/5"
                >
                  <div className="mt-0.5 flex-shrink-0">
                    {moduleCompleted ? (
                      <CheckCircle className="h-4 w-4 text-lyo-500" />
                    ) : (
                      <div className="flex h-4 w-4 items-center justify-center rounded-full border border-white/20">
                        <span className="text-[9px] font-bold text-white/40">{moduleIndex + 1}</span>
                      </div>
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="line-clamp-2 text-xs font-medium leading-snug text-white/80">
                      {module.title}
                    </p>
                    <p className="mt-0.5 text-[10px] text-white/30">
                      {completedCount}/{module.lessons.length} lessons
                    </p>
                  </div>
                  <ChevronRight
                    className={cn(
                      'mt-0.5 h-3.5 w-3.5 flex-shrink-0 text-white/30 transition-transform',
                      isExpanded && 'rotate-90',
                    )}
                  />
                </button>

                <AnimatePresence initial={false}>
                  {isExpanded && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.2 }}
                      className="overflow-hidden"
                    >
                      {module.lessons.map((lesson, lessonIndex) => {
                        const isActive =
                          activeModuleIndex === moduleIndex && activeLessonIndex === lessonIndex;
                        const isCompleted = completedLessonIds.has(lesson.id);

                        return (
                          <button
                            type="button"
                            key={lesson.id}
                            onClick={() => goToLesson(moduleIndex, lessonIndex)}
                            className={cn(
                              'flex w-full items-center gap-2.5 border-l-2 py-2.5 pl-10 pr-4 text-left transition-all',
                              isActive
                                ? 'border-lyo-500 bg-lyo-500/10'
                                : 'border-transparent hover:bg-white/5',
                            )}
                          >
                            <span
                              className={cn(
                                'flex-shrink-0',
                                isActive ? 'text-lyo-400' : 'text-white/30',
                              )}
                            >
                              {isCompleted ? (
                                <CheckCircle className="h-3.5 w-3.5 text-lyo-500" />
                              ) : (
                                lessonTypeIcon(lesson.type)
                              )}
                            </span>
                            <span
                              className={cn(
                                'min-w-0 flex-1 line-clamp-2 text-xs leading-snug',
                                isActive ? 'font-medium text-white' : 'text-white/60',
                              )}
                            >
                              {lesson.title}
                            </span>
                            <span className="flex-shrink-0 text-[10px] text-white/30">
                              {formatDuration(lesson.duration)}
                            </span>
                          </button>
                        );
                      })}
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            );
          })}
        </div>
      </aside>
    </div>
  );
}
