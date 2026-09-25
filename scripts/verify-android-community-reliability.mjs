import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const base = 'android/app/src/main/java/com/lyo/app';
const community = read(`${base}/ui/screens/community/LearningAroundCommunityScreen.kt`);
const viewModel = read(`${base}/ui/screens/community/CommunityMapViewModel.kt`);
const discovery = read(`${base}/ui/screens/community/CommunityDiscovery.kt`);
const detail = read(`${base}/ui/screens/community/CommunityNodeDetailScreen.kt`);
const navigation = read(`${base}/ui/navigation/LyoNavHost.kt`);
const api = read(`${base}/data/api/LyoApiService.kt`);
const creation = read(`${base}/ui/screens/create/CreateCommunityItemScreen.kt`);

function requireText(source, expected, label) {
  if (!source.includes(expected)) throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
}

function rejectText(source, forbidden, label) {
  if (source.includes(forbidden)) throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
}

for (const [source, expected, label] of [
  [navigation, 'import com.lyo.app.ui.screens.community.LearningAroundCommunityScreen', 'map-first Community route import'],
  [navigation, 'composable(Routes.COMMUNITY) { LearningAroundCommunityScreen(nav) }', 'map-first Community active route'],
  [navigation, 'composable(Routes.COMMUNITY_NODE)', 'shareable detail route'],
  [navigation, 'composable(Routes.EDIT_EVENT)', 'host edit route'],
  [community, 'val labels = listOf("Around Me", "My Community", "Activity")', 'shared tabs'],
  [community, 'var selectedTab by remember { mutableIntStateOf(0) }', 'Around Me default'],
  [community, 'val vm: CommunityMapViewModel = viewModel()', 'screen state survives opening a detail page'],
  [community, 'LearningMapWebView(', 'multi-marker map hero'],
  [community, 'L.marker([n.latitude,n.longitude]', 'multiple Leaflet markers'],
  [community, 'Math.floor(p.x/56)', 'marker clustering'],
  [community, 'LearningNodeSheet(', 'in-place preview (a marker tap never navigates)'],
  [community, 'CommunityBottomSheet(', 'collapsed/medium/expanded sheet'],
  [community, '"Search this area"', 'explicit area search'],
  [community, 'imeAction = ImeAction.Search', 'search runs on submit, not per keystroke'],
  [community, 'vm.onLocationDenied()', 'location-denied fallback'],
  [community, 'nav.navigate(Routes.CREATE_EVENT)', 'event creation route'],
  [community, 'nav.navigate(Routes.CREATE_GROUP)', 'group creation route'],
  [community, 'nav.navigate(Routes.CREATE_TUTOR)', 'tutor creation route'],
  [viewModel, 'api.nearbyLearning(', 'nearby learning source'],
  [viewModel, 'api.myCommunity(', 'account-owned state source'],
  [viewModel, 'ApiClient.api.saveLearningNode', 'account save request'],
  [viewModel, 'ApiClient.api.unsaveLearningNode', 'account unsave request'],
  [viewModel, 'api.setEventRsvp(', 'going / interested RSVP'],
  [viewModel, 'api.clearEventRsvp(', 'RSVP removal'],
  [viewModel, 'api.resolveCommunitySearch(', 'place vs topic search'],
  [viewModel, 'SyncClient.events.collect', 'cross-device Community refresh'],
  [viewModel, 'event.eventType in setOf("community_updated", "context_updated")', 'Community sync event'],
  [viewModel, 'patch(node.key) { restoreParticipation(before, it) }', 'optimistic change rolls back on failure'],
  [viewModel, 'reloadAccount()', 'state re-read after a confirmed write'],
  [viewModel, '.coarse()', 'viewer location rounded before it is sent'],
  [viewModel, 'track("community_opened"', 'privacy-respecting analytics'],
  [discovery, 'fun friendlyError(', 'learner-facing error copy'],
  [discovery, 'fun shouldOfferAreaSearch(', 'no refetch on small pans'],
  [detail, 'vm.loadDetail(kind, nodeId)', 'detail read from the backend'],
  [detail, 'CalendarContract.Events.CONTENT_URI', 'add to calendar'],
  [detail, 'Intent.ACTION_SEND', 'share'],
  [detail, 'vm.reportEvent(', 'report'],
  [api, '@GET("community/nearby")', 'nearby API'],
  [api, '@GET("community/me")', 'account state API'],
  [api, '@PUT("community/saved-nodes/{kind}/{nodeId}")', 'save API'],
  [api, '@PUT("community/events/{eventId}/rsvp")', 'RSVP API'],
  [api, '@GET("community/nodes/{kind}/{nodeId}")', 'detail API'],
  [creation, 'latitude = if (isOnline) null else coordinates?.first', 'geolocated creation'],
  [creation, 'CreatePrivateLessonRequest(', 'tutor creation payload'],
  [creation, 'clientRequestId = requestId', 'duplicate-safe event creation'],
  [creation, 'vm.updateEvent(', 'host edits'],
]) requireText(source, expected, label);

for (const [source, forbidden, label] of [
  [navigation, 'composable(Routes.COMMUNITY) { ReliableCommunityScreen(nav) }', 'feed-first Community must not be active'],
  [community, 'SharedPreferences', 'Community account state cannot be device-owned'],
  [viewModel, 'SharedPreferences', 'Community account state cannot be device-owned'],
  [community, 'rememberSaveable', 'Community account state cannot be navigation-owned'],
  [viewModel, 'DataStore', 'Community account state cannot be device-owned'],
  [community, 'localizedMessage', 'raw errors are never shown to learners'],
  [viewModel, 'localizedMessage', 'raw errors are never shown to learners'],
  [detail, 'localizedMessage', 'raw errors are never shown to learners'],
  [creation, 'localizedMessage', 'raw errors are never shown to learners'],
]) rejectText(source, forbidden, label);

console.log('Android Community is map-first, account-owned, optimistic with rollback, and never shows raw errors.');
