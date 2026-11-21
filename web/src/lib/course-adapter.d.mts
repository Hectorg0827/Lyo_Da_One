import type { CourseModule, LessonBlock } from '@/types';

export function normalizeLessonBlocks(value: unknown, lessonId: string): LessonBlock[];
export function normalizeCourseModules(raw: Record<string, unknown>): CourseModule[];
