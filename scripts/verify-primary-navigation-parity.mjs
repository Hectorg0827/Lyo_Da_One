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

function requireOrdered(source, expected, label) {
  let cursor = -1;
  for (const value of expected) {
    const index = source.indexOf(value, cursor + 1);
    if (index < 0) throw new Error(`${label}: missing ordered value ${JSON.stringify(value)}`);
    if (index <= cursor) throw new Error(`${label}: incorrect order near ${JSON.stringify(value)}`);
    cursor = index;
  }
}

const ios = read('Sources/Views/MainTabView.swift');
const androidNav = read('android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt');
const androidCreate = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreateScreen.kt');

requireOrdered(
  ios,
  ['case focus', 'case clips', 'case create', 'case community', 'case profile'],
  'iOS primary navigation',
);

requireOrdered(
  androidNav,
  [
    'BottomItem(Routes.HOME, "Focus"',
    'BottomItem(Routes.CLIPS, "Clips"',
    'BottomItem(Routes.CREATE, "Create"',
    'BottomItem(Routes.COMMUNITY, "Community"',
    'BottomItem(Routes.PROFILE, "Profile"',
  ],
  'Android primary navigation',
);

requireText(androidNav, 'composable(Routes.CREATE) { CreateScreen(nav) }', 'Android Create route');
rejectText(androidNav, 'BottomItem(Routes.CHAT', 'Android primary navigation');

for (const [expected, label] of [
  ['ApiClient.api.uploadMedia', 'clip upload'],
  ['ApiClient.api.createClip', 'clip publish'],
  ['ApiClient.api.createCommunityPost', 'community post publish'],
  ['ApiClient.api.createStudyGroup', 'study group create'],
  ['ApiClient.api.createCommunityEvent', 'community event create'],
  ['nav.navigate(Routes.COURSES)', 'AI course generation route'],
  ['nav.navigate(Routes.CHAT)', 'contextual Lyo AI route'],
]) {
  requireText(androidCreate, expected, `Android Create ${label}`);
}

for (const forbidden of ['coming soon', 'Coming soon', 'placeholder', 'Placeholder']) {
  rejectText(androidCreate, forbidden, 'Android Create production surface');
}

console.log('Primary navigation and Android Create parity contract verified.');
