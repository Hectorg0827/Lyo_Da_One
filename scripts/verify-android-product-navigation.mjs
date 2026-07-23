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

const nav = read('android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt');
const createHub = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreateScreen.kt');
const createClip = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreateClipScreen.kt');
const createPost = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreatePostScreen.kt');

const expectedOrder = [
  'BottomItem(Routes.HOME, "Focus"',
  'BottomItem(Routes.CLIPS, "Clips"',
  'BottomItem(Routes.CREATE, "Create"',
  'BottomItem(Routes.COMMUNITY, "Community"',
  'BottomItem(Routes.PROFILE, "Profile"',
];

let previousIndex = -1;
for (const marker of expectedOrder) {
  const index = nav.indexOf(marker);
  if (index < 0) throw new Error(`Android primary navigation: missing ${marker}`);
  if (index <= previousIndex) throw new Error('Android primary navigation order does not match iOS product hierarchy');
  previousIndex = index;
}

rejectText(nav, 'BottomItem(Routes.CHAT', 'Android primary navigation');
requireText(nav, 'composable(Routes.CREATE) { CreateScreen(nav) }', 'Android Create route');
requireText(nav, 'composable(Routes.CREATE_CLIP) { CreateClipScreen(nav) }', 'Android clip creator route');
requireText(nav, 'composable(Routes.CREATE_POST) { CreatePostScreen(nav) }', 'Android post creator route');

requireText(createHub, 'Every visible action is connected to a real service.', 'Android Create honesty');
requireText(createHub, 'Routes.CREATE_CLIP', 'Android Create clip entry');
requireText(createHub, 'Routes.CREATE_POST', 'Android Create post entry');
requireText(createHub, 'Routes.CHAT', 'Android contextual Lyo AI entry');
rejectText(createHub, 'Advertiser', 'Android Create honesty');
rejectText(createHub, 'Coming soon', 'Android Create honesty');

requireText(createClip, 'ApiClient.api.uploadMedia', 'Android clip upload');
requireText(createClip, 'ApiClient.api.createClip', 'Android clip publish');
requireText(createClip, 'ActivityResultContracts.GetContent()', 'Android system media picker');
requireText(createPost, 'ApiClient.api.createCommunityPost', 'Android community post publish');

console.log('Android primary navigation and Create workflows match the supported iOS product hierarchy.');
