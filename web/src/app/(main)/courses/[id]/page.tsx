'use client';

import { useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { ChevronLeft, Loader2, AlertCircle } from 'lucide-react';
import { Course } from '@/types';
import CoursePlayer from '@/components/courses/CoursePlayer';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';

// ── Adapter: backend course detail → frontend Course type ───────────────────

function adaptCourseDetail(raw: Record<string, unknown>): Course {
  const modules = Array.isArray(raw.modules)
    ? (raw.modules as Record<string, unknown>[]).map((m, mi) => ({
        id: String(m.id ?? `m_${mi}`),
        title: String(m.title ?? ''),
        description: String(m.description ?? ''),
        order: (m.order as number) ?? mi + 1,
        isCompleted: (m.is_completed as boolean) ?? false,
        lessons: Array.isArray(m.lessons)
          ? (m.lessons as Record<string, unknown>[]).map((l, li) => ({
              id: String(l.id ?? `l_${li}`),
              title: String(l.title ?? ''),
              type: (l.type as 'text') ?? 'text',
              duration: (l.duration as number) ?? 10,
              order: (l.order as number) ?? li + 1,
              isCompleted: (l.is_completed as boolean) ?? false,
              content: Array.isArray(l.content)
                ? (l.content as Course['modules'][0]['lessons'][0]['content'])
                : Array.isArray(l.blocks)
                ? (l.blocks as Course['modules'][0]['lessons'][0]['content'])
                : [],
            }))
          : [],
      }))
    : [];

  const lessonsCount = (raw.lessons_count as number) ?? modules.reduce((acc, m) => acc + m.lessons.length, 0);
  const durationHours = (raw.estimated_duration_hours as number) ?? 0;

  return {
    id: String(raw.id ?? ''),
    title: String(raw.title ?? ''),
    description: String(raw.description ?? ''),
    thumbnail: (raw.thumbnail_url as string) ?? (raw.thumbnail as string) ?? '',
    author: {
      id: String(raw.author_id ?? raw.creator_id ?? ''),
      displayName: String(raw.author_name ?? raw.creator_name ?? 'LYO'),
      username: String(raw.author_username ?? ''),
      avatar: (raw.author_avatar as string) ?? '',
      email: '',
      bio: '',
      role: 'creator',
      interests: [],
      learningGoals: [],
      streak: 0,
      xp: 0,
      level: 0,
      coursesCompleted: 0,
      followersCount: 0,
      followingCount: 0,
      createdAt: '',
      isPremium: false,
    },
    category: String(raw.subject ?? raw.category ?? 'General'),
    tags: Array.isArray(raw.tags) ? (raw.tags as string[]) : [],
    difficulty: (['beginner', 'intermediate', 'advanced'].includes(String(raw.difficulty_level ?? raw.difficulty ?? ''))
      ? String(raw.difficulty_level ?? raw.difficulty) as Course['difficulty']
      : 'beginner'),
    estimatedDuration: durationHours * 60 || lessonsCount * 15,
    enrolledCount: (raw.enrolled_count as number) ?? (raw.enrollments_count as number) ?? 0,
    rating: (raw.rating as number) ?? (raw.average_rating as number) ?? 0,
    reviewCount: (raw.review_count as number) ?? (raw.reviews_count as number) ?? 0,
    progress: raw.progress != null ? (raw.progress as number) : undefined,
    isAIGenerated: (raw.is_ai_generated as boolean) ?? false,
    createdAt: String(raw.created_at ?? new Date().toISOString()),
    modules,
  };
}

// ── Component ─────────────────────────────────────────────────────────────────

interface CourseDetailPageProps {
  params: { id: string };
}

export default function CourseDetailPage({ params }: CourseDetailPageProps) {
  const router = useRouter();
  const courseId = params.id;

  const fetcher = useCallback(() => api.courses.get(courseId), [courseId]);
  const { data: rawCourse, isLoading, error, refetch } = useApi<Record<string, unknown>>(fetcher, [courseId]);

  const course = rawCourse ? adaptCourseDetail(rawCourse) : null;

  // Loading state
  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-gray-950 flex items-center justify-center">
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="flex flex-col items-center gap-4"
        >
          <Loader2 className="w-10 h-10 text-lyo-500 animate-spin" />
          <p className="text-white/40 text-sm">Loading course...</p>
        </motion.div>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-gray-950 flex items-center justify-center">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="flex flex-col items-center gap-5 text-center px-4"
        >
          <div className="w-20 h-20 rounded-2xl bg-red-500/10 border border-red-500/20 flex items-center justify-center">
            <AlertCircle className="w-10 h-10 text-red-400" />
          </div>
          <div>
            <h2 className="text-white text-xl font-bold">Failed to load course</h2>
            <p className="text-white/40 text-sm mt-1">{error}</p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={refetch}
              className="px-5 py-2.5 rounded-xl bg-lyo-600 hover:bg-lyo-500 text-white text-sm font-semibold transition-colors"
            >
              Try again
            </button>
            <button
              onClick={() => router.push('/courses')}
              className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-white text-sm font-semibold transition-colors"
            >
              <ChevronLeft className="w-4 h-4" />
              Back to Courses
            </button>
          </div>
        </motion.div>
      </div>
    );
  }

  // Not found state
  if (!course) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-gray-950 flex items-center justify-center">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="flex flex-col items-center gap-5 text-center px-4"
        >
          <div className="w-20 h-20 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center">
            <ChevronLeft className="w-10 h-10 text-white/20" />
          </div>
          <div>
            <h2 className="text-white text-xl font-bold">Course not found</h2>
            <p className="text-white/40 text-sm mt-1">The course you&apos;re looking for doesn&apos;t exist or has been removed.</p>
          </div>
          <button
            onClick={() => router.push('/courses')}
            className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-lyo-600 hover:bg-lyo-500 text-white text-sm font-semibold transition-colors"
          >
            <ChevronLeft className="w-4 h-4" />
            Back to Courses
          </button>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="h-screen overflow-hidden">
      <CoursePlayer
        course={course}
        onBack={() => router.push('/courses')}
      />
    </div>
  );
}
