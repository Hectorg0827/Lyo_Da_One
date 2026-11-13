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
const bottomBar = read('android/app/src/main/java/com/lyo/app/ui/navigation/LyoBottomBar.kt');
const createHub = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreateScreen.kt');
const createClip = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreateClipScreen.kt');
const createPost = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreatePostScreen.kt');
const createCommunity = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreateCommunityItemScreen.kt');
const communityViewModel = read('android/app/src/main/java/com/lyo/app/ui/screens/community/CommunityMapViewModel.kt');

// The second tab is the clip reel. It used to be labelled "Clips" while
// "discover" opened an unrelated places-and-events browser nothing linked to,
// so the same feed had two names and one of them pointed somewhere else. It
// is Discover on all three platforms now — iOS shows the same reel, web
// serves it at /discover — and the reel is what this tab opens.
const expectedTabs = [
  ['HOME', 'Focus'],
  ['DISCOVER', 'Discover'],
  ['CHAT', 'Lyo'],
  ['COMMUNITY', 'Community'],
  ['CREATE', '+'],
];

// Verify the *entire* list rather than merely finding five strings in order.
// The older check silently accepted a sixth bottom tab or a duplicate route.
const declaredTabs = nav.match(/private val bottomItems\s*=\s*listOf\(([\s\S]*?)\n\)/);
if (!declaredTabs) throw new Error('Android primary navigation list is missing');
const tabEntries = [...declaredTabs[1].matchAll(/BottomItem\(\s*Routes\.([A-Z_]+)\s*,\s*"([^"]+)"\s*,/g)]
  .map((match) => [match[1], match[2]]);
const rawEntryCount = (declaredTabs[1].match(/\bBottomItem\s*\(/g) || []).length;
if (rawEntryCount !== expectedTabs.length || tabEntries.length !== expectedTabs.length ||
    tabEntries.some(([route, label], i) =>
      route !== expectedTabs[i][0] || label !== expectedTabs[i][1])) {
  throw new Error(
    'Android primary navigation must contain exactly Focus / Discover / Lyo / Community / +: ' +
    JSON.stringify(tabEntries),
  );
}

requireText(nav, 'composable(Routes.CHAT) { ChatScreen(nav) }', 'Android Lyo chat route');

// Edge-to-edge rendering is enabled by MainActivity. Keep the native tab row
// above either gesture navigation or Samsung's three-button system bar.
requireText(bottomBar, '.navigationBarsPadding()', 'Android bottom navigation system insets');

// The visible mobile bar must keep all five destinations in product order,
// including Community; a hidden launch gate must not replace it with whitespace.
const visibleTabOrder = [
  'GhostTab("Focus", Routes.HOME',
  'GhostTab("Discover", Routes.DISCOVER',
  'contentDescription = "Ask Lyo"',
  'GhostTab("Community", Routes.COMMUNITY',
  'GhostTab("Create", Routes.CREATE',
];
let lastVisibleIndex = -1;
for (const marker of visibleTabOrder) {
  const index = bottomBar.indexOf(marker);
  if (index < 0 || index <= lastVisibleIndex) {
    throw new Error(`Android visible tab order is wrong: ${marker}`);
  }
  lastVisibleIndex = index;
}
const renderedBar = bottomBar.match(/internal fun LyoBottomBar\([\s\S]*?\n\}\n\n@Composable\nprivate fun RowScope\.GhostTab/);
if (!renderedBar || (renderedBar[0].match(/\bGhostTab\("/g) || []).length !== 4) {
  throw new Error('Android visible navigation must have exactly four glyph tabs plus the Lyo mascot');
}
requireText(bottomBar, '.semantics { contentDescription = label }', 'Accessible tab descriptions');
const homeScreen = read('android/app/src/main/java/com/lyo/app/ui/screens/home/HomeScreen.kt');
requireText(homeScreen, 'nav.navigate(Routes.PROFILE)', 'Learner own-profile entry');

rejectText(bottomBar, 'communityLaunchEnabled = false', 'Android Community tab availability');
// The + glyph must open the current creation studio, not the legacy sheet.
// A prior APK had the new CreateScreen but the tab still intercepted it.
requireText(bottomBar,
  'GhostTab("Create", Routes.CREATE, "create", currentRoute == Routes.CREATE, onNavigate)',
  'Android Create studio entry');
rejectText(bottomBar, 'LyoCreateSheet(', 'Android legacy Create sheet interception');
requireText(nav, 'composable(Routes.COMMUNITY) { LearningAroundCommunityScreen(nav) }', 'Community tab navigation');


// Both names reach the one reel. "clips" stays registered because links to it
// have already been shared, and a shared clip that opens nothing is worse than
// an extra route. The places browser keeps its own route rather than sitting
// on "discover", where it answered to a name that belongs to the feed.
requireText(nav, 'composable(Routes.DISCOVER) { ClipsScreen(nav) }', 'Android Discover reel route');
requireText(nav, 'composable(Routes.CLIPS) { ClipsScreen(nav) }', 'Android legacy clips route');
requireText(nav, 'composable(Routes.PLACES) { DiscoverScreen(nav) }', 'Android places browser route');
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
requireText(createPost, 'ApiClient.api.createCommunityPost', 'Android community post publish');
requireText(createCommunity, 'ApiClient.api.createStudyGroup', 'Android study group publish');
requireText(createCommunity, 'vm.createEvent(', 'Android event publish');
requireText(communityViewModel, 'api.createCommunityEvent(request)', 'Android event publish request');
requireText(createCommunity, 'endAt.isAfter(startAt)', 'Android event time validation');


// The Discover creator control belongs on the left of the video, away from
// the Like/Comment/Share/Save rail on compact Samsung displays.
const clipScreen = read('android/app/src/main/java/com/lyo/app/ui/screens/clips/ClipsScreen.kt');
const createPillCall = clipScreen.slice(
  clipScreen.indexOf('CreateVideoPill('),
  clipScreen.indexOf('CreateVideoPill(') + 550,
);
requireText(createPillCall, '.align(Alignment.TopStart)', 'Discover Create control placement');
rejectText(createPillCall, '.align(Alignment.TopEnd)', 'Discover Create control placement');

console.log('Android primary navigation and complete Create workflows match the supported approved LYO hierarchy.');

// Guard the shipped screen and the course handoff, not only unused route metadata.
requireText(nav, 'LyoBottomBar(currentRoute)', 'Rendered Android navigation');
const courses = read('android/app/src/main/java/com/lyo/app/ui/screens/courses/CoursesScreen.kt');
const chat = read('android/app/src/main/java/com/lyo/app/ui/screens/chat/ChatScreen.kt');
const api = read('android/app/src/main/java/com/lyo/app/data/api/LyoApiService.kt');
rejectText(api, 'api/v1/learning/courses/generate', 'Unsupported course endpoint');
for (const [source, label] of [[courses, 'Courses'], [createHub, 'Create']]) {
  requireText(source, '"lyo_chat_seed_prompt"', label + ' course handoff');
  requireText(source, 'nav.navigate(Routes.CHAT)', label + ' course destination');
}
requireText(chat, '?.remove<String>("lyo_chat_seed_prompt")', 'Single-use course prompt');
requireText(chat, 'send(seededPrompt)', 'Course prompt is submitted to canonical Chat');
