'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  BookOpen,
  ChevronDown,
  ChevronUp,
  Clock,
  Play,
  Settings2,
  CheckCircle2,
  Loader2,
} from 'lucide-react';
import { cn, formatDuration } from '@/lib/utils';
import type { Course } from '@/types';
import { useChatStore } from '@/stores/chat-store';

interface CourseGenerationCardProps {
  course?: Partial<Course>;
  isGenerating?: boolean;
  generationProgress?: number;
}

const GENERATION_STEPS = [
  'Analyzing',
  'Structuring',
  'Creating Lessons',
  'Adding Quizzes',
  'Done',
];

function getStepIndex(progress: number): number {
  if (progress < 20) return 0;
  if (progress < 45) return 1;
  if (progress < 70) return 2;
  if (progress < 90) return 3;
  return 4;
}

const DIFFICULTY_COLORS: Record<string, string> = {
  beginner: 'bg-green-500/20 text-green-400 border-green-500/30',
  intermediate: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30',
  advanced: 'bg-red-500/20 text-red-400 border-red-500/30',
};

export default function CourseGenerationCard({
  course,
  isGenerating = false,
  generationProgress = 0,
}: CourseGenerationCardProps) {
  const router = useRouter();
  const { sendMessage } = useChatStore();

  // Start: open the persisted course when we have an id; otherwise ask the
  // AI to start it (mirrors the iOS proposal-card behavior).
  const handleStart = () => {
    if (course?.id) {
      router.push(`/courses/${course.id}`);
    } else if (course?.title) {
      // No persisted course id on web — start the lesson right here in chat.
      // Phrased to elicit actual teaching rather than another course card.
      void sendMessage(
        `Begin lesson 1 of "${course.title}" right now, here in this chat. ` +
        `Teach the first concept with a clear explanation and one practice question — don't send the course overview again.`
      );
    }
  };

  // Customize: continue the conversation as a refine request.
  const handleCustomize = () => {
    const title = course?.title ?? 'this course';
    void sendMessage(
      `I'd like to customize "${title}" — can we adjust the difficulty, length, or focus areas?`
    );
  };

  const [modulesExpanded, setModulesExpanded] = useState(false);
  const currentStep = getStepIndex(generationProgress);

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.97, y: 8 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      transition={{ duration: 0.4, ease: 'easeOut' }}
      className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur-md overflow-hidden w-full max-w-lg"
    >
      {/* Header gradient strip */}
      <div className="h-1.5 w-full bg-gradient-to-r from-lyo-500 via-accent-purple to-accent-pink" />

      <div className="p-5 space-y-4">
        {/* Title + badges */}
        <div className="flex items-start gap-3">
          <div className="p-2.5 rounded-xl bg-lyo-600/20 border border-lyo-500/20 shrink-0">
            <BookOpen className="w-5 h-5 text-lyo-400" />
          </div>
          <div className="flex-1 min-w-0">
            <h3 className="font-semibold text-white text-base leading-snug truncate">
              {course?.title ?? 'Generating your course…'}
            </h3>
            {course?.description && (
              <p className="text-sm text-white/55 mt-0.5 line-clamp-2">
                {course.description}
              </p>
            )}
          </div>
        </div>

        {/* Meta badges */}
        {(course?.difficulty || course?.estimatedDuration) && (
          <div className="flex items-center gap-2 flex-wrap">
            {course.difficulty && (
              <span
                className={cn(
                  'px-2.5 py-0.5 rounded-full text-xs font-medium border capitalize',
                  DIFFICULTY_COLORS[course.difficulty] ?? DIFFICULTY_COLORS.beginner
                )}
              >
                {course.difficulty}
              </span>
            )}
            {course.estimatedDuration && (
              <span className="flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-white/5 border border-white/10 text-white/60">
                <Clock className="w-3 h-3" />
                {formatDuration(course.estimatedDuration)}
              </span>
            )}
          </div>
        )}

        {/* Generation progress */}
        {isGenerating && (
          <div className="space-y-3">
            <div className="flex gap-1.5">
              {GENERATION_STEPS.map((step, i) => (
                <div key={step} className="flex-1 flex flex-col items-center gap-1">
                  <div
                    className={cn(
                      'w-full h-1 rounded-full transition-all duration-500',
                      i <= currentStep
                        ? 'bg-gradient-to-r from-lyo-500 to-accent-purple'
                        : 'bg-white/10'
                    )}
                  />
                  <span
                    className={cn(
                      'text-[10px] leading-none transition-colors duration-300',
                      i === currentStep
                        ? 'text-lyo-400 font-medium'
                        : i < currentStep
                        ? 'text-white/40'
                        : 'text-white/20'
                    )}
                  >
                    {step}
                  </span>
                </div>
              ))}
            </div>
            <div className="flex items-center gap-2 text-sm text-white/60">
              <Loader2 className="w-3.5 h-3.5 animate-spin text-lyo-400" />
              <span>{GENERATION_STEPS[currentStep]}…</span>
              <span className="ml-auto text-lyo-400 font-medium">{generationProgress}%</span>
            </div>
          </div>
        )}

        {/* Module outline */}
        {course?.modules && course.modules.length > 0 && (
          <div className="space-y-2">
            <button
              onClick={() => setModulesExpanded((v) => !v)}
              className="flex items-center justify-between w-full text-sm text-white/70 hover:text-white transition-colors group"
            >
              <span className="font-medium">
                {course.modules.length} Modules
              </span>
              {modulesExpanded ? (
                <ChevronUp className="w-4 h-4 group-hover:text-lyo-400 transition-colors" />
              ) : (
                <ChevronDown className="w-4 h-4 group-hover:text-lyo-400 transition-colors" />
              )}
            </button>
            <AnimatePresence>
              {modulesExpanded && (
                <motion.ul
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={{ duration: 0.25, ease: 'easeInOut' }}
                  className="overflow-hidden space-y-1.5"
                >
                  {course.modules.map((mod, idx) => (
                    <li
                      key={mod.id ?? idx}
                      className="flex items-center gap-2.5 text-sm text-white/60 py-1 px-2 rounded-lg hover:bg-white/5 transition-colors"
                    >
                      <span className="w-5 h-5 rounded-full bg-lyo-600/20 border border-lyo-500/20 flex items-center justify-center text-[10px] text-lyo-400 font-bold shrink-0">
                        {idx + 1}
                      </span>
                      {mod.title}
                      {mod.isCompleted && (
                        <CheckCircle2 className="w-3.5 h-3.5 text-green-400 ml-auto shrink-0" />
                      )}
                    </li>
                  ))}
                </motion.ul>
              )}
            </AnimatePresence>
          </div>
        )}

        {/* Actions */}
        {!isGenerating && (
          <div className="flex gap-2 pt-1">
            <button
              onClick={handleStart}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl font-semibold text-sm text-white bg-gradient-to-r from-lyo-600 to-accent-purple hover:opacity-90 active:scale-[0.98] transition-all duration-200">
              <Play className="w-4 h-4" />
              Start Learning
            </button>
            <button
              onClick={handleCustomize}
              className="flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl font-semibold text-sm text-white/70 bg-white/5 border border-white/10 hover:bg-white/10 hover:text-white active:scale-[0.98] transition-all duration-200">
              <Settings2 className="w-4 h-4" />
              Customize
            </button>
          </div>
        )}
      </div>
    </motion.div>
  );
}
