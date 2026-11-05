import { parseTeachingVisual } from './teaching-activity.mjs';

/**
 * A very small, intentionally conservative bridge for legacy lesson text that
 * refers to a fraction model without supplying a structured teaching visual.
 *
 * It is not a general natural-language parser: a drawable model needs three
 * explicit facts in the narration (shape, *equal* partition count, and shaded
 * count). Never guess from an answer choice or a bare fraction such as 3/5.
 */
const numberWords = Object.freeze({
  one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7,
  eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12, thirteen: 13,
  fourteen: 14, fifteen: 15, sixteen: 16, seventeen: 17, eighteen: 18,
  nineteen: 19, twenty: 20,
});
const number = '(?:\\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty)';
const piece = '(?:parts?|pieces?|sections?|slices?|sectors?)';
const shade = '(?:shaded|colou?red|filled|highlighted)';
const count = raw => /^\d+$/.test(raw) ? Number(raw) : numberWords[raw.toLowerCase()];

const partitionPatterns = [
  new RegExp(`\\b(?:divided|split|partitioned|separated)\\s+(?:evenly\\s+)?into\\s+(${number})\\s+(?:equal|equally[\\s-]sized|same[\\s-]sized)\\s+${piece}\\b`, 'gi'),
  new RegExp(`\\b(?:divided|split|partitioned|separated)\\s+(?:evenly\\s+)?into\\s+(${number})\\s+${piece}\\s+of\\s+equal\\s+size\\b`, 'gi'),
  new RegExp(`\\b(?:divided|split|partitioned|separated)\\s+evenly\\s+into\\s+(${number})\\s+${piece}\\b`, 'gi'),
];

const shadedPatterns = [
  new RegExp(`\\b(${number})\\s+(?:of\\s+(?:those|these|the|its)\\s+)?(?:equal\\s+)?${piece}\\s+(?:(?:are|is|were|have\\s+been)\\s+)?${shade}\\b`, 'gi'),
  new RegExp(`\\b(${number})\\s+(?:are|is|were)\\s+${shade}\\b`, 'gi'),
  new RegExp(`\\bwith\\s+(${number})\\s+${shade}(?:\\s+${piece})?\\b`, 'gi'),
  new RegExp(`\\b${shade}\\s+(${number})\\s+${piece}\\b`, 'gi'),
];

function explicitCounts(text, patterns) {
  const values = new Set();
  for (const pattern of patterns) {
    // `matchAll` uses each regexp's own lastIndex; fresh input every call.
    pattern.lastIndex = 0;
    for (const match of text.matchAll(pattern)) values.add(count(match[1]));
  }
  return values;
}

/** Strip labelled multiple-choice answers before searching for narrated facts. */
function modelNarration(text) {
  // The A/B/C/D answer text is never authoritative evidence for a model.
  const option = /(?:^|\s)(?:\(?[A-D]\)|[A-D][.)]|option\s+[A-D][.:])\s*(?=\S)/im.exec(text);
  return (option ? text.slice(0, option.index) : text).trim();
}

/**
 * @param {unknown} rawText Plain-English lesson/quiz narration.
 * @returns {import('./teaching-activity.mjs').TeachingVisual|null}
 */
export function inferExplicitFractionVisual(rawText) {
  if (typeof rawText !== 'string' || rawText.length < 15 || rawText.length > 6000) return null;
  const text = modelNarration(rawText.replace(/\s+/g, ' '));
  if (!text) return null;

  const bar = /\b(?:fraction\s+bar|bar\s+model|rectangles?|rectangular\s+models?|bars?)\b/i.test(text);
  const pie = /\b(?:fraction\s+pie|pie\s+(?:chart|model)|circles?|circular\s+models?)\b/i.test(text);
  // Two model kinds in one narration are ambiguous. A diagram cannot be
  // selected safely from answer choices or surrounding curriculum references.
  if (bar === pie) return null;

  // Qualifiers that make a count an estimate rather than a drawable fact.
  if (/\b(?:about|approximately|roughly|maybe|perhaps|around|nearly)\s+(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\b/i.test(text)) return null;

  const parts = explicitCounts(text, partitionPatterns);
  const shaded = explicitCounts(text, shadedPatterns);
  if (parts.size !== 1 || shaded.size !== 1) return null;
  const [denominator] = parts;
  const [numerator] = shaded;
  if (!Number.isInteger(denominator) || !Number.isInteger(numerator)
    || denominator < (pie ? 1 : 2) || denominator > 20
    || numerator < 0 || numerator > denominator) return null;

  const kind = pie ? 'fraction_pie' : 'fraction_bar';
  const description = `${denominator} equal parts, ${numerator} shaded`;
  return parseTeachingVisual({
    kind,
    title: pie ? 'Fraction circle model' : 'Fraction bar model',
    caption: description,
    description,
    parts: denominator,
    value: numerator,
    whole: 1,
    unit: 'whole',
  });
}
