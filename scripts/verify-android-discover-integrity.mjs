import { readFileSync } from 'node:fs';

const discover = readFileSync(
  new URL('../android/app/src/main/java/com/lyo/app/ui/screens/discover/DiscoverScreen.kt', import.meta.url),
  'utf8',
);

function requireText(expected, label) {
  if (!discover.includes(expected)) {
    throw new Error(`${label}: missing ${JSON.stringify(expected)}`);
  }
}

function rejectText(forbidden, label) {
  if (discover.includes(forbidden)) {
    throw new Error(`${label}: forbidden ${JSON.stringify(forbidden)}`);
  }
}

for (const [expected, label] of [
  ['var placesError by remember', 'places error state'],
  ['var eventsError by remember', 'events error state'],
  ['var classesError by remember', 'online classes error state'],
  ['var reloadVersion by remember', 'Discover retry state'],
  ['.onFailure { placesError = discoverError(it, "places") }', 'places failure handling'],
  ['.onFailure { eventsError = discoverError(it, "events") }', 'events failure handling'],
  ['.onFailure { classesError = discoverError(it, "online classes") }', 'class failure handling'],
  ['filter { it.rating != null }', 'rated-place filtering'],
  ['place.rating?.let { rating ->', 'optional place rating display'],
  ['course.subject?.takeIf { it.isNotBlank() }?.let { subject ->', 'optional course subject display'],
  ['activeTab == "All" && !hasVisibleData && !hasVisibleError', 'honest global empty state'],
  ['DiscoverErrorCard(', 'recoverable source failures'],
]) {
  requireText(expected, label);
}

for (const forbidden of [
  'place.rating ?: 0.0',
  'it.rating ?: 0.0',
  'course.subject ?: "General"',
  'places.isEmpty() && events.isEmpty() && classes.isEmpty()',
  'text = " ${place.rating ?: 0.0}',
]) {
  rejectText(forbidden, 'Android Discover integrity');
}

console.log('Android Discover distinguishes source failures and omits missing metadata.');