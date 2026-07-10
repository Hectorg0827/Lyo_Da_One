'use client';

import { motion } from 'framer-motion';
import { BookOpen, Clock, Users, Star } from 'lucide-react';
import { Course } from '@/types';
import { cn, formatDuration, formatNumber, getInitials } from '@/lib/utils';

interface CourseCardProps {
  course: Course;
  onClick?: () => void;
}

const categoryGradients: Record<string, string> = {
  programming: 'from-blue-600/40 to-cyan-500/40',
  mathematics: 'from-purple-600/40 to-pink-500/40',
  science: 'from-green-600/40 to-teal-500/40',
  history: 'from-amber-600/40 to-orange-500/40',
  language: 'from-rose-600/40 to-pink-500/40',
  art: 'from-violet-600/40 to-fuchsia-500/40',
  music: 'from-indigo-600/40 to-blue-500/40',
  business: 'from-emerald-600/40 to-green-500/40',
  design: 'from-pink-600/40 to-rose-500/40',
  health: 'from-teal-600/40 to-cyan-500/40',
  default: 'from-lyo-600/40 to-accent-purple/40',
};

function getCategoryGradient(category: string): string {
  const key = category.toLowerCase();
  return categoryGradients[key] ?? categoryGradients.default;
}

const difficultyStyles: Record<string, { bg: string; text: string; label: string }> = {
  beginner: { bg: 'bg-green-500/20', text: 'text-green-400', label: 'Beginner' },
  intermediate: { bg: 'bg-yellow-500/20', text: 'text-yellow-400', label: 'Intermediate' },
  advanced: { bg: 'bg-red-500/20', text: 'text-red-400', label: 'Advanced' },
};

export default function CourseCard({ course, onClick }: CourseCardProps) {
  const difficulty = difficultyStyles[course.difficulty] ?? difficultyStyles.beginner;
  const gradient = getCategoryGradient(course.category);
  const hasProgress = course.progress !== undefined && course.progress > 0;

  const renderStars = (rating: number) => {
    const full = Math.floor(rating);
    const half = rating - full >= 0.5;
    return (
      <span className="text-yellow-400 text-sm leading-none">
        {Array.from({ length: 5 }, (_, i) => {
          if (i < full) return '★';
          if (i === full && half) return '½';
          return '☆';
        }).join('')}
      </span>
    );
  };

  return (
    <motion.div
      whileHover={{ y: -4 }}
      transition={{ duration: 0.2 }}
      onClick={onClick}
      className={cn(
        'bg-white/5 border border-white/10 rounded-2xl overflow-hidden cursor-pointer',
        'hover:border-lyo-500/40 transition-all flex flex-col',
      )}
    >
      {/* Thumbnail */}
      <div className="relative h-40 flex-shrink-0">
        {course.thumbnail ? (
          <img
            src={course.thumbnail}
            alt={course.title}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className={cn('w-full h-full bg-gradient-to-br', gradient, 'flex items-center justify-center')}>
            <BookOpen className="w-10 h-10 text-white/40" />
          </div>
        )}

        {/* AI Generated badge */}
        {course.isAIGenerated && (
          <span className="absolute top-2 left-2 bg-gradient-to-r from-lyo-500 to-accent-purple text-white text-[10px] font-semibold px-2 py-0.5 rounded-full">
            AI Generated
          </span>
        )}

        {/* Difficulty badge */}
        <span
          className={cn(
            'absolute top-2 right-2 text-[10px] font-semibold px-2 py-0.5 rounded-full',
            difficulty.bg,
            difficulty.text,
          )}
        >
          {difficulty.label}
        </span>
      </div>

      {/* Body */}
      <div className="flex flex-col flex-1 p-4 gap-3">
        {/* Title */}
        <h3 className="text-white font-semibold text-sm leading-snug line-clamp-2">{course.title}</h3>

        {/* Description */}
        <p className="text-white/50 text-xs leading-relaxed line-clamp-2">{course.description}</p>

        {/* Author */}
        <div className="flex items-center gap-2">
          {course.author.avatar ? (
            <img
              src={course.author.avatar}
              alt={course.author.displayName}
              className="w-5 h-5 rounded-full object-cover flex-shrink-0"
            />
          ) : (
            <div className="w-5 h-5 rounded-full bg-lyo-600 flex items-center justify-center flex-shrink-0">
              <span className="text-white text-[9px] font-bold">{getInitials(course.author.displayName)}</span>
            </div>
          )}
          <span className="text-white/60 text-xs truncate">{course.author.displayName}</span>
        </div>

        {/* Meta row */}
        <div className="flex items-center gap-3 text-white/40 text-xs">
          <span className="flex items-center gap-1">
            <Clock className="w-3 h-3" />
            {formatDuration(course.estimatedDuration)}
          </span>
          <span className="flex items-center gap-1">
            <Users className="w-3 h-3" />
            {formatNumber(course.enrolledCount)} enrolled
          </span>
        </div>

        {/* Rating */}
        <div className="flex items-center gap-1.5">
          {renderStars(course.rating)}
          <span className="text-white/60 text-xs font-medium">{course.rating.toFixed(1)}</span>
          <span className="text-white/30 text-xs">({formatNumber(course.reviewCount)})</span>
        </div>
      </div>

      {/* Progress bar */}
      {hasProgress && (
        <div className="px-4 pb-3">
          <div className="h-1 w-full bg-white/10 rounded-full overflow-hidden">
            <div
              className="h-full bg-lyo-500 rounded-full transition-all"
              style={{ width: `${course.progress}%` }}
            />
          </div>
          <span className="text-white/40 text-[10px] mt-1 block">{course.progress}% complete</span>
        </div>
      )}
    </motion.div>
  );
}
