import { readFileSync } from 'node:fs';

const profile = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/screens/profile/ProfileScreen.kt', import.meta.url),
  'utf8',
);

function requireText(expected, label) {
  if (!profile.includes(expected)) {
    throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
  }
}

function rejectText(forbidden, label) {
  if (profile.includes(forbidden)) {
    throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
  }
}

// "Clips" is a creator's own work and what it has added up to. It sits beside
// Activity rather than inside Stats, because Stats is learning progress — XP,
// streaks, level — and a creator checking whether anyone watched is asking a
// different question.
requireText(
  'private val OwnProfileTabs = listOf("Activity", "Clips", "Achievements", "Stats")',
  'owner-only profile tabs',
);

// A figure the backend did not send is never drawn as a zero: a creator whose
// views are not being counted needs to know that, not be told nobody watched.
// The library size goes in with the page: the clips endpoint is paged, so
// totalling one page and calling it the creator's total is the same mistake
// as summing a missing count as zero.
requireText('CreatorStats.totals(myClips, myClipsTotal)', 'owner clip totals measured against the library');
requireText('"Not reported"', 'unreported clip metric is not a zero');
requireText('clipsError', 'clips loading failure state');
requireText('private val PublicProfileTabs = listOf("Activity")', 'public profile tabs');
requireText('if (isOwn) {', 'current-user data gate');
requireText('ApiClient.api.achievements()', 'owner achievements endpoint');
requireText('ApiClient.api.gamificationOverview()', 'owner gamification endpoint');
requireText('profileError', 'profile loading failure state');
requireText('activityError', 'activity loading failure state');
requireText('followPending', 'transactional follow state');
requireText('.onSuccess { following = !following }', 'confirmed follow state transition');
requireText('.onFailure { followError = followActionMessage(it) }', 'visible follow failure');
requireText('xp = runCatching { obj.get("xp_reward")?.asInt }.getOrNull() ?: 0', 'non-fabricated achievement XP');

const ownerGate = profile.indexOf('if (isOwn) {');
const achievementCall = profile.indexOf('ApiClient.api.achievements()');
const statsCall = profile.indexOf('ApiClient.api.gamificationOverview()');
if (ownerGate < 0 || achievementCall < ownerGate || statsCall < ownerGate) {
  throw new Error('Current-user achievements and stats must remain inside the owner-only gate.');
}

for (const forbidden of [
  'ApiClient.api.courses(',
  '"Courses" ->',
  'ProfileTabs = listOf("Activity", "Courses"',
  'CourseDto',
  'CardGradients',
  'xp = runCatching { obj.get("xp_reward")?.asInt }.getOrNull() ?: 100',
]) {
  rejectText(forbidden, 'Android Profile integrity');
}

console.log('Android Profile uses profile-scoped data and confirmed social actions only.');