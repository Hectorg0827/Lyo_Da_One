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
requireText(home, 'SectionHeader("Explore Courses")', 'Android Focus catalog section');
requireText(home, 'StackRepository.listCourseStacks()', 'Android Focus real, backend-synced Stacks list');
requireText(home, 'ApiClient.api.courses(0, 5)', 'Android Focus public catalog exploration');
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

console.log('Android Focus sources Your Stacks from the real, device-agnostic backend list, separate from the public catalog.');