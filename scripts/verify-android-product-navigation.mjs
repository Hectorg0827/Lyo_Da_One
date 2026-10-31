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
const expectedOrder = [
  'BottomItem(Routes.HOME, "Focus"',
  'BottomItem(Routes.DISCOVER, "Discover"',
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

console.log('Android primary navigation and complete Create workflows match the supported iOS product hierarchy.');
