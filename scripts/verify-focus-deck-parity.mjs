import { readFileSync } from 'node:fs';

// The collapsed course deck is drawn by three codebases from one table of
// numbers: how far each peek card sits below the top one, how much narrower
// it is, how faint, and how long each card waits before it slides into place.
//
// Each platform's unit suite pins its own copy, but nothing makes the three
// copies agree — and they are the same design decision, so a stack that
// opens on iOS and on Android should look like the same stack. This reads
// the numbers straight out of the three sources and fails when they drift.

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
}

const swift = read('Sources/Views/Main/Focus/FocusPresentation.swift');
const web = read('web/src/lib/focus-presentation.mjs');
const kotlin = read('android/app/src/main/java/com/lyo/app/ui/screens/home/FocusPresentation.kt');

function numbers(source, pattern, label) {
  const match = source.match(pattern);
  if (!match) throw new Error(`${label}: could not find the table`);
  return match[1]
    .split(',')
    .map((piece) => Number.parseFloat(piece.trim().replace(/f$/, '')));
}

function scalar(source, pattern, label) {
  const match = source.match(pattern);
  if (!match) throw new Error(`${label}: could not find the value`);
  return Number.parseInt(match[1], 10);
}

const tables = {
  offsets: {
    iOS: numbers(swift, /deckOffsets: \[Double\] = \[([^\]]+)\]/, 'iOS deck offsets'),
    web: numbers(web, /DECK_OFFSETS = Object\.freeze\(\[([^\]]+)\]\)/, 'web deck offsets'),
    Android: numbers(kotlin, /DECK_OFFSETS = listOf\(([^)]+)\)/, 'Android deck offsets'),
  },
  scales: {
    iOS: numbers(swift, /deckScales: \[Double\] = \[([^\]]+)\]/, 'iOS deck scales'),
    web: numbers(web, /DECK_SCALES = Object\.freeze\(\[([^\]]+)\]\)/, 'web deck scales'),
    Android: numbers(kotlin, /DECK_SCALES = listOf\(([^)]+)\)/, 'Android deck scales'),
  },
  opacities: {
    iOS: numbers(swift, /deckOpacities: \[Double\] = \[([^\]]+)\]/, 'iOS deck opacities'),
    web: numbers(web, /DECK_OPACITIES = Object\.freeze\(\[([^\]]+)\]\)/, 'web deck opacities'),
    Android: numbers(kotlin, /DECK_OPACITIES = listOf\(([^)]+)\)/, 'Android deck opacities'),
  },
};

for (const [name, byPlatform] of Object.entries(tables)) {
  const [reference, ...rest] = Object.entries(byPlatform);
  for (const [platform, values] of rest) {
    const same =
      values.length === reference[1].length &&
      values.every((value, index) => Math.abs(value - reference[1][index]) < 1e-6);
    if (!same) {
      throw new Error(
        `Focus deck ${name} drifted: ${reference[0]} has [${reference[1]}], ` +
          `${platform} has [${values}]`,
      );
    }
  }
  if (byPlatform.iOS.length !== 2) {
    throw new Error(`Focus deck ${name}: expected one value per peek card, got ${byPlatform.iOS.length}`);
  }
}

const scalars = {
  'peek limit': {
    iOS: scalar(swift, /deckPeekLimit = (\d+)/, 'iOS deck peek limit'),
    web: scalar(web, /DECK_PEEK_LIMIT = (\d+)/, 'web deck peek limit'),
    Android: scalar(kotlin, /DECK_PEEK_LIMIT = (\d+)/, 'Android deck peek limit'),
  },
  'stagger step': {
    iOS: scalar(swift, /deckStaggerStep = (\d+)/, 'iOS deck stagger step'),
    web: scalar(web, /DECK_STAGGER_STEP = (\d+)/, 'web deck stagger step'),
    Android: scalar(kotlin, /DECK_STAGGER_STEP = (\d+)/, 'Android deck stagger step'),
  },
  'next-card peek': {
    iOS: scalar(swift, /deckNextCardPeek: Double = (\d+)/, 'iOS deck next-card peek'),
    web: scalar(web, /DECK_NEXT_CARD_PEEK = (\d+)/, 'web deck next-card peek'),
    Android: scalar(kotlin, /DECK_NEXT_CARD_PEEK = (\d+)f/, 'Android deck next-card peek'),
  },
  'card gap': {
    iOS: scalar(swift, /deckCardGap: Double = (\d+)/, 'iOS deck card gap'),
    web: scalar(web, /DECK_CARD_GAP = (\d+)/, 'web deck card gap'),
    Android: scalar(kotlin, /DECK_CARD_GAP = (\d+)f/, 'Android deck card gap'),
  },
  'stagger limit': {
    iOS: scalar(swift, /deckStaggerLimit = (\d+)/, 'iOS deck stagger limit'),
    web: scalar(web, /DECK_STAGGER_LIMIT = (\d+)/, 'web deck stagger limit'),
    Android: scalar(kotlin, /DECK_STAGGER_LIMIT = (\d+)/, 'Android deck stagger limit'),
  },
};

for (const [name, byPlatform] of Object.entries(scalars)) {
  const values = new Set(Object.values(byPlatform));
  if (values.size !== 1) {
    throw new Error(
      `Focus deck ${name} drifted: ${Object.entries(byPlatform)
        .map(([platform, value]) => `${platform}=${value}`)
        .join(', ')}`,
    );
  }
}

// The count under a shut deck is a figure shown to a learner about their own
// library, so all three must derive it from the list's real length rather
// than from the two cards they happen to draw.
for (const [label, source] of [['iOS', swift], ['web', web], ['Android', kotlin]]) {
  for (const phrase of ['1 more course', 'more courses']) {
    if (!source.includes(phrase)) {
      throw new Error(`${label} deck label: missing ${JSON.stringify(phrase)}`);
    }
  }
  if (!/cardCount - 1|count - 1/.test(source)) {
    throw new Error(`${label} deck label: must count the whole list, not the cards drawn`);
  }
}

// An opened deck scrolls sideways on all three, and each card has to stop
// short of the container so the next one's edge shows. A platform that let a
// card run the full width would hide every course after the first behind a
// swipe nothing signals.
for (const [label, source, pattern] of [
  ['iOS', swift, /deckCardWidth\(containerWidth:/],
  ['web', web, /export function deckCardWidth\(/],
  ['Android', kotlin, /fun deckCardWidth\(/],
]) {
  if (!pattern.test(source)) {
    throw new Error(`${label}: the opened deck has no shared card width`);
  }
}

console.log(
  'Focus deck geometry, card width, stagger and count label are identical on iOS, web and Android.',
);
