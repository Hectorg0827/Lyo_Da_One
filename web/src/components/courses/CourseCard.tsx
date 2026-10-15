'use client';

import { motion } from 'framer-motion';
import Link from 'next/link';
import { Clock, Users, Star } from 'lucide-react';
import { Course } from '@/types';
import { cn, formatDuration, formatNumber, getInitials } from '@/lib/utils';
import CourseArtwork from '@/components/home/CourseArtwork';

interface CourseCardProps {
  course: Course;
}

const difficultyStyles: Record<string, { bg: string; text: string; label: string }> = {
  beginner: { bg: 'bg-green-500/20', text: 'text-green-400', label: 'Beginner' },
  intermediate: { bg: 'bg-yellow-500/20', text: 'text-yellow-400', label: 'Intermediate' },
  advanced: { bg: 'bg-red-500/20', text: 'text-red-400', label: 'Advanced' },
};

export default function CourseCard({ course }: CourseCardProps) {
  const persistedId = /^(?:[1-9][0-9]*)$/.test(course.id) && Number.isSafeInteger(Number(course.id));
  const href = persistedId ? `/courses/${course.id}` : `/classroom?topic=${encodeURIComponent(course.title)}`;
  const hasRealRating = course.reviewCount > 0 && course.rating > 0;

  const difficulty = difficultyStyles[course.difficulty] ?? difficultyStyles.beginner;
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
    <Link href={href} aria-label={`Open ${course.title}`} className="block rounded-2xl focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet-300">
    <motion.div
      whileHover={{ y: -4 }}
      transition={{ duration: 0.2 }}
      className={cn(
        'bg-white/5 border border-white/10 rounded-2xl overflow-hidden',
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
          <CourseArtwork
            title={course.title}
            className="h-full w-full"
          />
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
          {course.enrolledCount > 0 && (
            <span className="flex items-center gap-1">
              <Users className="w-3 h-3" />
              {formatNumber(course.enrolledCount)} enrolled
            </span>
          )}
        </div>

        {/* Rating */}
        {hasRealRating && (
          <div className="flex items-center gap-1.5">
            {renderStars(course.rating)}
            <span className="text-white/60 text-xs font-medium">{course.rating.toFixed(1)}</span>
            <span className="text-white/30 text-xs">({formatNumber(course.reviewCount)})</span>
          </div>
        )}
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
    </Link>
  );
}
