import { readFileSync } from 'node:fs';

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
}

function requireText(source, expected, label) {
  if (!source.includes(expected)) {
    throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
  }
}

function rejectText(source, forbidden, label) {
  if (source.includes(forbidden)) {
    throw new Error(`${label}: forbidden stale contract ${JSON.stringify(forbidden)}`);
  }
}

const web = read('web/src/lib/learning-progress.ts');
const androidApi = read('android/app/src/main/java/com/lyo/app/data/api/LearningProgressApi.kt');
const androidPlayer = read('android/app/src/main/java/com/lyo/app/ui/screens/courses/CourseDetailScreen.kt');
const iosStore = read('Sources/Services/UIStackStore.swift');

for (const [source, label] of [
  [web, 'web learning progress'],
  [androidApi, 'Android learning progress'],
]) {
  requireText(source, 'learning/completions', label);
  requireText(source, 'learning/users/me/courses/', label);
  requireText(source, 'lesson_id', label);
}

requireText(web, 'markLessonComplete', 'web lesson player contract');
requireText(web, 'getCourseProgress', 'web progress hydration contract');
requireText(androidApi, 'completed_lesson_ids', 'Android canonical completed lesson IDs');
requireText(androidApi, 'completedLessonIdStrings', 'Android completion ID normalization');
requireText(androidPlayer, 'ApiClient.learning.markLessonComplete', 'Android lesson completion write');
requireText(androidPlayer, 'ApiClient.learning.courseProgress', 'Android progress hydration');
requireText(androidPlayer, 'previousCompletedIds', 'Android optimistic rollback');
requireText(androidPlayer, 'reconcileCompletedLessonIds', 'Android canonical completion reconciliation');
requireText(iosStore, 'refreshCourseProgressFromBackend', 'iOS progress hydration');
requireText(iosStore, 'repository.getCourseProgress', 'iOS canonical progress read');
rejectText(iosStore, 'Synced course progress to backend', 'iOS false progress write');

console.log('Learning progress parity contract verified for web, Android, and iOS hydration.');