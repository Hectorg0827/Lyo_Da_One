import { readFileSync } from 'node:fs';

const community = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/screens/community/ReliableCommunityScreen.kt', import.meta.url),
  'utf8',
);
const navigation = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt', import.meta.url),
  'utf8',
);

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

for (const [source, expected, label] of [
  [navigation, 'import com.lyo.app.ui.screens.community.ReliableCommunityScreen', 'reliable Community route import'],
  [navigation, 'composable(Routes.COMMUNITY) { ReliableCommunityScreen(nav) }', 'reliable Community active route'],
  [community, 'var postsLoaded by remember { mutableStateOf(false) }', 'confirmed post load state'],
  [community, 'var groupsLoaded by remember { mutableStateOf(false) }', 'confirmed group load state'],
  [community, 'var eventsLoaded by remember { mutableStateOf(false) }', 'confirmed event load state'],
  [community, 'postsError != null && posts.isEmpty() && !loaded', 'post error before empty state'],
  [community, 'loaded && posts.isEmpty()', 'confirmed post empty state'],
  [community, 'val response = ApiClient.api.toggleCommunityPostLike(id)', 'post like request'],
  [community, 'val confirmedLiked = response.liked', 'confirmed like state'],
  [community, 'val confirmedCount = response.likeCount', 'confirmed like count'],
  [community, '.get("bookmarked")\n                    ?.asBoolean', 'confirmed bookmark state'],
  [community, '.onSuccess { (confirmedLiked, confirmedCount) ->', 'like mutation after success'],
  [community, '.onSuccess { confirmedBookmarked ->', 'bookmark mutation after success'],
  [community, '.onSuccess { confirmedJoined ->', 'group mutation after success'],
  [community, '.onSuccess { confirmedAttending ->', 'event mutation after success'],
  [community, 'pendingGroupIds = pendingGroupIds + id', 'group duplicate-write protection'],
  [community, 'pendingEventIds = pendingEventIds + id', 'event duplicate-write protection'],
  [community, 'SyncClient.events.collect', 'cross-device Community refresh'],
  [community, 'nav.navigate(Routes.CREATE_POST)', 'real post creation route'],
  [community, 'nav.navigate(Routes.CREATE_GROUP)', 'real group creation route'],
  [community, 'nav.navigate(Routes.CREATE_EVENT)', 'real event creation route'],
  [community, 'https://lyoai.app/community/$id', 'canonical Community share URL'],
  [community, 'ReliableCommunityEventMap(visibleEvents)', 'event map retained'],
  [community, 'peopleError = communityFailureMessage(it, "search for people")', 'visible people search failure'],
]) {
  requireText(source, expected, label);
}

for (const [source, forbidden, label] of [
  [navigation, 'composable(Routes.COMMUNITY) { CommunityScreen(nav) }', 'legacy Community must not be active'],
  [community, '.getOrDefault(emptyList())', 'failed sources must not become empty results'],
  [community, 'likedPostIds = if (wasLiked)', 'post likes must not mutate optimistically'],
  [community, 'joinedGroupIds = if (wasJoined)', 'group state must not mutate optimistically'],
  [community, 'attendingEventIds = if (wasAttending)', 'event state must not mutate optimistically'],
  [community, 'https://lyoapp.com/', 'obsolete share domain'],
]) {
  rejectText(source, forbidden, label);
}

const likeRequest = community.indexOf('val response = ApiClient.api.toggleCommunityPostLike(id)');
const likeSuccess = community.indexOf('.onSuccess { (confirmedLiked, confirmedCount) ->', likeRequest);
const likeMutation = community.indexOf('likedPostIds = if (confirmedLiked)', likeSuccess);
if (likeRequest < 0 || likeSuccess < likeRequest || likeMutation < likeSuccess) {
  throw new Error('Community post like state must change only after confirmed backend success.');
}

const bookmarkRequest = community.indexOf('ApiClient.api.toggleCommunityPostBookmark(id)');
const bookmarkSuccess = community.indexOf('.onSuccess { confirmedBookmarked ->', bookmarkRequest);
const bookmarkMutation = community.indexOf('bookmarkedPostIds = if (confirmedBookmarked)', bookmarkSuccess);
if (bookmarkRequest < 0 || bookmarkSuccess < bookmarkRequest || bookmarkMutation < bookmarkSuccess) {
  throw new Error('Community bookmark state must change only after confirmed backend success.');
}

console.log('Android Community uses independent recoverable sources and confirmed transactional state.');
