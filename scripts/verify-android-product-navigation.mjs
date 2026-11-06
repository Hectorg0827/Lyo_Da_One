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
const createCommunity = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreateCommunityItemScreen.kt');
const communityViewModel = read('android/app/src/main/java/com/lyo/app/ui/screens/community/CommunityMapViewModel.kt');

/**
 * Verify the routes actually used to build the Android bottom bar. Reading
 * the route list, rather than searching for the former five BottomItem()
 * literals, prevents a declaration refactor from turning a real UX fix into
 * a false regression. This checks the approved Web/Android hierarchy, not
 * the older iOS order: Focus / Discover / Lyo / Community / +.
 *
 * Exported for mutation tests: a swapped route, wrong label or an extra
 * Profile tab must fail even if every expected label appears elsewhere.
 */
export function verifyPrimaryTabs(source) {
  const declaration = source.match(/\binternal\s+val\s+primaryTabRoutes\s*=\s*listOf\(([^)]*)\)/);
  if (!declaration) throw new Error('Android primary navigation: no primaryTabRoutes declaration');
  const actual = [...declaration[1].matchAll(/\bRoutes\.([A-Z_]+)\b/g)].map(([, route]) => route);
  const expected = ['HOME', 'DISCOVER', 'CHAT', 'COMMUNITY', 'CREATE'];
  const otherTokens = declaration[1]
    .replace(/\bRoutes\.[A-Z_]+\b/g, '')
    .replace(/[\s,]/g, '');
  if (otherTokens || JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Android primary navigation: expected ${expected.join(' → ')}, got ${actual.join(' → ')}`);
  }

  for (const [route, label, icon] of [
    ['HOME', 'Focus', 'Home'],
    ['DISCOVER', 'Discover', 'PlayCircle'],
    ['CHAT', 'Lyo', 'SmartToy'],
    ['COMMUNITY', 'Community', 'People'],
    ['CREATE', 'Create', 'Add'],
  ]) {
    const mapping = new RegExp(`\\bRoutes\\.${route}\\s*->\\s*BottomItem\\(\\s*route\\s*,\\s*"${label}"\\s*,\\s*Icons\\.Filled\\.${icon}\\s*\\)`);
    if (!mapping.test(source)) {
      throw new Error(`Android primary navigation: missing ${route} / ${label} / ${icon} mapping`);
    }
  }
  requireText(source, 'label = if (item.route == Routes.CREATE) null', 'Android unlabeled + icon');
}

verifyPrimaryTabs(nav);

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

console.log('Android five-tab navigation (Focus, Discover, Lyo, Community, +) and Create workflows verified.');
