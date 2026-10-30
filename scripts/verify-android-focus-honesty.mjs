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
    throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
  }
}

const home = read('android/app/src/main/java/com/lyo/app/ui/screens/home/HomeScreen.kt');
const navigation = read('android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt');
const recentStore = read('android/app/src/main/java/com/lyo/app/data/RecentCourseStore.kt');

// "Your Learning"/RecentCourseStore (a single-slot, device-local pointer)
// was superseded by "Your Stacks" — a real, backend-synced, multi-item list
// (StackRepository) that's device- and platform-agnostic by design, so a
// course started here also shows up on iOS/web. RecentCourseStore itself
// is intentionally left in place (still written to on course-detail visits
// — see the navigation assertion below) but is no longer HomeScreen's
// source of truth.
requireText(home, 'SectionHeader("Your Stacks")', 'Android Focus learner section');
requireText(home, 'StackRepository.listCourseStacks()', 'Android Focus real, backend-synced Stacks list');
requireText(home, 'ApiClient.api.dueReviews()', 'Android Focus canonical review schedule');
requireText(home, 'SectionHeader("Next for you")', 'Android Focus recommendations section');
requireText(home, 'LearnerStatsStrip(', 'Android Focus compact Web-equivalent stats strip');
rejectText(home, 'SectionHeader("Explore Courses")', 'Web parity: no duplicate catalog tiles on Focus');
rejectText(home, 'SectionHeader("Learning Actions")', 'Web parity: no duplicate navigation tiles on Focus');
rejectText(home, 'ApiClient.api.courses(0, 5)', 'Web parity: Focus should not prefetch a public catalog it no longer displays');
requireText(home, 'Routes.reviewClassroom(', 'Android Focus review entry');
requireText(navigation, 'RecentCourseStore.save(context, courseId)', 'Android real course visit recording');
requireText(recentStore, 'Device-local pointer', 'Android recent-course scope disclosure');

for (const forbidden of [
  'SectionHeader("Continue Learning")',
  'SectionHeader("Your Learning")',
  'ApiClient.api.publicFeed',
  'SectionHeader("Community Activity")',
  'PostDto',
  'course_title',
  'progress_percent',
]) {
  rejectText(home + recentStore, forbidden, 'Android Focus honesty');
}

console.log('Android Focus sources personalized learning from the real backend and matches Web without duplicate stock catalog tiles.');