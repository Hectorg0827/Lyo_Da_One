/**
 * Test Prep — the desktop workspace's view logic.
 *
 * The page it serves went from a 640px column of collapsed accordions to a
 * full-width two-column workspace: a KPI strip, a week timeline, and a
 * materials library with filters. Every one of those is a small pile of date
 * and counting arithmetic, and all of it used to be the kind of thing that
 * gets written inline in JSX and quietly goes wrong.
 *
 * So it lives here, pure and tested, for the same reason `test-prep.mjs` and
 * `test-prep-state.mjs` do.
 *
 * Two rules this module exists to hold:
 *
 * 1. A timezone is not an offset. Sessions arrive as UTC instants and are
 *    shown in the learner's study timezone, so "which day is this on" and
 *    "how far down the grid does it sit" are answered with `Intl`, and the
 *    week's seven dates are plain calendar arithmetic that never touches an
 *    offset at all. Stepping a Date by 86400000ms gets both of those wrong
 *    twice a year.
 *
 * 2. Nothing here renders a number nobody measured. `readinessKpi` returns
 *    'Not measured' where the rest of this codebase would be tempted to
 *    return '0%'. That rule, and the 0-1 scale of `readiness.readiness`, are
 *    `readinessHeadline`'s to own — this module calls it rather than
 *    reimplementing it, because the first draft of `readinessKpi` did
 *    reimplement it, read the fraction as a percentage, and turned a learner
 *    at 80% into "1%".
 */
import { readinessHeadline } from './test-prep.mjs';

/**
 * A session's instant.
 *
 * The API sends naive UTC for scheduled times. Appending the Z is what makes
 * a 6pm session 6pm and not whatever 6pm UTC happens to be locally.
 */
export function sessionDate(value) {
  return new Date(/(?:Z|[+-]\d{2}:\d{2})$/.test(value) ? value : `${value}Z`);
}

/**
 * Where an instant falls on the wall clock of `timeZone`.
 *
 * `hour12: false` reports midnight as 24 in some engines, hence the modulo —
 * without it a 00:15 session sorts to the bottom of the grid instead of the
 * top.
 */
function zonedParts(date, timeZone) {
  const parts = {};
  try {
    for (const part of new Intl.DateTimeFormat('en-US', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      weekday: 'short',
      hour12: false,
    }).formatToParts(date)) {
      parts[part.type] = part.value;
    }
  } catch {
    // An unknown timezone must not blank the schedule.
    return zonedParts(date, 'UTC');
  }
  const hour = Number(parts.hour) % 24;
  return {
    key: `${parts.year}-${parts.month}-${parts.day}`,
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    weekday: parts.weekday,
    minutes: hour * 60 + Number(parts.minute),
  };
}

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/** The seven calendar dates of the Monday-start week containing `anchor`. */
function weekDates(anchor) {
  const index = WEEKDAYS.indexOf(anchor.weekday);
  // Monday is 0 here; an unrecognised weekday falls back to starting today,
  // which is wrong-looking but never empty.
  const back = index < 0 ? 0 : (index + 6) % 7;
  const cursor = new Date(Date.UTC(anchor.year, anchor.month - 1, anchor.day));
  cursor.setUTCDate(cursor.getUTCDate() - back);

  const dates = [];
  for (let i = 0; i < 7; i++) {
    dates.push({
      key: cursor.toISOString().slice(0, 10),
      weekday: WEEKDAYS[cursor.getUTCDay()],
      dayOfMonth: cursor.getUTCDate(),
    });
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return dates;
}

function minutesOf(session) {
  const raw = Number(session?.duration_minutes);
  return Number.isFinite(raw) && raw > 0 ? raw : 25;
}

const DONE = new Set(['completed', 'done']);

/** The default window, when the week has nothing on it to size one from. */
const DEFAULT_START_HOUR = 16;
const DEFAULT_END_HOUR = 21;

/**
 * The week as a timeline: seven day columns, one row per hour, each session a
 * positioned block.
 *
 * `startMinutes` is measured from the top of the window rather than from
 * midnight, so a caller renders a block with `top: startMinutes * pxPerMinute`
 * and needs to know nothing about what hour the grid begins at.
 */
export function weekTimeline(sessions, options) {
  const timeZone = options?.timezone || 'UTC';
  const now = options?.now instanceof Date ? options.now : new Date();
  const todayKey = zonedParts(now, timeZone).key;
  const dates = weekDates(zonedParts(now, timeZone));

  const days = dates.map((date) => ({
    ...date,
    isToday: date.key === todayKey,
    totalMinutes: 0,
    status: 'rest',
    blocks: [],
  }));
  const byKey = new Map(days.map((day) => [day.key, day]));

  let earliest = null;
  let latest = null;

  for (const session of Array.isArray(sessions) ? sessions : []) {
    if (!session?.scheduled_at) continue;
    const at = sessionDate(session.scheduled_at);
    if (Number.isNaN(at.getTime())) continue;
    const zoned = zonedParts(at, timeZone);
    const day = byKey.get(zoned.key);
    if (!day) continue;

    const duration = minutesOf(session);
    const done = DONE.has(String(session.status ?? '').toLowerCase());
    day.blocks.push({
      id: session.id,
      topic: session.topic ?? '',
      sessionType: session.session_type ?? '',
      status: session.status ?? '',
      done,
      startOfDayMinutes: zoned.minutes,
      durationMinutes: duration,
    });
    day.totalMinutes += duration;

    earliest = earliest === null ? zoned.minutes : Math.min(earliest, zoned.minutes);
    latest = latest === null ? zoned.minutes + duration : Math.max(latest, zoned.minutes + duration);
  }

  const startHour = earliest === null ? DEFAULT_START_HOUR : Math.floor(earliest / 60);
  let endHour = latest === null ? DEFAULT_END_HOUR : Math.ceil(latest / 60);
  // A one-session week would otherwise draw a grid half a row tall.
  if (endHour - startHour < 4) endHour = startHour + 4;
  if (endHour > 24) endHour = 24;

  const windowStart = startHour * 60;
  for (const day of days) {
    day.blocks.sort((a, b) => a.startOfDayMinutes - b.startOfDayMinutes);
    for (const block of day.blocks) {
      block.startMinutes = block.startOfDayMinutes - windowStart;
    }
    day.status = day.blocks.length === 0
      ? 'rest'
      : day.blocks.every((block) => block.done)
        ? 'done'
        : 'scheduled';
  }

  const hours = [];
  for (let hour = startHour; hour < endHour; hour++) hours.push(hour);

  return { days, hours, startHour, endHour, totalMinutes: endHour * 60 - windowStart };
}

/** `16` → `"4 PM"`. The grid gutter is narrow; "16:00" does not fit it. */
export function hourLabel(hour) {
  const h = ((Number(hour) % 24) + 24) % 24;
  if (h === 0) return '12 AM';
  if (h === 12) return '12 PM';
  return h < 12 ? `${h} AM` : `${h - 12} PM`;
}

// ─── Study materials ─────────────────────────────────────────────────────────

/**
 * Which pile a material belongs in.
 *
 * `modality` is what the server stores and only distinguishes IMAGE from
 * DOCUMENT, so the mime type decides between a PDF and a note — a learner who
 * uploaded one of each should not see both filed under "Documents".
 */
export function materialKind(material) {
  const mime = String(material?.mime_type ?? '').toLowerCase();
  const name = String(material?.name ?? '').toLowerCase();
  if (mime.startsWith('image/')) return 'image';
  if (String(material?.modality ?? '').toUpperCase() === 'IMAGE') return 'image';
  if (mime === 'application/pdf' || name.endsWith('.pdf')) return 'pdf';
  return 'note';
}

const FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'pdf', label: 'PDFs' },
  { key: 'image', label: 'Images' },
  { key: 'note', label: 'Notes' },
];

/** The filter rail, each entry carrying its own count. */
export function materialFilters(materials) {
  const list = Array.isArray(materials) ? materials : [];
  return FILTERS.map((filter) => ({
    ...filter,
    count: filter.key === 'all'
      ? list.length
      : list.filter((material) => materialKind(material) === filter.key).length,
  }));
}

export function filterMaterials(materials, key) {
  const list = Array.isArray(materials) ? materials : [];
  if (!key || key === 'all') return list;
  return list.filter((material) => materialKind(material) === key);
}

// ─── The KPI strip ───────────────────────────────────────────────────────────

function finite(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

/** Days between today and the test, when the server did not already say. */
function daysUntil(testDate, now) {
  if (!testDate) return null;
  const target = Date.parse(`${testDate}T00:00:00Z`);
  if (Number.isNaN(target)) return null;
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  return Math.round((target - today) / 86400000);
}

function testDateLabel(testDate) {
  if (!testDate) return 'No date set';
  const parsed = new Date(`${testDate}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) return 'No date set';
  return parsed.toLocaleDateString(undefined, {
    weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC',
  });
}

function daysLeftKpi(readiness, profile, now) {
  const remaining = finite(readiness?.days_remaining) ?? daysUntil(profile?.test_date, now);
  const detail = testDateLabel(profile?.test_date ?? readiness?.test_date);
  if (remaining === null) return { key: 'days', icon: 'calendar', label: 'Days left', value: '—', detail, tone: 'plain' };
  if (remaining < 0) return { key: 'days', icon: 'calendar', label: 'Days left', value: 'Passed', detail, tone: 'plain' };
  if (remaining === 0) return { key: 'days', icon: 'calendar', label: 'Days left', value: 'Today', detail, tone: 'urgent' };
  return {
    key: 'days',
    icon: 'calendar',
    label: 'Days left',
    value: String(remaining),
    detail,
    tone: remaining <= 3 ? 'urgent' : 'plain',
  };
}

/**
 * Readiness, or an honest refusal to state one.
 *
 * Three different things read as "zero" here and only one of them is a
 * measurement: nothing assessed yet, a plan with no topics on it, and a
 * readiness call that failed. None of them may render as "0%".
 */
function readinessKpi(coachReadiness, readiness) {
  if (coachReadiness) {
    const assessed = finite(coachReadiness.assessed_skills) ?? 0;
    const total = finite(coachReadiness.total_skills) ?? 0;
    const detail = total > 0 ? `${assessed} of ${total} skills assessed` : 'No skills on this goal yet';
    if (assessed <= 0 || total <= 0) {
      return { key: 'readiness', icon: 'target', label: 'Readiness', value: 'Not measured', detail, tone: 'muted' };
    }
    const level = coachReadiness.readiness_level;
    return {
      key: 'readiness',
      icon: 'target',
      label: 'Readiness',
      value: level === 'ready' ? 'Ready' : level === 'getting_there' ? 'Getting there' : 'Not ready yet',
      detail,
      tone: level === 'ready' || level === 'getting_there' ? 'good' : 'warn',
    };
  }

  if (!readiness) {
    return {
      key: 'readiness', icon: 'target', label: 'Readiness',
      value: 'Unavailable', detail: 'Could not read your evidence', tone: 'muted',
    };
  }

  const total = finite(readiness.topics_total) ?? 0;
  const assessed = finite(readiness.topics_assessed) ?? 0;
  const detail = total > 0 ? `${assessed} of ${total} topics assessed` : 'No topics on this plan yet';
  const standing = readinessHeadline(readiness);
  if (standing.kind !== 'measured') {
    return { key: 'readiness', icon: 'target', label: 'Readiness', value: 'Not measured', detail, tone: 'muted' };
  }
  return {
    key: 'readiness', icon: 'target', label: 'Readiness',
    value: `${standing.percent}%`, detail,
    tone: standing.percent >= 70 ? 'good' : standing.percent >= 40 ? 'plain' : 'warn',
  };
}

function streakKpi(streak) {
  const current = finite(streak?.current) ?? 0;
  const best = finite(streak?.best) ?? 0;
  if (current <= 0) {
    return {
      key: 'streak', icon: 'flame', label: 'Study streak',
      value: 'Day 1', detail: 'Starts when you finish today', tone: 'muted',
    };
  }
  return {
    key: 'streak', icon: 'flame', label: 'Study streak',
    value: `${current} ${current === 1 ? 'day' : 'days'}`,
    detail: best > current ? `Your best is ${best}` : 'Your best yet',
    tone: 'plain',
  };
}

function todayKpi(missionMinutes, missionCount, dueCount) {
  const minutes = finite(missionMinutes) ?? 0;
  const steps = finite(missionCount) ?? 0;
  const due = finite(dueCount) ?? 0;
  if (steps > 0) {
    return {
      key: 'today', icon: 'clock', label: 'Today',
      value: `${minutes} min`,
      detail: `${steps} ${steps === 1 ? 'step' : 'steps'} on your mission`,
      tone: 'plain',
    };
  }
  if (due > 0) {
    return {
      key: 'today', icon: 'clock', label: 'Today',
      value: `${due} ${due === 1 ? 'session' : 'sessions'}`, detail: 'Scheduled for today', tone: 'plain',
    };
  }
  return {
    key: 'today', icon: 'clock', label: 'Today',
    value: 'Clear', detail: 'Nothing scheduled for today', tone: 'muted',
  };
}

/** The four tiles of the workspace header, in order. */
export function buildKpis(input) {
  const now = input?.now instanceof Date ? input.now : new Date();
  return [
    daysLeftKpi(input?.readiness, input?.profile, now),
    readinessKpi(input?.coachReadiness, input?.readiness),
    streakKpi(input?.streak),
    todayKpi(input?.missionMinutes, input?.missionCount, input?.dueCount),
  ];
}

/**
 * What the coach's ring should draw.
 *
 * `readiness_index` is a 0–1 index, but a server that starts sending 0–100
 * would otherwise paint every learner at a hard 100%, so the scale is
 * detected rather than assumed. With nothing assessed there is no arc and no
 * figure at all — `kind: 'unmeasured'` — because a ring drawn at zero is the
 * same false claim as the text "0%".
 */
export function readinessRing(coachReadiness, readiness) {
  if (coachReadiness) {
    const assessed = finite(coachReadiness.assessed_skills) ?? 0;
    const total = finite(coachReadiness.total_skills) ?? 0;
    if (assessed <= 0 || total <= 0) return { kind: 'unmeasured', percent: null };
    const index = finite(coachReadiness.readiness_index);
    if (index === null) return { kind: 'unmeasured', percent: null };
    const percent = index <= 1 ? index * 100 : index;
    return { kind: 'measured', percent: Math.max(0, Math.min(100, Math.round(percent))) };
  }

  if (!readiness) return { kind: 'unknown', percent: null };
  // Same scale, same guards, one implementation.
  const standing = readinessHeadline(readiness);
  return standing.kind === 'measured'
    ? { kind: 'measured', percent: standing.percent }
    : { kind: standing.kind === 'unknown' ? 'unknown' : 'unmeasured', percent: null };
}

/**
 * The mission, with each step told whether it is already behind the learner.
 *
 * There is no endpoint for "tick off a mission step", so a checkbox the
 * learner could click would forget itself on the next load. Instead a step is
 * done when a session for the same concept is done — real, server-owned
 * evidence — and the control is a status marker, not a fake input.
 */
export function missionChecklist(mission, sessions) {
  const completed = new Set(
    (Array.isArray(sessions) ? sessions : [])
      .filter((session) => DONE.has(String(session?.status ?? '').toLowerCase()))
      .map((session) => session?.concept_id)
      .filter(Boolean),
  );
  return (Array.isArray(mission) ? mission : []).map((item) => ({
    ...item,
    done: Boolean(item?.concept_id) && completed.has(item.concept_id),
  }));
}

/** How far through the plan the learner is, for the schedule card's footer. */
export function planProgress(sessions) {
  const list = Array.isArray(sessions) ? sessions : [];
  const done = list.filter((session) => DONE.has(String(session?.status ?? '').toLowerCase())).length;
  return { done, total: list.length };
}
