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
const clipCamera = read('android/app/src/main/java/com/lyo/app/ui/screens/create/ClipCameraCapture.kt');
const createPost = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreatePostScreen.kt');
const createCommunity = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreateCommunityItemScreen.kt');
const manifest = read('android/app/src/main/AndroidManifest.xml');
const gradle = read('android/app/build.gradle.kts');

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
requireText(nav, 'composable(Routes.CREATE_GROUP)', 'Android group creator route');
requireText(nav, 'composable(Routes.CREATE_EVENT)', 'Android event creator route');

requireText(createHub, 'Every visible action is connected to a real service.', 'Android Create honesty');
for (const route of [
  'Routes.CREATE_CLIP',
  'Routes.CREATE_POST',
  'Routes.CREATE_GROUP',
  'Routes.CREATE_EVENT',
  'Routes.COURSES',
  'Routes.CHAT',
]) {
  requireText(createHub, route, 'Android Create entry');
}
rejectText(createHub, 'Advertiser', 'Android Create honesty');
rejectText(createHub, 'Coming soon', 'Android Create honesty');

requireText(createClip, 'ApiClient.api.uploadMedia', 'Android clip upload');
requireText(createClip, 'ApiClient.api.createClip', 'Android clip publish');
requireText(createClip, 'ActivityResultContracts.GetContent()', 'Android system media picker');
requireText(createClip, 'ClipCameraCapture(', 'Android native clip capture entry');
requireText(createClip, 'UriRequestBody', 'Android streamed clip upload');
rejectText(createClip, 'CameraX workflow is implemented', 'Android stale camera placeholder');

for (const marker of [
  'ProcessCameraProvider',
  'VideoCapture<Recorder>',
  'prepareRecording',
  'withAudioEnabled',
  'CameraSelector.LENS_FACING_FRONT',
  'enableTorch',
  'MAX_RECORDING_MILLIS',
  'onOpenLibrary',
]) {
  requireText(clipCamera, marker, 'Android CameraX capture');
}

requireText(manifest, 'android.permission.CAMERA', 'Android camera permission');
requireText(manifest, 'android.permission.RECORD_AUDIO', 'Android microphone permission');
requireText(gradle, 'androidx.camera:camera-video', 'Android CameraX video dependency');
requireText(gradle, 'androidx.camera:camera-view', 'Android CameraX preview dependency');

requireText(createPost, 'ApiClient.api.createCommunityPost', 'Android community post publish');
requireText(createCommunity, 'ApiClient.api.createStudyGroup', 'Android study group publish');
requireText(createCommunity, 'ApiClient.api.createCommunityEvent', 'Android event publish');
requireText(createCommunity, 'end.isAfter(start)', 'Android event time validation');

console.log('Android primary navigation, native clip capture, and complete Create workflows match the supported iOS product hierarchy.');