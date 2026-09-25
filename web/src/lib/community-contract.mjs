// Pure Community map logic shared by the web screens and their tests.
// No React, no DOM: everything here is a function of its inputs, so the
// behaviours the product depends on (filters, "Search this area", clustering,
// directions, calendar export, error copy) are testable with `node --test`.

export const DEFAULT_CENTER = Object.freeze({ latitude: 40.7128, longitude: -74.006, label: 'New York City' });
export const DEFAULT_RADIUS_KM = 12;
export const NEARBY_RADIUS_KM = 3;
export const MAX_SEARCH_RADIUS_KM = 50;

/** Every map category, in the order the filter row shows them. */
export const NODE_CATEGORIES = [
  'event',
  'workshop',
  'class',
  'study_group',
  'tutor',
  'library',
  'museum',
  'educational_center',
];

export const SCHOOL_PLACE_TYPES = ['university', 'college'];
export const LEARNING_CENTER_PLACE_TYPES = [
  'language_school',
  'music_school',
  'prep_school',
  'training',
  'community_centre',
];

/**
 * The filter chips. `categories` / `placeTypes` narrow *what* appears; the
 * modifiers (`free`, `when`, `nearby`) narrow *which* of those appear, so any
 * combination is meaningful: "Workshops + Free + This week".
 */
export const FILTERS = [
  { id: 'events', label: 'Events', categories: ['event'] },
  { id: 'libraries', label: 'Libraries', categories: ['library'] },
  { id: 'museums', label: 'Museums', categories: ['museum'] },
  { id: 'classes', label: 'Classes', categories: ['class'] },
  { id: 'workshops', label: 'Workshops', categories: ['workshop'] },
  { id: 'study_groups', label: 'Study groups', categories: ['study_group'] },
  { id: 'schools', label: 'Schools & universities', categories: ['educational_center'], placeTypes: SCHOOL_PLACE_TYPES },
  { id: 'learning_centers', label: 'Learning centers', categories: ['educational_center'], placeTypes: LEARNING_CENTER_PLACE_TYPES },
  { id: 'tutors', label: 'Tutors', categories: ['tutor'] },
  { id: 'free', label: 'Free', modifier: 'free' },
  { id: 'today', label: 'Today', modifier: 'when', value: 'today' },
  { id: 'week', label: 'This week', modifier: 'when', value: 'week' },
  { id: 'nearby', label: 'Nearby', modifier: 'nearby' },
];

const FILTER_BY_ID = new Map(FILTERS.map((filter) => [filter.id, filter]));

/** Toggle a chip. "Today" and "This week" are mutually exclusive. */
export function toggleFilter(active, id) {
  const next = new Set(active);
  if (next.has(id)) {
    next.delete(id);
    return next;
  }
  const filter = FILTER_BY_ID.get(id);
  if (!filter) return next;
  if (filter.modifier === 'when') {
    for (const other of FILTERS) if (other.modifier === 'when') next.delete(other.id);
  }
  next.add(id);
  return next;
}

/** Translate the active chips into `/community/nearby` parameters. */
export function filtersToQuery(active) {
  const categories = new Set();
  const placeTypes = new Set();
  let broadPlaces = false;
  let free = false;
  let when = null;
  let nearby = false;
  for (const id of active) {
    const filter = FILTER_BY_ID.get(id);
    if (!filter) continue;
    if (filter.categories) {
      for (const category of filter.categories) categories.add(category);
      if (filter.placeTypes) for (const type of filter.placeTypes) placeTypes.add(type);
      else if (filter.categories.includes('educational_center')) broadPlaces = true;
    }
    if (filter.modifier === 'free') free = true;
    if (filter.modifier === 'when') when = filter.value;
    if (filter.modifier === 'nearby') nearby = true;
  }
  return {
    categories: [...categories].sort(),
    placeTypes: broadPlaces ? [] : [...placeTypes].sort(),
    freeOnly: free,
    when,
    nearby,
  };
}

export function activeFilterLabels(active) {
  return FILTERS.filter((filter) => active.has(filter.id)).map((filter) => filter.label);
}

// ---------------------------------------------------------------------------
// Geography
// ---------------------------------------------------------------------------

const EARTH_RADIUS_KM = 6371.0088;
const toRadians = (degrees) => (degrees * Math.PI) / 180;

export function distanceKm(a, b) {
  const dLat = toRadians(b.latitude - a.latitude);
  const dLng = toRadians(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(a.latitude)) * Math.cos(toRadians(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Search area covering a visible map viewport: its center and half-diagonal. */
export function areaForBounds({ north, south, east, west }) {
  const center = { latitude: (north + south) / 2, longitude: (east + west) / 2 };
  const corner = { latitude: north, longitude: east };
  const radiusKm = Math.min(MAX_SEARCH_RADIUS_KM, Math.max(0.5, distanceKm(center, corner)));
  return { ...center, radiusKm: Math.round(radiusKm * 10) / 10 };
}

/**
 * Whether the visible map differs enough from the searched area to offer
 * "Search this area". Small pans and zooms never trigger a request.
 */
export function shouldOfferAreaSearch(searched, visible) {
  if (!searched || !visible) return false;
  const moved = distanceKm(searched, visible);
  const larger = Math.max(searched.radiusKm, visible.radiusKm);
  const smaller = Math.max(0.1, Math.min(searched.radiusKm, visible.radiusKm));
  return moved > searched.radiusKm * 0.35 || larger / smaller > 1.8;
}

// ---------------------------------------------------------------------------
// Clustering
// ---------------------------------------------------------------------------

/**
 * Group markers that would overlap on screen. `project` maps a node to pixel
 * coordinates at the current zoom (Leaflet's `map.project`), so the same
 * function works for any zoom level. Nodes without coordinates are skipped.
 */
export function clusterNodes(nodes, project, cellPx = 56) {
  const cells = new Map();
  for (const node of nodes) {
    if (!Number.isFinite(node.latitude) || !Number.isFinite(node.longitude)) continue;
    const point = project(node);
    const key = `${Math.floor(point.x / cellPx)}:${Math.floor(point.y / cellPx)}`;
    const cell = cells.get(key);
    if (cell) cell.push(node);
    else cells.set(key, [node]);
  }
  return [...cells.values()].map((members) => {
    const latitude = members.reduce((sum, node) => sum + node.latitude, 0) / members.length;
    const longitude = members.reduce((sum, node) => sum + node.longitude, 0) / members.length;
    return {
      id: members.map((node) => node.key).sort().join('|'),
      latitude,
      longitude,
      members,
      bounds: {
        north: Math.max(...members.map((node) => node.latitude)),
        south: Math.min(...members.map((node) => node.latitude)),
        east: Math.max(...members.map((node) => node.longitude)),
        west: Math.min(...members.map((node) => node.longitude)),
      },
    };
  });
}

// ---------------------------------------------------------------------------
// Presentation
// ---------------------------------------------------------------------------

export const CATEGORY_LABELS = {
  event: 'Event',
  workshop: 'Workshop',
  class: 'Class',
  study_group: 'Study group',
  tutor: 'Tutor',
  library: 'Library',
  museum: 'Museum',
  educational_center: 'Learning center',
};

const PLACE_TYPE_LABELS = {
  university: 'University',
  college: 'College',
  language_school: 'Language school',
  music_school: 'Music school',
  prep_school: 'Tutoring center',
  training: 'Training center',
  community_centre: 'Community learning center',
  planetarium: 'Planetarium',
  museum: 'Museum',
  library: 'Library',
  tutoring: 'Tutoring',
};

export function categoryLabel(node) {
  if (node.place_type && PLACE_TYPE_LABELS[node.place_type]) return PLACE_TYPE_LABELS[node.place_type];
  return CATEGORY_LABELS[node.category] ?? 'Learning';
}

export function formatDistance(km) {
  if (km == null || !Number.isFinite(km)) return null;
  if (km < 0.1) return 'Here';
  if (km < 1) return `${Math.round(km * 1000 / 10) * 10} m`;
  return `${km < 10 ? km.toFixed(1) : Math.round(km)} km`;
}

export function formatPrice(node) {
  if (node.is_free === true) return 'Free';
  if (node.price_amount != null) {
    const currency = node.currency || 'USD';
    try {
      const whole = Number.isInteger(node.price_amount);
      return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency,
        minimumFractionDigits: whole ? 0 : 2,
        maximumFractionDigits: 2,
      }).format(node.price_amount);
    } catch {
      return `${currency} ${node.price_amount}`;
    }
  }
  if (node.is_free === false) return 'Paid';
  return null;
}

export const LIFECYCLE_LABELS = {
  upcoming: 'Upcoming',
  today: 'Today',
  live: 'Happening now',
  past: 'Ended',
  cancelled: 'Cancelled',
};

/** "Sat, Sep 27 · 6:00 – 8:00 PM" in the viewer's own timezone. */
export function formatWhen(startsAt, endsAt, locale = undefined, timeZone = undefined) {
  if (!startsAt) return null;
  const start = new Date(startsAt);
  if (Number.isNaN(start.getTime())) return null;
  const day = new Intl.DateTimeFormat(locale, { weekday: 'short', month: 'short', day: 'numeric', timeZone }).format(start);
  const time = new Intl.DateTimeFormat(locale, { hour: 'numeric', minute: '2-digit', timeZone });
  if (!endsAt) return `${day} · ${time.format(start)}`;
  const end = new Date(endsAt);
  if (Number.isNaN(end.getTime())) return `${day} · ${time.format(start)}`;
  const sameDay = new Intl.DateTimeFormat('en-CA', { timeZone }).format(start) === new Intl.DateTimeFormat('en-CA', { timeZone }).format(end);
  if (sameDay) return `${day} · ${time.format(start)} – ${time.format(end)}`;
  const endDay = new Intl.DateTimeFormat(locale, { month: 'short', day: 'numeric', timeZone }).format(end);
  return `${day} · ${time.format(start)} – ${endDay}, ${time.format(end)}`;
}

/** A plain http(s) URL, or null for anything else (javascript:, data:, …). */
export function safeWebUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.toString() : null;
  } catch {
    return null;
  }
}

/** Directions to a node's public location; never includes the viewer's position. */
export function directionsUrl(node) {
  if (Number.isFinite(node.latitude) && Number.isFinite(node.longitude)) {
    return `https://www.google.com/maps/dir/?api=1&destination=${node.latitude},${node.longitude}`;
  }
  const place = node.address || node.location_name;
  if (!place || node.attendance_mode === 'online') return null;
  return `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(place)}`;
}

export function detailPath(node) {
  if (node.kind === 'event') return `/community/events/${encodeURIComponent(node.id)}`;
  return `/community/places/${node.kind}/${encodeURIComponent(node.id)}`;
}

function icsText(value) {
  return String(value ?? '')
    .replace(/\\/g, '\\\\')
    .replace(/\r?\n/g, '\\n')
    .replace(/([,;])/g, '\\$1');
}

function icsStamp(value) {
  return new Date(value).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

/** An RFC 5545 calendar file for an event node, or null if it has no time. */
export function buildIcs(node, pageUrl) {
  if (!node.starts_at) return null;
  const end = node.ends_at || new Date(new Date(node.starts_at).getTime() + 60 * 60 * 1000).toISOString();
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Lyo//Community//EN',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    `UID:lyo-${node.kind}-${node.id}@lyoai.app`,
    `DTSTAMP:${icsStamp(new Date().toISOString())}`,
    `DTSTART:${icsStamp(node.starts_at)}`,
    `DTEND:${icsStamp(end)}`,
    `SUMMARY:${icsText(node.title)}`,
  ];
  if (node.description) lines.push(`DESCRIPTION:${icsText(node.description)}`);
  const place = [node.venue_name, node.address || node.location_name].filter(Boolean).join(', ');
  if (place) lines.push(`LOCATION:${icsText(place)}`);
  if (pageUrl) lines.push(`URL:${pageUrl}`);
  lines.push('END:VEVENT', 'END:VCALENDAR');
  return lines.join('\r\n');
}

export function googleCalendarUrl(node) {
  if (!node.starts_at) return null;
  const end = node.ends_at || new Date(new Date(node.starts_at).getTime() + 60 * 60 * 1000).toISOString();
  const params = new URLSearchParams({
    action: 'TEMPLATE',
    text: node.title,
    dates: `${icsStamp(node.starts_at)}/${icsStamp(end)}`,
  });
  if (node.description) params.set('details', node.description.slice(0, 1500));
  const place = node.address || node.location_name;
  if (place) params.set('location', place);
  return `https://calendar.google.com/calendar/render?${params}`;
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/**
 * Learner-facing copy for a failed Community request. Technical details are
 * logged by the caller, never shown as the primary message.
 */
export function friendlyError(error, action = 'load nearby learning opportunities') {
  const status = typeof error?.status === 'number' ? error.status : null;
  const message = typeof error?.message === 'string' ? error.message : '';
  const offline =
    status == null &&
    (/failed to fetch|networkerror|load failed|network request failed/i.test(message) ||
      (typeof navigator !== 'undefined' && navigator.onLine === false));
  if (offline) return { title: "You're offline", body: 'Check your connection and try again.', retry: true };
  if (status === 401) return { title: 'Please sign in again', body: 'Your session ended.', retry: false };
  if (status === 404) return { title: 'This is no longer available', body: 'It may have been removed or made private.', retry: false };
  const generic = !message || /^HTTP\b/i.test(message) || /^Request validation failed$/i.test(message);
  if (status === 429) {
    return {
      title: "That didn't work",
      body: generic ? "You're going a little fast. Please wait a moment and try again." : message,
      retry: true,
    };
  }
  if (status === 409 || status === 400 || status === 422) {
    return { title: "That didn't work", body: generic ? 'Please check the details and try again.' : message, retry: false };
  }
  return { title: `We couldn't ${action}.`, body: 'Please try again in a moment.', retry: true };
}
