import { readFileSync } from 'node:fs';

const stories = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/screens/stories/StoriesScreen.kt', import.meta.url),
  'utf8',
);

function requireText(expected, label) {
  if (!stories.includes(expected)) {
    throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
  }
}

function rejectText(forbidden, label) {
  if (stories.includes(forbidden)) {
    throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
  }
}

for (const [expected, label] of [
  ['var loaded by remember', 'confirmed story load state'],
  ['var loadError by remember', 'story load failure state'],
  ['var pendingSeenIds by remember', 'pending seen-write state'],
  ['var confirmedSeenIds by remember', 'confirmed seen-write state'],
  ['var failedSeenStory by remember', 'targeted seen retry state'],
  ['loaded && stories.isEmpty()', 'confirmed story empty state'],
  ['.onFailure { error ->\n                loadError = storyError(error, "load stories")', 'visible story load failure'],
  ['LaunchedEffect(story.idStr)', 'active-story seen trigger'],
  ['runCatching { ApiClient.api.markStorySeen(storyId) }', 'real story seen write'],
  ['.onSuccess {\n                    confirmedSeenIds = confirmedSeenIds + storyId', 'confirmed seen transition'],
  ['.onFailure { error ->\n                    failedSeenStory = story', 'visible seen-write failure'],
  ['StorySeenError(', 'seen-write retry UI'],
  ['failedSeenStory?.let { failed ->', 'targeted seen retry'],
]) {
  requireText(expected, label);
}

const seenRequest = stories.indexOf('runCatching { ApiClient.api.markStorySeen(storyId) }');
const seenSuccess = stories.indexOf('.onSuccess {', seenRequest);
const seenMutation = stories.indexOf('confirmedSeenIds = confirmedSeenIds + storyId', seenRequest);
if (seenRequest < 0 || seenSuccess < seenRequest || seenMutation < seenSuccess) {
  throw new Error('Story seen state must become confirmed only after backend success.');
}

const goNextStart = stories.indexOf('fun goNext()');
const goNextEnd = stories.indexOf('fun goPrevious()', goNextStart);
const goNextBody = stories.slice(goNextStart, goNextEnd);
if (goNextBody.includes('markSeen(')) {
  throw new Error('Story seen writes must begin when a story is displayed, not only when advancing.');
}

for (const forbidden of [
  'runCatching { ApiClient.api.stories() }\n            .onSuccess { stories = it.stories.orEmpty() }',
  'scope.launch { runCatching { ApiClient.api.markStorySeen(s.idStr) } }',
  'if (stories.isEmpty()) {',
]) {
  rejectText(forbidden, 'Android Stories reliability');
}

console.log('Android Stories distinguishes load failures and retries confirmed seen writes.');