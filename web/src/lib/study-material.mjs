/**
 * Study material the learner asked for, lifted out of a prose reply.
 *
 * Chat can only show a flashcard deck, a study plan or a set of notes when the
 * turn carries a structured block for it. The model usually answers "make me
 * flashcards on X" with ordinary Markdown instead — a list of term/definition
 * lines — so the learner got a paragraph and the deck never appeared at all.
 *
 * This module reads a finished reply and builds the blocks that reply is
 * describing. The geometry and the rules live here, apart from the components,
 * so they can be tested directly.
 *
 * Deliberately conservative, because a false positive is expensive: the prose
 * bubble is replaced once blocks are present. So it acts only on an explicit
 * study-material ask (or a reply that labels itself a deck), reads only
 * list-shaped lines — never free prose, which would turn any sentence with a
 * colon into a card — and needs at least MIN_CARDS cards before it restructures
 * anything.
 */

/** What the learner asked for. */
export const STUDY_ASKS = Object.freeze(['flashcards', 'studyPlan', 'notes', 'unrelated']);

/**
 * How many cards the learner is given at a time.
 *
 * A deck arrives in batches rather than all at once: reaching the last card of
 * a batch asks for the next one, so the deck keeps pace with how far the
 * learner actually got instead of dumping forty cards on them up front.
 */
export const DECK_BATCH_SIZE = 3;

/** Hard stop, so a deck cannot grow without bound while someone keeps swiping. */
export const DECK_MAX_CARDS = 60;

/**
 * Fewest cards worth turning a prose answer into a deck.
 *
 * A line that literally says `Flashcard Front:` / `Back:` is unambiguous, so
 * one of those is already a deck — models routinely answer "make me a
 * flashcard" with exactly one. The looser one-line heuristic below infers the
 * pairs from list shape, so it needs several before it will believe them.
 */
export const MIN_LABELLED_CARDS = 1;
export const MIN_INLINE_CARDS = 3;
const MIN_PLAN_DAYS = 2;
const MIN_NOTE_SECTIONS = 2;

/**
 * Above this much leftover prose the reply is an explanation that happens to
 * contain a list, not a deck — so it is left exactly as the model wrote it.
 */
const MAX_LEFTOVER_PROSE = 600;

const LIST_MARKER = /^(?:[-*+•]|\d+[.)])\s+/;
// Longest first, so `flashcard front:` is not shadowed by a shorter prefix.
const FRONT_LABELS = [
  'flashcard front:', 'card front:', 'front:', 'term:', 'question:', 'word:', 'q:',
];
const BACK_LABELS = [
  'flashcard back:', 'card back:', 'back:', 'definition:', 'answer:', 'meaning:', 'a:',
];

const FLASHCARD_PHRASES = [
  'flashcard', 'flash card', 'flash-card', 'cue card', 'study deck', 'study cards',
  'key terms', 'term and definition', 'terms and definitions', 'glossary', 'quizlet',
];
const PLAN_PHRASES = [
  'study plan', 'study schedule', 'revision plan', 'revision schedule',
  'study timetable', 'plan to study', 'schedule to study',
];
const NOTES_PHRASES = [
  'study material', 'study materials', 'study guide', 'study notes', 'study sheet',
  'cheat sheet', 'revision notes', 'summary notes', 'notes on', 'notes for',
  'summarize for study',
];

// ─── Intent ──────────────────────────────────────────────────────────────────

/** Which kind of study material the ask is for. */
export function classifyStudyAsk(userAsk) {
  const text = String(userAsk || '').toLowerCase();
  if (FLASHCARD_PHRASES.some((phrase) => text.includes(phrase))) return 'flashcards';
  if (PLAN_PHRASES.some((phrase) => text.includes(phrase))) return 'studyPlan';
  if (NOTES_PHRASES.some((phrase) => text.includes(phrase))) return 'notes';
  return 'unrelated';
}

/** A reply that opens by calling itself a deck counts even when the ask was vague. */
function mentionsDeck(reply) {
  const head = String(reply || '').slice(0, 400).toLowerCase();
  return head.includes('flashcard') || head.includes('flash card');
}

// ─── Entry point ─────────────────────────────────────────────────────────────

/**
 * The blocks a reply is describing, or null to leave the reply alone.
 *
 * Returns a leading `text` block for whatever prose is left over, so the
 * model's framing survives alongside the cards rather than being replaced by
 * them.
 *
 * @param {string} reply the assistant's finished answer
 * @param {string} userAsk what the learner typed
 * @param {string} [idPrefix] prefix for the synthesized block ids
 */
export function extractStudyBlocks(reply, userAsk, idPrefix = 'study') {
  const text = String(reply || '');
  const ask = classifyStudyAsk(userAsk);
  const selfLabelled = mentionsDeck(text);
  if (ask === 'unrelated' && !selfLabelled) return null;

  const found =
    fromFencedJSON(text) ??
    ((ask === 'flashcards' || selfLabelled) ? deckFromMarkdown(text, userAsk) : null) ??
    (ask === 'studyPlan' ? planFromMarkdown(text) : null) ??
    (ask === 'notes' ? notesFromMarkdown(text) : null);

  if (!found) return null;

  const blocks = [];
  if (found.displayText) {
    blocks.push({
      id: `${idPrefix}-lead`,
      type: 'text',
      content: { text: found.displayText },
    });
  }
  blocks.push({ ...found.block, id: `${idPrefix}-${found.block.subtype}` });
  return { blocks, displayText: found.displayText };
}

// ─── Whether a turn still needs study material ───────────────────────────────

/**
 * Whether a block is study material the backend already supplied.
 *
 * Only these suppress the fallback. An ordinary text or lesson block must not:
 * a turn that happens to arrive as blocks is still a turn whose reply may be
 * describing a deck in prose, and treating "has any block at all" as "already
 * handled" is what left a learner looking at a paragraph.
 */
export function isStudyBlock(block) {
  if (!block || typeof block !== 'object') return false;
  if (block.type === 'flashcard' || block.type === 'quiz') return true;
  return (
    block.type === 'interactive' &&
    (block.subtype === 'studyPlan' || block.subtype === 'studyNotes')
  );
}

/** Whether the turn already carries study material of its own. */
export function hasStudyBlock(blocks) {
  return Array.isArray(blocks) && blocks.some(isStudyBlock);
}

// ─── Growing a deck ──────────────────────────────────────────────────────────

/**
 * What a deck should do when the learner lands on a card.
 *
 * The rule the component follows, kept here as a pure decision so it can be
 * tested without a browser: while the learner is mid-batch, nothing happens;
 * arriving at the last reachable card either shows cards already parsed from
 * the reply (free) or asks the model for the next batch (a request).
 *
 * The batch is fetched on *arrival* at the last card, not on leaving it, so
 * the next swipe is usually already paid for.
 *
 * @returns 'idle' | 'reveal' | 'fetch'
 */
export function nextDeckStep({
  index,
  revealed,
  total,
  loading = false,
  exhausted = false,
  max = DECK_MAX_CARDS,
}) {
  const visible = Math.min(revealed, total);
  if (visible <= 0) return 'idle';
  if (index < visible - 1) return 'idle';
  if (total > visible) return 'reveal';
  if (loading || exhausted || total >= max) return 'idle';
  return 'fetch';
}

/**
 * The request for the next batch.
 *
 * Names the cards already seen, newest last, so the model writes different
 * ones rather than rephrasing the deck the learner just worked through.
 */
export function moreCardsPrompt(topic, seenFronts = [], count = DECK_BATCH_SIZE) {
  const seen = (seenFronts || []).filter(Boolean).slice(-24);
  const lines = [
    `Write exactly ${count} more flashcards on: ${topic || 'this topic'}.`,
    'Reply with JSON only, no commentary, in exactly this shape:',
    '{"cards":[{"front":"...","back":"..."}]}',
    'Each front is a short question or term. Each back answers it in one or two sentences.',
  ];
  if (seen.length) {
    lines.push('', 'Do not repeat any of these, which the learner already has:');
    for (const front of seen) lines.push(`- ${front}`);
  }
  return lines.join('\n');
}

/**
 * Cards from a reply to `moreCardsPrompt`.
 *
 * "JSON only" is a request, not a guarantee, so a Markdown answer is read with
 * the same parsers as any other reply rather than being thrown away.
 */
export function parseMoreCards(reply) {
  const text = String(reply || '');

  for (const fenced of fencedJSONBlocks(text)) {
    let root;
    try {
      root = JSON.parse(fenced.json);
    } catch {
      continue;
    }
    if (!root || typeof root !== 'object') continue;
    const cards = decodeCards(payloadBody(root)) ?? decodeCards(root);
    if (cards && cards.length) return cards;
  }

  const lines = text.split(/\r?\n/);
  const paired = pairedCards(lines);
  if (paired.cards.length) return paired.cards;
  return inlineCards(lines).cards;
}

/**
 * `existing` plus the incoming cards it does not already hold, capped.
 *
 * Compared on a loosened front, because a model asked for new cards will
 * happily return the same question with different punctuation.
 */
export function mergeCards(existing, incoming, max = DECK_MAX_CARDS) {
  const merged = (existing || []).filter((card) => card && card.front && card.back);
  const seen = new Set(merged.map((card) => frontKey(card.front)));

  for (const card of incoming || []) {
    if (merged.length >= max) break;
    if (!card || !card.front || !card.back) continue;
    const key = frontKey(card.front);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    merged.push({ front: card.front, back: card.back });
  }
  return merged;
}

function frontKey(front) {
  return String(front || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

// ─── Fenced JSON payloads ────────────────────────────────────────────────────

function fromFencedJSON(reply) {
  for (const fenced of fencedJSONBlocks(reply)) {
    let root;
    try {
      root = JSON.parse(fenced.json);
    } catch {
      continue;
    }
    if (!root || typeof root !== 'object') continue;
    const body = payloadBody(root);

    const cards = decodeCards(body) ?? decodeCards(root);
    if (cards && cards.length >= 2) {
      return {
        displayText: stripping(fenced.raw, reply, ''),
        block: deckBlock(
          firstString(body, ['title', 'topic']) ??
            firstString(root, ['title', 'topic']) ??
            'Study deck',
          cards
        ),
      };
    }

    const plan = decodePlan(body) ?? decodePlan(root);
    if (plan) {
      return { displayText: stripping(fenced.raw, reply, ''), block: plan };
    }
  }
  return null;
}

function fencedJSONBlocks(source) {
  const blocks = [];
  const fence = /```(?:json)?\s*([\s\S]*?)```/gi;
  let match;
  while ((match = fence.exec(source)) !== null) {
    const json = balancedObject(match[1]);
    if (json) blocks.push({ raw: match[0], json });
  }
  // Some replies carry the payload with no fence around it at all.
  if (!blocks.length) {
    const json = balancedObject(source);
    if (json) blocks.push({ raw: json, json });
  }
  return blocks;
}

/**
 * The first brace-balanced JSON object in `text`.
 *
 * A regex cannot do this job: a lazy `\{[\s\S]*?\}` stops at the first inner
 * closing brace, so `{"cards":[{"front":…}]}` is captured as invalid JSON and
 * silently dropped, while a greedy one swallows everything after the payload.
 */
export function balancedObject(text) {
  const source = String(text || '');
  const start = source.indexOf('{');
  if (start === -1) return null;

  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < source.length; i++) {
    const char = source[i];
    if (escaped) {
      escaped = false;
    } else if (char === '\\') {
      escaped = true;
    } else if (char === '"') {
      inString = !inString;
    } else if (!inString) {
      if (char === '{') depth += 1;
      else if (char === '}') {
        depth -= 1;
        if (depth === 0) return source.slice(start, i + 1);
      }
    }
  }
  return null;
}

function payloadBody(root) {
  for (const key of ['payload', 'data', 'content', 'deck']) {
    const nested = root[key];
    if (nested && typeof nested === 'object' && !Array.isArray(nested)) return nested;
  }
  return root;
}

function decodeCards(body) {
  const rows =
    (Array.isArray(body?.cards) && body.cards) ||
    (Array.isArray(body?.flashcards) && body.flashcards) ||
    (Array.isArray(body?.items) && body.items) ||
    null;
  if (!rows) return null;

  const cards = [];
  for (const row of rows) {
    if (!row || typeof row !== 'object') continue;
    const front = firstString(row, ['front', 'term', 'question', 'prompt']);
    const back = firstString(row, ['back', 'definition', 'answer', 'response']);
    if (front && back) cards.push({ front, back });
  }
  return cards.length ? cards : null;
}

function decodePlan(body) {
  const rows =
    (Array.isArray(body?.schedule) && body.schedule) ||
    (Array.isArray(body?.days) && body.days) ||
    null;
  if (!rows || !rows.length) return null;

  const schedule = rows.map((row, index) => ({
    day: toInt(row?.day) ?? toInt(row?.day_number) ?? toInt(row?.dayNumber) ?? index + 1,
    topic: firstString(row ?? {}, ['topic', 'title', 'focus']) ?? `Day ${index + 1}`,
    tasks: (Array.isArray(row?.tasks) ? row.tasks : [])
      .map((task) => {
        const title = firstString(task ?? {}, ['title', 'name', 'task']);
        if (!title) return null;
        return {
          title,
          minutes:
            toInt(task?.duration_minutes) ?? toInt(task?.durationMinutes) ??
            toInt(task?.minutes) ?? minutesIn(title) ?? 20,
          kind: firstString(task ?? {}, ['type', 'activity_type', 'activityType']) ?? taskKind(title),
        };
      })
      .filter(Boolean),
  }));

  if (schedule.length < MIN_PLAN_DAYS) return null;
  return planBlock(firstString(body, ['title', 'name']) ?? 'Your study plan', schedule);
}

// ─── Flashcards from Markdown ────────────────────────────────────────────────

function deckFromMarkdown(reply, userAsk) {
  const lines = reply.split(/\r?\n/);

  let parsed = pairedCards(lines);
  if (parsed.cards.length < MIN_LABELLED_CARDS) parsed = inlineCards(lines);
  if (!parsed.cards.length) return null;
  if (!parsed.labelled && parsed.cards.length < MIN_INLINE_CARDS) return null;

  const leftovers = lines.filter((_, index) => !parsed.consumed.has(index));
  const remainder = prose(leftovers);
  if (remainder.length > MAX_LEFTOVER_PROSE) return null;

  return {
    displayText: remainder,
    block: deckBlock(deckTitle(userAsk, reply), parsed.cards),
  };
}

/**
 * `Flashcard Front: …` / `Back: …`, `Front:` / `Back:`, `Q:` / `A:`.
 *
 * The back is not always one line. Models commonly follow it with a bulleted
 * "Key points" list that plainly belongs to the card, so those continuation
 * lines are folded into the back rather than left behind as stray prose.
 */
function pairedCards(lines) {
  const cards = [];
  const consumed = new Set();
  let index = 0;

  while (index < lines.length) {
    const front = labelledValue(lines[index], FRONT_LABELS);
    if (!front) {
      index += 1;
      continue;
    }

    let next = index + 1;
    while (next < lines.length && listBody(lines[next]) === '') next += 1;
    const head = next < lines.length ? labelledValue(lines[next], BACK_LABELS) : null;
    if (!head) {
      index += 1;
      continue;
    }
    consumed.add(index);
    consumed.add(next);

    // Keep continuation lines verbatim so their bullets still render as a list.
    const back = [head];
    let cursor = next + 1;
    while (cursor < lines.length) {
      const raw = lines[cursor];
      if (!String(raw).trim()) {
        cursor += 1;
        continue;
      }
      if (labelledValue(raw, FRONT_LABELS)) break;
      if (!isContinuation(raw)) break;
      back.push(String(raw).replace(/\s+$/, ''));
      consumed.add(cursor);
      cursor += 1;
    }

    cards.push({ front, back: back.join('\n') });
    index = cursor;
  }
  return { cards, consumed, labelled: true };
}

/** A line that carries on the card above it rather than starting new prose. */
function isContinuation(rawLine) {
  const raw = String(rawLine || '');
  if (/^\s{2,}\S/.test(raw)) return true;
  return LIST_MARKER.test(raw.trim());
}

function labelledValue(rawLine, labels) {
  const line = listBody(rawLine);
  const lowered = line.toLowerCase();
  for (const label of labels) {
    if (lowered.startsWith(label)) return tidyValue(line.slice(label.length));
  }
  return null;
}

/**
 * Like `tidy`, but keeps trailing punctuation.
 *
 * A labelled value is already delimited by its label, so a trailing colon is
 * the author's ("It is given by:" leading into a list), not leftover markup.
 */
function tidyValue(text) {
  const stripped = String(text || '')
    .replace(/\*\*/g, '')
    .replace(/`/g, '')
    .replace(/^[\s*_—–\-:]+/, '')
    .replace(/\s+$/, '');
  return stripped || null;
}

/** One card per line: `- Term: definition`, `**Term** — definition`, table rows. */
function inlineCards(lines) {
  const cards = [];
  const consumed = new Set();
  const seen = new Set();

  lines.forEach((rawLine, index) => {
    const pair = inlinePair(rawLine);
    if (!pair) return;
    const key = pair.front.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    cards.push(pair);
    consumed.add(index);
  });
  return { cards, consumed, labelled: false };
}

/**
 * Only list items, bold-led lines and table rows become cards. Free prose is
 * skipped on purpose — otherwise "Note: this matters" would become a card.
 */
function inlinePair(rawLine) {
  const line = String(rawLine || '').trim();
  if (!line || line.startsWith('#')) return null;

  const row = tableRow(line);
  if (row) return row;

  if (!LIST_MARKER.test(line) && !line.startsWith('**')) return null;

  const body = listBody(line);
  const separator = separatorAt(body);
  if (!separator) return null;

  const front = tidy(body.slice(0, separator.start));
  const back = tidy(body.slice(separator.end));
  if (!front || !back) return null;
  if (front.length < 2 || front.length > 160 || back.length < 2) return null;
  return { front, back };
}

function tableRow(line) {
  if (!line.startsWith('|')) return null;
  const cells = line.split('|').filter((cell) => cell !== '').map((cell) => cell.trim());
  if (cells.length < 2) return null;

  // The `|---|---|` rule and the header row carry no card content.
  if (/^[-:\s]+$/.test(cells[0])) return null;
  if (['term', 'front', 'question', 'word', 'concept'].includes(cells[0].toLowerCase())) {
    return null;
  }
  const front = tidy(cells[0]);
  const back = tidy(cells[1]);
  if (!front || !back || front.length < 2 || back.length < 2) return null;
  return { front, back };
}

/** Earliest of the separators a model puts between a term and its definition. */
function separatorAt(body) {
  let earliest = null;
  for (const candidate of [' — ', ' – ', ' -- ', ': ', ' - ', '—', '–']) {
    const index = body.indexOf(candidate);
    if (index === -1) continue;
    if (earliest && earliest.start <= index) continue;
    earliest = { start: index, end: index + candidate.length };
  }
  return earliest;
}

function deckTitle(userAsk, reply) {
  const heading = firstHeading(reply);
  if (heading) return heading;
  const topic = topicPhrase(userAsk);
  return topic ? `Flashcards: ${topic}` : 'Study deck';
}

/** Pulls "photosynthesis" out of "make flashcards on photosynthesis". */
function topicPhrase(userAsk) {
  const lowered = String(userAsk || '').toLowerCase();
  for (const marker of [' on ', ' about ', ' for ', ' covering ', ' from ']) {
    const index = lowered.indexOf(marker);
    if (index === -1) continue;
    const tidied = tidy(lowered.slice(index + marker.length));
    if (tidied && tidied.length >= 3 && tidied.length <= 60) return tidied;
  }
  return null;
}

// ─── Study plan from Markdown ────────────────────────────────────────────────

function planFromMarkdown(reply) {
  const lines = reply.split(/\r?\n/);
  const schedule = [];
  const consumed = new Set();
  let open = null;

  const closeDay = () => {
    if (open) schedule.push(open);
    open = null;
  };

  lines.forEach((rawLine, index) => {
    const line = rawLine.trim();
    const heading = dayHeading(line);
    if (heading) {
      closeDay();
      open = { day: heading.day, topic: heading.topic, tasks: [] };
      consumed.add(index);
      return;
    }
    if (open) {
      const task = planTask(line);
      if (task) {
        open.tasks.push(task);
        consumed.add(index);
      }
    }
  });
  closeDay();

  if (schedule.length < MIN_PLAN_DAYS) return null;

  const leftovers = lines.filter((_, index) => !consumed.has(index));
  const remainder = prose(leftovers);
  if (remainder.length > MAX_LEFTOVER_PROSE) return null;

  return {
    displayText: remainder,
    block: planBlock(firstHeading(reply) ?? 'Your study plan', schedule),
  };
}

function dayHeading(line) {
  const body = listBody(line).replace(/#/g, '').trim();
  const lowered = body.toLowerCase();
  if (!lowered.startsWith('day ') && !lowered.startsWith('week ')) return null;

  const match = body.match(/(\d+)/);
  if (!match) return null;
  const day = Number(match[1]);
  const rest = body.slice(match.index + match[1].length);
  return { day, topic: tidy(rest) ?? `Study session ${day}` };
}

function planTask(line) {
  if (!LIST_MARKER.test(line)) return null;
  const title = tidy(listBody(line));
  if (!title) return null;
  return { title, minutes: minutesIn(title) ?? 20, kind: taskKind(title) };
}

function minutesIn(text) {
  const match = String(text || '').match(/(\d+)\s*(?:min|minute)/i);
  return match ? Number(match[1]) : null;
}

function taskKind(title) {
  const lowered = String(title || '').toLowerCase();
  if (lowered.includes('watch') || lowered.includes('video')) return 'watch';
  if (lowered.includes('quiz') || lowered.includes('practice') || lowered.includes('problem')) {
    return 'practice';
  }
  return 'read';
}

// ─── Notes from Markdown ─────────────────────────────────────────────────────

function notesFromMarkdown(reply) {
  const lines = reply.split(/\r?\n/);
  const sections = [];
  const lead = [];
  let openTitle = null;
  let openBody = [];

  const closeSection = () => {
    if (openTitle) {
      const body = openBody.join('\n').trim();
      if (body) sections.push({ title: openTitle, body });
    }
    openTitle = null;
    openBody = [];
  };

  for (const rawLine of lines) {
    const line = rawLine.trim();
    const heading = sectionHeading(line);
    if (heading) {
      closeSection();
      openTitle = heading;
      continue;
    }
    if (openTitle) {
      if (line) openBody.push(line);
    } else if (line && !line.startsWith('#')) {
      lead.push(line);
    }
  }
  closeSection();

  if (sections.length < MIN_NOTE_SECTIONS) return null;

  return {
    displayText: prose(lead),
    block: {
      type: 'interactive',
      subtype: 'studyNotes',
      content: { title: firstHeading(reply) ?? 'Study notes', sections },
    },
  };
}

function sectionHeading(line) {
  if (line.startsWith('##')) return tidy(line.replace(/^#+/, ''));
  // A whole line in bold reads as a heading; a bold run inside a sentence does not.
  if (line.startsWith('**') && line.endsWith('**') && line.length > 4 && !line.includes('. ')) {
    return tidy(line);
  }
  return null;
}

// ─── Block shapes ────────────────────────────────────────────────────────────

function deckBlock(title, cards) {
  return { type: 'flashcard', subtype: 'deck', content: { title, cards } };
}

function planBlock(title, schedule) {
  return { type: 'interactive', subtype: 'studyPlan', content: { title, schedule } };
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

/** A line with its list marker, Markdown emphasis and outer whitespace removed. */
function listBody(rawLine) {
  return String(rawLine || '')
    .trim()
    .replace(LIST_MARKER, '')
    .replace(/\*\*/g, '')
    .replace(/`/g, '')
    .trim();
}

function tidy(text) {
  const stripped = String(text || '')
    .replace(/\*\*/g, '')
    .replace(/`/g, '')
    .replace(/^[\s*_—–\-:]+/, '')
    .replace(/[\s*_—–\-:]+$/, '');
  return stripped || null;
}

function firstHeading(reply) {
  for (const rawLine of String(reply || '').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line.startsWith('#')) continue;
    const tidied = tidy(line.replace(/^#+/, ''));
    if (tidied && tidied.length >= 3 && tidied.length <= 80) return tidied;
  }
  return null;
}

/**
 * The reply text left over once the cards have been lifted out. A couple of
 * orphaned words is noise rather than prose, so it is dropped.
 */
function prose(lines) {
  const kept = lines
    .map((line) => String(line || '').trim())
    .filter((line) => line && !line.startsWith('|'));
  const text = kept.join('\n').trim();
  return text.length >= 12 ? text : '';
}

function stripping(fragment, source, fallback) {
  const stripped = String(source || '').split(fragment).join('').trim();
  return stripped || fallback;
}

function firstString(row, keys) {
  for (const key of keys) {
    const value = row?.[key];
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return null;
}

function toInt(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string' && value.trim() && Number.isFinite(Number(value))) {
    return Math.trunc(Number(value));
  }
  return null;
}
