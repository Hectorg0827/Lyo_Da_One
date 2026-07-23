import fs from 'node:fs';

const contracts = [
  {
    name: 'web progress client',
    path: 'web/src/lib/learning-progress.ts',
    needles: [
      '/learning/completions',
      '/learning/users/me/courses/',
      'lesson_id',
      'normalizeProgressPercent',
    ],
  },
  {
    name: 'web lesson player',
    path: 'web/src/components/courses/CoursePlayer.tsx',
    needles: [
      'markLessonComplete',
      'getCourseProgress',
      'completedLessonIds',
      'previousCompleted',
    ],
  },
  {
    name: 'Android progress client',
    path: 'android/app/src/main/java/com/lyo/app/data/api/LearningProgressClient.kt',
    needles: [
      'learning/completions',
      'learning/users/me/courses',
      'markLessonComplete',
      'getCourseProgress',
    ],
  },
  {
    name: 'Android lesson player',
    path: 'android/app/src/main/java/com/lyo/app/ui/screens/courses/CourseDetailScreen.kt',
    needles: [
      'completedIds',
      'completionIdsFromProgress',
      'resumeIndex',
      'previousIds',
      'LearningProgressClient.markLessonComplete',
    ],
  },
  {
    name: 'iOS progress hydration',
    path: 'Sources/Services/UIStackStore.swift',
    needles: [
      'refreshCourseProgressFromBackend',
      'getCourseProgress',
      'progressPercent',
      'completedLessons',
    ],
  },
];

const failures = [];
for (const contract of contracts) {
  const source = fs.readFileSync(contract.path, 'utf8');
  for (const needle of contract.needles) {
    if (!source.includes(needle)) failures.push(`${contract.name}: missing ${needle}`);
  }
}

if (failures.length > 0) {
  console.error('Cross-device learning continuity contract failed:');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log(
  'Learning continuity contract: web and Android persist lesson completion; iOS hydrates canonical server progress pending the classroom lesson-id contract.',
);
