import test from 'node:test';
import assert from 'node:assert/strict';
import {
  FILTERS,
  NODE_CATEGORIES,
  areaForBounds,
  buildIcs,
  categoryLabel,
  clusterNodes,
  detailPath,
  directionsUrl,
  distanceKm,
  filtersToQuery,
  formatDistance,
  formatPrice,
  formatWhen,
  friendlyError,
  googleCalendarUrl,
  safeWebUrl,
  shouldOfferAreaSearch,
  toggleFilter,
} from './community-contract.mjs';

const node = (overrides = {}) => ({
  key: 'event:1',
  kind: 'event',
  category: 'event',
  id: '1',
  title: 'SAT Prep, Session 1',
  latitude: 40.713,
  longitude: -74.005,
  starts_at: '2026-09-27T22:00:00Z',
  ends_at: '2026-09-28T00:00:00Z',
  ...overrides,
});

test('every map category has a filter chip that can show it', () => {
  const reachable = new Set(FILTERS.flatMap((filter) => filter.categories ?? []));
  for (const category of NODE_CATEGORIES) assert.ok(reachable.has(category), category);
});

test('filters combine: categories union, modifiers narrow', () => {
  let active = new Set();
  active = toggleFilter(active, 'workshops');
  active = toggleFilter(active, 'libraries');
  active = toggleFilter(active, 'free');
  active = toggleFilter(active, 'week');
  assert.deepEqual(filtersToQuery(active), {
    categories: ['library', 'workshop'],
    placeTypes: [],
    freeOnly: true,
    when: 'week',
    nearby: false,
  });
});

test('today and this week are mutually exclusive, and chips toggle off', () => {
  let active = toggleFilter(new Set(), 'today');
  active = toggleFilter(active, 'week');
  assert.deepEqual([...active], ['week']);
  active = toggleFilter(active, 'week');
  assert.equal(active.size, 0);
});

test('schools and learning centers narrow the same category by place type', () => {
  const schools = filtersToQuery(new Set(['schools']));
  assert.deepEqual(schools.categories, ['educational_center']);
  assert.deepEqual(schools.placeTypes, ['college', 'university']);
  const both = filtersToQuery(new Set(['schools', 'learning_centers']));
  assert.ok(both.placeTypes.includes('language_school') && both.placeTypes.includes('university'));
});

test('no chips means everything', () => {
  assert.deepEqual(filtersToQuery(new Set()), {
    categories: [], placeTypes: [], freeOnly: false, when: null, nearby: false,
  });
});

test('viewport area is the center and half-diagonal, capped', () => {
  const area = areaForBounds({ north: 40.8, south: 40.6, east: -73.9, west: -74.1 });
  assert.ok(Math.abs(area.latitude - 40.7) < 1e-9);
  assert.ok(area.radiusKm > 12 && area.radiusKm < 16, String(area.radiusKm));
  const huge = areaForBounds({ north: 60, south: 20, east: 10, west: -60 });
  assert.equal(huge.radiusKm, 50);
});

test('"Search this area" appears only after a meaningful move or zoom', () => {
  const searched = { latitude: 40.7128, longitude: -74.006, radiusKm: 10 };
  assert.equal(shouldOfferAreaSearch(searched, { ...searched, latitude: 40.72 }), false);
  assert.equal(shouldOfferAreaSearch(searched, { ...searched, latitude: 40.8 }), true);
  assert.equal(shouldOfferAreaSearch(searched, { ...searched, radiusKm: 25 }), true);
  assert.equal(shouldOfferAreaSearch(searched, { ...searched, radiusKm: 12 }), false);
  assert.equal(shouldOfferAreaSearch(null, searched), false);
});

test('markers that would overlap become one cluster; distant ones do not', () => {
  const project = (item) => ({ x: item.longitude * 1000, y: item.latitude * 1000 });
  const clusters = clusterNodes(
    [
      node({ key: 'a', latitude: 40.7130, longitude: -74.0050 }),
      node({ key: 'b', latitude: 40.7131, longitude: -74.0051 }),
      node({ key: 'c', latitude: 40.9, longitude: -73.8 }),
      node({ key: 'online', latitude: null, longitude: null }),
    ],
    project,
    56,
  );
  const sizes = clusters.map((cluster) => cluster.members.length).sort();
  assert.deepEqual(sizes, [1, 2]);
  const pair = clusters.find((cluster) => cluster.members.length === 2);
  assert.equal(pair.id, 'a|b');
  assert.ok(pair.bounds.north >= pair.bounds.south);
});

test('distances, prices, and labels read naturally', () => {
  assert.equal(formatDistance(0.05), 'Here');
  assert.equal(formatDistance(0.456), '460 m');
  assert.equal(formatDistance(3.24), '3.2 km');
  assert.equal(formatDistance(18.6), '19 km');
  assert.equal(formatDistance(null), null);
  assert.equal(formatPrice({ is_free: true }), 'Free');
  assert.equal(formatPrice({ is_free: false, price_amount: 15, currency: 'USD' }), '$15');
  assert.equal(formatPrice({ is_free: null }), null);
  assert.equal(categoryLabel({ category: 'educational_center', place_type: 'university' }), 'University');
  assert.equal(categoryLabel({ category: 'library' }), 'Library');
  assert.ok(Math.abs(distanceKm({ latitude: 0, longitude: 0 }, { latitude: 0, longitude: 1 }) - 111.2) < 0.2);
});

test('event times show in the viewer timezone', () => {
  const text = formatWhen('2026-09-27T22:00:00Z', '2026-09-28T00:00:00Z', 'en-US', 'America/New_York');
  assert.equal(text, 'Sun, Sep 27 · 6:00 PM – 8:00 PM');
  assert.equal(formatWhen(null), null);
  assert.equal(formatWhen('not a date'), null);
});

test('links are only ever plain web URLs', () => {
  assert.equal(safeWebUrl('javascript:alert(1)'), null);
  assert.equal(safeWebUrl('data:text/html,hi'), null);
  assert.equal(safeWebUrl('https://lyoai.app/x'), 'https://lyoai.app/x');
});

test('directions use the public place, never the viewer', () => {
  assert.equal(
    directionsUrl(node()),
    'https://www.google.com/maps/dir/?api=1&destination=40.713,-74.005',
  );
  assert.equal(
    directionsUrl(node({ latitude: null, longitude: null, address: '455 5th Ave' })),
    'https://www.google.com/maps/dir/?api=1&destination=455%205th%20Ave',
  );
  assert.equal(directionsUrl(node({ latitude: null, longitude: null, attendance_mode: 'online' })), null);
});

test('detail routes are stable and shareable', () => {
  assert.equal(detailPath({ kind: 'event', id: '42' }), '/community/events/42');
  assert.equal(detailPath({ kind: 'institution', id: 'osm:node:7' }), '/community/places/institution/osm%3Anode%3A7');
});

test('calendar export escapes text and uses UTC instants', () => {
  const ics = buildIcs(node({ description: 'Bring a pencil; and snacks\nsee you', address: '455 5th Ave, NY' }), 'https://lyoai.app/community/events/1');
  assert.match(ics, /DTSTART:20260927T220000Z/);
  assert.match(ics, /DTEND:20260928T000000Z/);
  assert.match(ics, /SUMMARY:SAT Prep\\, Session 1/);
  assert.match(ics, /DESCRIPTION:Bring a pencil\\; and snacks\\nsee you/);
  assert.match(ics, /LOCATION:455 5th Ave\\, NY/);
  assert.equal(buildIcs(node({ starts_at: null })), null);
  assert.match(googleCalendarUrl(node()), /dates=20260927T220000Z%2F20260928T000000Z/);
});

test('errors become learner-facing copy', () => {
  assert.equal(friendlyError({ status: 500, message: 'HTTP 500' }).title, "We couldn't load nearby learning opportunities.");
  assert.equal(friendlyError({ status: 500 }).retry, true);
  assert.equal(friendlyError(new TypeError('Failed to fetch')).title, "You're offline");
  assert.equal(friendlyError({ status: 409, message: 'This event is full' }).body, 'This event is full');
  assert.equal(friendlyError({ status: 404 }).retry, false);
  assert.ok(!friendlyError({ status: 500, message: 'Internal Server Error' }).body.includes('500'));
  // The backend's rate-limit envelope says "HTTP error occurred": never show that.
  assert.equal(friendlyError({ status: 429, message: 'HTTP error occurred' }).body, "You're going a little fast. Please wait a moment and try again.");
  assert.equal(friendlyError({ status: 429, message: "You've reached today's event limit." }).body, "You've reached today's event limit.");
  assert.equal(friendlyError({ status: 422, message: 'Request validation failed' }).body, 'Please check the details and try again.');
});

test('invite codes are read from a pasted link or a bare code, and nothing else', async () => {
  const { inviteTokenFromText, invitePath } = await import('./community-contract.mjs');
  const token = 'Zx9_aB-3cD4eF5gH6iJ7kL8mN';
  assert.equal(inviteTokenFromText(`https://lyoai.app/community/invite/${token}`), token);
  assert.equal(inviteTokenFromText(`  https://lyoai.app/community/invite/${token}?utm=x  `), token);
  assert.equal(inviteTokenFromText(token), token);
  assert.equal(inviteTokenFromText('https://lyoai.app/community/events/42'), null);
  assert.equal(inviteTokenFromText('short'), null);
  assert.equal(inviteTokenFromText(''), null);
  assert.equal(invitePath(token), `/community/invite/${token}`);
});

test('invite links say how they are used and why they stopped working', async () => {
  const { describeInviteLink } = await import('./community-contract.mjs');
  const now = new Date('2026-09-25T12:00:00Z');
  assert.equal(
    describeInviteLink({ active: true, use_count: 2, max_uses: 5, expires_at: '2026-09-30T12:00:00Z' }, now, 'en-US', 'UTC'),
    'Used 2 of 5 · Expires Sep 30',
  );
  assert.equal(describeInviteLink({ active: true, use_count: 1, max_uses: null, expires_at: null }, now), 'Used 1 time');
  assert.equal(describeInviteLink({ active: false, use_count: 1, max_uses: 1 }, now), 'Used 1 of 1 · Used up');
  assert.equal(describeInviteLink({ active: false, use_count: 0, expires_at: '2026-09-01T00:00:00Z' }, now), 'Used 0 times · Expired');
  assert.equal(describeInviteLink({ active: false, use_count: 3 }, now), 'Used 3 times · Turned off');
});
