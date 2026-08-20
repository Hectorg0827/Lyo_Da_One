import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const community = read('android/app/src/main/java/com/lyo/app/ui/screens/community/LearningAroundCommunityScreen.kt');
const navigation = read('android/app/src/main/java/com/lyo/app/ui/navigation/LyoNavHost.kt');
const api = read('android/app/src/main/java/com/lyo/app/data/api/LyoApiService.kt');
const creation = read('android/app/src/main/java/com/lyo/app/ui/screens/create/CreateCommunityItemScreen.kt');

function requireText(source, expected, label) {
  if (!source.includes(expected)) throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
}

function rejectText(source, forbidden, label) {
  if (source.includes(forbidden)) throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
}

for (const [source, expected, label] of [
  [navigation, 'import com.lyo.app.ui.screens.community.LearningAroundCommunityScreen', 'map-first Community route import'],
  [navigation, 'composable(Routes.COMMUNITY) { LearningAroundCommunityScreen(nav) }', 'map-first Community active route'],
  [community, 'val labels = listOf("Around Me", "My Community", "Activity")', 'shared tabs'],
  [community, 'var selectedTab by remember { mutableIntStateOf(0) }', 'Around Me default'],
  [community, 'ApiClient.api.nearbyLearning(', 'nearby learning source'],
  [community, 'ApiClient.api.myCommunity()', 'account-owned state source'],
  [community, 'LearningMapWebView(', 'multi-marker map hero'],
  [community, 'L.marker([n.latitude,n.longitude]', 'multiple Leaflet markers'],
  [community, 'LearningNodeSheet(', 'in-place map drawer'],
  [community, 'ApiClient.api.saveLearningNode', 'account save request'],
  [community, 'ApiClient.api.unsaveLearningNode', 'account unsave request'],
  [community, 'SyncClient.events.collect', 'cross-device Community refresh'],
  [community, 'event.eventType in setOf("community_updated", "context_updated")', 'Community sync event'],
  [community, '.onSuccess { reload += 1 }', 'state refresh after confirmed write'],
  [community, 'nav.navigate(Routes.CREATE_EVENT)', 'event creation route'],
  [community, 'nav.navigate(Routes.CREATE_GROUP)', 'group creation route'],
  [community, 'nav.navigate(Routes.CREATE_TUTOR)', 'tutor creation route'],
  [api, '@GET("community/nearby")', 'nearby API'],
  [api, '@GET("community/me")', 'account state API'],
  [api, '@PUT("community/saved-nodes/{kind}/{nodeId}")', 'save API'],
  [creation, 'latitude = if (isOnline) null else coordinates?.first', 'geolocated creation'],
  [creation, 'CreatePrivateLessonRequest(', 'tutor creation payload'],
]) requireText(source, expected, label);

for (const [source, forbidden, label] of [
  [navigation, 'composable(Routes.COMMUNITY) { ReliableCommunityScreen(nav) }', 'feed-first Community must not be active'],
  [community, 'SharedPreferences', 'Community account state cannot be device-owned'],
  [community, 'rememberSaveable', 'Community account state cannot be navigation-owned'],
  [community, 'joinedGroupIds = if', 'group state must not mutate optimistically'],
  [community, 'attendingEventIds = if', 'event state must not mutate optimistically'],
]) rejectText(source, forbidden, label);

console.log('Android Community is map-first and refreshes canonical account state after confirmed writes.');
