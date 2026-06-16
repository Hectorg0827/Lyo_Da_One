'use client';

import { useState, useMemo, useCallback } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, BookOpen, Sparkles, X, Loader2, AlertCircle } from 'lucide-react';
import { Course } from '@/types';
import { cn } from '@/lib/utils';
import CourseCard from '@/components/courses/CourseCard';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';

// ── Adapter: backend course → frontend Course type ──────────────────────────

function adaptCourse(raw: Record<string, unknown>): Course {
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
              content: Array.isArray(l.content) ? (l.content as Course['modules'][0]['lessons'][0]['content']) : [],
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

// ── Types ─────────────────────────────────────────────────────────────────────

type TabId = 'inProgress' | 'completed' | 'bookmarked' | 'browse';
type DifficultyFilter = 'all' | 'beginner' | 'intermediate' | 'advanced';

const TABS: { id: TabId; label: string }[] = [
  { id: 'inProgress', label: 'In Progress' },
  { id: 'completed', label: 'Completed' },
  { id: 'bookmarked', label: 'Bookmarked' },
  { id: 'browse', label: 'Browse' },
];

const DIFFICULTY_FILTERS: { id: DifficultyFilter; label: string }[] = [
  { id: 'all', label: 'All Levels' },
  { id: 'beginner', label: 'Beginner' },
  { id: 'intermediate', label: 'Intermediate' },
  { id: 'advanced', label: 'Advanced' },
];

// ── Component ─────────────────────────────────────────────────────────────────

export default function CoursesPage() {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<TabId>('browse');
  const [searchQuery, setSearchQuery] = useState('');
  const [difficultyFilter, setDifficultyFilter] = useState<DifficultyFilter>('all');

  // Fetch courses from API
  const fetcher = useCallback(
    () => api.courses.list(0, 50, undefined, difficultyFilter === 'all' ? undefined : difficultyFilter),
    [difficultyFilter],
  );
  const { data: rawCourses, isLoading, error, refetch } = useApi<Record<string, unknown>[]>(fetcher, [difficultyFilter]);

  // Adapt raw API data to frontend Course type
  const courses = useMemo<Course[]>(() => {
    if (!rawCourses) return [];
    return rawCourses.map(adaptCourse);
  }, [rawCourses]);

  // Derive tab-specific lists
  const tabCourses = useMemo<Course[]>(() => {
    switch (activeTab) {
      case 'inProgress':
        return courses.filter((c) => c.progress !== undefined && c.progress > 0 && c.progress < 100);
      case 'completed':
        return courses.filter((c) => c.progress === 100);
      case 'bookmarked':
        // TODO: wire to real bookmarks endpoint when available
        return [];
      case 'browse':
      default:
        return courses;
    }
  }, [activeTab, courses]);

  // Apply search filter
  const filteredCourses = useMemo<Course[]>(() => {
    return tabCourses.filter((c) => {
      const matchesSearch =
        searchQuery.trim() === '' ||
        c.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.tags.some((t) => t.toLowerCase().includes(searchQuery.toLowerCase()));
      return matchesSearch;
    });
  }, [tabCourses, searchQuery]);

  const handleCourseClick = (course: Course) => {
    router.push(`/courses/${course.id}`);
  };

  const inProgressCount = courses.filter((c) => c.progress !== undefined && c.progress > 0 && c.progress < 100).length;
  const completedCount = courses.filter((c) => c.progress === 100).length;

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-gray-950">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8">

        {/* ── Page Header ── */}
        <motion.div
          initial={{ opacity: 0, y: -12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="flex items-center justify-between mb-8"
        >
          <div>
            <h1 className="text-3xl font-bold text-white tracking-tight">My Courses</h1>
            <p className="text-white/40 text-sm mt-1">
              {inProgressCount} in progress
              &nbsp;&middot;&nbsp;
              {completedCount} completed
            </p>
          </div>
          <Link href="/chat">
            <motion.button
              whileHover={{ scale: 1.03 }}
              whileTap={{ scale: 0.97 }}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-gradient-to-r from-lyo-600 to-lyo-500 text-white text-sm font-semibold shadow-lg shadow-lyo-600/25 hover:shadow-lyo-500/40 transition-shadow"
            >
              <Sparkles className="w-4 h-4" />
              Create with AI
            </motion.button>
          </Link>
        </motion.div>

        {/* ── Tab Row ── */}
        <motion.div
          initial={{ opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3, delay: 0.05 }}
          className="flex items-center gap-2 mb-6"
        >
          {TABS.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={cn(
                'px-4 py-2 rounded-full text-sm font-medium transition-all duration-200',
                activeTab === tab.id
                  ? 'bg-lyo-500 text-white shadow-md shadow-lyo-500/30'
                  : 'bg-white/5 text-white/50 hover:bg-white/10 hover:text-white/80 border border-white/10',
              )}
            >
              {tab.label}
            </button>
          ))}
        </motion.div>

        {/* ── Search + Difficulty Filters ── */}
        <motion.div
          initial={{ opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3, delay: 0.1 }}
          className="mb-6 space-y-3"
        >
          {/* Search bar */}
          <div className="relative">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30 pointer-events-none" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search courses..."
              className={cn(
                'w-full bg-white/5 border border-white/10 rounded-xl',
                'pl-10 pr-10 py-2.5 text-sm text-white placeholder:text-white/30',
                'focus:outline-none focus:border-lyo-500/50 focus:bg-white/8 transition-all',
              )}
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-3.5 top-1/2 -translate-y-1/2 text-white/30 hover:text-white/60 transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>

          {/* Difficulty filters */}
          <div className="flex items-center gap-2 flex-wrap">
            {DIFFICULTY_FILTERS.map((f) => (
              <button
                key={f.id}
                onClick={() => setDifficultyFilter(f.id)}
                className={cn(
                  'px-3 py-1.5 rounded-lg text-xs font-medium transition-all duration-200',
                  difficultyFilter === f.id
                    ? 'bg-lyo-500/20 text-lyo-400 border border-lyo-500/40'
                    : 'bg-white/5 text-white/40 border border-white/10 hover:bg-white/10 hover:text-white/60',
                )}
              >
                {f.label}
              </button>
            ))}
          </div>
        </motion.div>

        {/* ── Loading State ── */}
        {isLoading && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="flex flex-col items-center justify-center py-24 gap-4"
          >
            <Loader2 className="w-8 h-8 text-lyo-500 animate-spin" />
            <p className="text-white/40 text-sm">Loading courses...</p>
          </motion.div>
        )}

        {/* ── Error State ── */}
        {error && !isLoading && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="flex flex-col items-center justify-center py-24 gap-4"
          >
            <div className="w-16 h-16 rounded-2xl bg-red-500/10 border border-red-500/20 flex items-center justify-center">
              <AlertCircle className="w-8 h-8 text-red-400" />
            </div>
            <div className="text-center">
              <p className="text-white/60 font-medium">Failed to load courses</p>
              <p className="text-white/30 text-sm mt-1">{error}</p>
            </div>
            <button
              onClick={refetch}
              className="text-lyo-400 text-sm hover:text-lyo-300 transition-colors"
            >
              Try again
            </button>
          </motion.div>
        )}

        {/* ── Course Grid ── */}
        {!isLoading && !error && (
          <AnimatePresence mode="wait">
            {filteredCourses.length > 0 ? (
              <motion.div
                key={`${activeTab}-${searchQuery}-${difficultyFilter}`}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.25 }}
                className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6"
              >
                {filteredCourses.map((course, i) => (
                  <motion.div
                    key={course.id}
                    initial={{ opacity: 0, y: 16 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.25, delay: i * 0.04 }}
                  >
                    <CourseCard
                      course={course}
                      onClick={() => handleCourseClick(course)}
                    />
                  </motion.div>
                ))}
              </motion.div>
            ) : (
              <motion.div
                key="empty"
                initial={{ opacity: 0, scale: 0.96 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.96 }}
                transition={{ duration: 0.2 }}
                className="flex flex-col items-center justify-center py-24 gap-4"
              >
                <div className="w-16 h-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center">
                  <BookOpen className="w-8 h-8 text-white/20" />
                </div>
                <div className="text-center">
                  <p className="text-white/60 font-medium">No courses found</p>
                  <p className="text-white/30 text-sm mt-1">
                    {searchQuery
                      ? `No results for "${searchQuery}"`
                      : activeTab === 'inProgress'
                      ? 'You have no courses in progress yet.'
                      : activeTab === 'completed'
                      ? 'You have not completed any courses yet.'
                      : activeTab === 'bookmarked'
                      ? 'You have no bookmarked courses.'
                      : 'No courses match the selected filters.'}
                  </p>
                </div>
                {searchQuery && (
                  <button
                    onClick={() => setSearchQuery('')}
                    className="text-lyo-400 text-sm hover:text-lyo-300 transition-colors"
                  >
                    Clear search
                  </button>
                )}
              </motion.div>
            )}
          </AnimatePresence>
        )}
      </div>
    </div>
  );
}
