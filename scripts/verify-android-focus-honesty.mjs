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

requireText(home, 'SectionHeader("Your Learning")', 'Android Focus learner section');
requireText(home, 'SectionHeader("Explore Courses")', 'Android Focus catalog section');
requireText(home, 'RecentCourseStore.load(context)', 'Android Focus real recent-course pointer');
requireText(home, 'ApiClient.api.course(storedRecent.id)', 'Android Focus backend course hydration');
requireText(home, 'ApiClient.api.courses(0, 5)', 'Android Focus public catalog exploration');
requireText(home, 'account progress refreshes when opened', 'Android Focus progress disclosure');
requireText(navigation, 'RecentCourseStore.save(context, courseId)', 'Android real course visit recording');
requireText(recentStore, 'Device-local pointer', 'Android recent-course scope disclosure');

for (const forbidden of [
  'SectionHeader("Continue Learning")',
  'ApiClient.api.publicFeed',
  'SectionHeader("Community Activity")',
  'PostDto',
  'course_title',
  'progress_percent',
]) {
  rejectText(home + recentStore, forbidden, 'Android Focus honesty');
}

console.log('Android Focus separates real device learning activity from the public catalog.');