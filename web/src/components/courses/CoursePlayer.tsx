'use client';

import { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ChevronLeft,
  ChevronRight,
  CheckCircle,
  BookOpen,
  Play,
  FileText,
  HelpCircle,
  Zap,
} from 'lucide-react';
import { Course, Lesson } from '@/types';
import { cn, formatDuration } from '@/lib/utils';
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
      return <Zap className="w-3.5 h-3.5" />;
    case 'flashcard':
      return <BookOpen className="w-3.5 h-3.5" />;
    case 'interactive':
      return <Zap className="w-3.5 h-3.5" />;
    case 'text':
    default:
      return <FileText className="w-3.5 h-3.5" />;
  }
};

export default function CoursePlayer({ course, onBack }: CoursePlayerProps) {
  const [activeModuleIndex, setActiveModuleIndex] = useState(0);
  const [activeLessonIndex, setActiveLessonIndex] = useState(0);
  const [expandedModules, setExpandedModules] = useState<Set<number>>(
    () => new Set(course.modules.map((_, i) => i)),
  );

  // Flat list of all lessons for prev/next navigation
  const flatLessons = useMemo<FlatLesson[]>(() => {
    const list: FlatLesson[] = [];
    course.modules.forEach((mod, mIdx) => {
      mod.lessons.forEach((lesson, lIdx) => {
        list.push({ lesson, moduleIndex: mIdx, lessonIndex: lIdx });
      });
    });
    return list;
  }, [course]);

  const currentFlatIndex = useMemo(() => {
    return flatLessons.findIndex(
      (f) => f.moduleIndex === activeModuleIndex && f.lessonIndex === activeLessonIndex,
    );
  }, [flatLessons, activeModuleIndex, activeLessonIndex]);

  const activeLesson = course.modules[activeModuleIndex]?.lessons[activeLessonIndex];

  const overallProgress = useMemo(() => {
    const total = flatLessons.length;
    if (total === 0) return 0;
    const completed = flatLessons.filter((f) => f.lesson.isCompleted).length;
    return Math.round((completed / total) * 100);
  }, [flatLessons]);

  const goToLesson = (moduleIndex: number, lessonIndex: number) => {
    setActiveModuleIndex(moduleIndex);
    setActiveLessonIndex(lessonIndex);
  };

  const goPrev = () => {
    if (currentFlatIndex <= 0) return;
    const prev = flatLessons[currentFlatIndex - 1];
    goToLesson(prev.moduleIndex, prev.lessonIndex);
  };

  const goNext = () => {
    if (currentFlatIndex >= flatLessons.length - 1) return;
    const next = flatLessons[currentFlatIndex + 1];
    goToLesson(next.moduleIndex, next.lessonIndex);
  };

  const toggleModule = (index: number) => {
    setExpandedModules((prev) => {
      const next = new Set(prev);
      if (next.has(index)) {
        next.delete(index);
      } else {
        next.add(index);
      }
      return next;
    });
  };

  const isFirst = currentFlatIndex <= 0;
  const isLast = currentFlatIndex >= flatLessons.length - 1;

  return (
    <div className="flex h-full w-full bg-[#0a0a0f] text-white overflow-hidden">
      {/* ── LEFT: Content ── */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Top bar */}
        <div className="flex-shrink-0 border-b border-white/10 bg-white/3 backdrop-blur-sm px-4 py-3 flex items-center gap-4">
          <button
            onClick={onBack}
            className="flex items-center gap-1.5 text-white/60 hover:text-white text-sm transition-colors"
          >
            <ChevronLeft className="w-4 h-4" />
            Back to courses
          </button>

          <div className="h-4 w-px bg-white/10" />

          <h1 className="flex-1 text-white font-semibold text-sm truncate">{course.title}</h1>

          <div className="flex items-center gap-2 flex-shrink-0">
            <span className="text-white/40 text-xs">{overallProgress}%</span>
            <div className="w-24 h-1.5 bg-white/10 rounded-full overflow-hidden">
              <div
                className="h-full bg-lyo-500 rounded-full transition-all duration-500"
                style={{ width: `${overallProgress}%` }}
              />
            </div>
          </div>
        </div>

        {/* Lesson content area */}
        <div className="flex-1 overflow-y-auto px-6 py-8">
          <AnimatePresence mode="wait">
            {activeLesson ? (
              <motion.div
                key={`${activeModuleIndex}-${activeLessonIndex}`}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.2 }}
                className="max-w-3xl mx-auto"
              >
                <LessonView lesson={activeLesson} />
              </motion.div>
            ) : (
              <div className="flex items-center justify-center h-full text-white/30 text-sm">
                No lesson selected
              </div>
            )}
          </AnimatePresence>
        </div>

        {/* Bottom navigation bar */}
        <div className="flex-shrink-0 border-t border-white/10 bg-white/3 backdrop-blur-sm px-4 py-3 flex items-center gap-3">
          <button
            onClick={goPrev}
            disabled={isFirst}
            className={cn(
              'flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all',
              isFirst
                ? 'text-white/20 cursor-not-allowed'
                : 'text-white/60 hover:text-white hover:bg-white/10',
            )}
          >
            <ChevronLeft className="w-4 h-4" />
            Previous
          </button>

          <div className="flex-1 text-center text-white/40 text-xs">
            Lesson {currentFlatIndex + 1} of {flatLessons.length}
          </div>

          <button
            onClick={goNext}
            disabled={isLast}
            className={cn(
              'flex items-center gap-1.5 px-4 py-1.5 rounded-lg text-sm font-semibold transition-all',
              isLast
                ? 'bg-white/5 text-white/20 cursor-not-allowed'
                : 'bg-lyo-600 hover:bg-lyo-500 text-white',
            )}
          >
            {activeLesson?.isCompleted ? 'Next Lesson' : 'Mark Complete & Next'}
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* ── RIGHT: Sidebar ── */}
      <aside className="hidden md:flex flex-col w-72 xl:w-80 border-l border-white/10 bg-white/3 overflow-y-auto flex-shrink-0">
        {/* Sidebar header */}
        <div className="px-4 py-4 border-b border-white/10 flex-shrink-0">
          <h2 className="text-white font-semibold text-sm">Course Content</h2>
          <p className="text-white/40 text-xs mt-0.5">
            {flatLessons.length} lessons · {formatDuration(course.estimatedDuration)}
          </p>
        </div>

        {/* Module list */}
        <div className="flex-1 overflow-y-auto py-2">
          {course.modules.map((mod, mIdx) => {
            const isExpanded = expandedModules.has(mIdx);
            const completedCount = mod.lessons.filter((l) => l.isCompleted).length;

            return (
              <div key={mod.id} className="border-b border-white/5 last:border-0">
                {/* Module header */}
                <button
                  onClick={() => toggleModule(mIdx)}
                  className="w-full flex items-start gap-3 px-4 py-3 hover:bg-white/5 transition-colors text-left"
                >
                  <div className="flex-shrink-0 mt-0.5">
                    {mod.isCompleted ? (
                      <CheckCircle className="w-4 h-4 text-lyo-500" />
                    ) : (
                      <div className="w-4 h-4 rounded-full border border-white/20 flex items-center justify-center">
                        <span className="text-white/40 text-[9px] font-bold">{mIdx + 1}</span>
                      </div>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-white/80 text-xs font-medium leading-snug line-clamp-2">{mod.title}</p>
                    <p className="text-white/30 text-[10px] mt-0.5">
                      {completedCount}/{mod.lessons.length} lessons
                    </p>
                  </div>
                  <ChevronRight
                    className={cn(
                      'w-3.5 h-3.5 text-white/30 flex-shrink-0 mt-0.5 transition-transform',
                      isExpanded && 'rotate-90',
                    )}
                  />
                </button>

                {/* Lessons */}
                <AnimatePresence initial={false}>
                  {isExpanded && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.2 }}
                      className="overflow-hidden"
                    >
                      {mod.lessons.map((lesson, lIdx) => {
                        const isActive = activeModuleIndex === mIdx && activeLessonIndex === lIdx;
                        return (
                          <button
                            key={lesson.id}
                            onClick={() => goToLesson(mIdx, lIdx)}
                            className={cn(
                              'w-full flex items-center gap-2.5 pl-10 pr-4 py-2.5 text-left transition-all',
                              isActive
                                ? 'bg-lyo-500/10 border-l-2 border-lyo-500'
                                : 'border-l-2 border-transparent hover:bg-white/5',
                            )}
                          >
                            <span
                              className={cn(
                                'flex-shrink-0',
                                isActive ? 'text-lyo-400' : 'text-white/30',
                              )}
                            >
                              {lesson.isCompleted ? (
                                <CheckCircle className="w-3.5 h-3.5 text-lyo-500" />
                              ) : (
                                lessonTypeIcon(lesson.type)
                              )}
                            </span>
                            <span
                              className={cn(
                                'flex-1 text-xs leading-snug line-clamp-2 min-w-0',
                                isActive ? 'text-white font-medium' : 'text-white/60',
                              )}
                            >
                              {lesson.title}
                            </span>
                            <span className="text-white/30 text-[10px] flex-shrink-0">
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
