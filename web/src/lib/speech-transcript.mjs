/**
 * Speech-to-text transcript assembly.
 *
 * The Web Speech API hands back a *cumulative* result list, and browsers
 * disagree about what lives in it. Chrome on desktop replaces the single
 * interim result in place; Chrome on Android instead appends every interim
 * hypothesis as a new entry, each one restating the whole phrase so far
 * ("can", "can I", "can I activate"). Naively concatenating every entry —
 * which is the obvious reading of the spec — therefore produces the
 * "cancan Ican I activate" stutter on exactly the devices most people
 * dictate from.
 *
 * These helpers assemble one clean transcript from either shape: each final
 * result is folded in at most once, and every fold is overlap-aware, so a
 * restated hypothesis extends the sentence instead of repeating it.
 */

/** Word-level overlap search window. Beyond this a repeat is real speech. */
const MAX_OVERLAP_WORDS = 12;

/** Languages the recognizer is markedly more accurate on when region-tagged. */
const DEFAULT_REGIONS = {
  en: 'en-US',
  es: 'es-US',
  pt: 'pt-BR',
  fr: 'fr-FR',
  de: 'de-DE',
  it: 'it-IT',
  nl: 'nl-NL',
  zh: 'zh-CN',
  ar: 'ar-SA',
  hi: 'hi-IN',
};

/**
 * A region-qualified language tag for the recognizer.
 *
 * A bare tag like "en" makes the recognizer guess the accent model, which
 * measurably hurts word accuracy, so bare tags are widened to their most
 * common region.
 */
export function normalizeSpeechLang(raw) {
  const tag = typeof raw === 'string' ? raw.trim().replace(/_/g, '-') : '';
  if (!tag) return 'en-US';
  const [language, region] = tag.split('-');
  const base = language.toLowerCase();
  if (region) return `${base}-${region.toUpperCase()}`;
  return DEFAULT_REGIONS[base] || base;
}

/** Comparison form: letters, digits and single spaces only. */
function comparable(text) {
  return String(text ?? '')
    .toLocaleLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * The most confident wording of one result.
 *
 * Alternatives usually arrive best-first, but not every engine sorts them,
 * and a blank top alternative is common while audio is still arriving.
 */
export function bestAlternative(result) {
  if (!result) return '';
  const count = Math.max(0, Number(result.length) || 0);
  let best = '';
  let bestConfidence = -Infinity;
  for (let index = 0; index < count; index++) {
    const alternative = result[index];
    const transcript = typeof alternative?.transcript === 'string'
      ? alternative.transcript.trim()
      : '';
    if (!transcript) continue;
    const confidence = Number(alternative?.confidence);
    const score = Number.isFinite(confidence) ? confidence : 0;
    if (score > bestConfidence) {
      best = transcript;
      bestConfidence = score;
    }
  }
  return best;
}

/**
 * Join `addition` onto `base`, dropping the part it merely restates.
 *
 * This is what turns the Android stutter back into a sentence: "can I" onto
 * "can" is "can I", not "can can I".
 */
export function mergeTranscript(base, addition) {
  const left = String(base ?? '').trim();
  const right = String(addition ?? '').trim();
  if (!left) return right;
  if (!right) return left;

  const leftWords = left.split(/\s+/);
  const rightWords = right.split(/\s+/);
  const leftKeys = leftWords.map(comparable);
  const rightKeys = rightWords.map(comparable);

  const matchesAt = (count) => {
    const offset = leftKeys.length - count;
    for (let index = 0; index < count; index++) {
      if (leftKeys[offset + index] !== rightKeys[index]) return false;
    }
    return true;
  };

  // A hypothesis the sentence already ends with adds nothing. Single-word
  // repeats are only dropped when they restate the whole of what we have,
  // so a genuine "no no" survives.
  if (
    rightWords.length <= leftWords.length
    && matchesAt(rightWords.length)
    && (rightWords.length > 1 || leftKeys.join(' ') === rightKeys.join(' '))
  ) {
    return left;
  }

  const limit = Math.min(MAX_OVERLAP_WORDS, leftWords.length, rightWords.length);
  for (let count = limit; count >= 1; count--) {
    if (count < rightWords.length && matchesAt(count)) {
      return `${left} ${rightWords.slice(count).join(' ')}`;
    }
  }
  return `${left} ${right}`;
}

/**
 * Readable spacing, punctuation and sentence case for dictated text.
 *
 * Pass `capitalize: false` when the dictation continues text the user already
 * typed, so it is joined on rather than started as a new sentence.
 */
export function tidyTranscript(text, options) {
  const cleaned = String(text ?? '')
    .replace(/\s+/g, ' ')
    .replace(/\s+([,.!?;:])/g, '$1')
    .replace(/([,;:])(?=\p{L})/gu, '$1 ')
    .trim();
  if (!cleaned) return '';
  if (options?.capitalize === false) return cleaned;
  return cleaned.replace(/^\p{Ll}/u, (first) => first.toLocaleUpperCase());
}

/**
 * Collects one dictation into a single transcript.
 *
 * `push` takes a raw SpeechRecognition result event and returns the text as
 * it should now be displayed. Results already folded in are never counted
 * twice, so the same event may safely be delivered more than once.
 */
export function createTranscriptAccumulator() {
  let settled = '';
  let pending = '';
  let committedThrough = -1;

  return {
    /** Text the recognizer has committed to so far. */
    get final() {
      return settled;
    },

    push(event) {
      const results = event?.results;
      const length = Math.max(0, Number(results?.length) || 0);
      let interim = '';

      for (let index = 0; index < length; index++) {
        const result = results[index];
        const transcript = bestAlternative(result);
        if (!transcript) continue;
        if (result?.isFinal) {
          if (index <= committedThrough) continue;
          committedThrough = index;
          settled = mergeTranscript(settled, transcript);
        } else if (index > committedThrough) {
          interim = mergeTranscript(interim, transcript);
        }
      }

      pending = interim;
      const combined = mergeTranscript(settled, interim);
      return { final: settled, interim, combined };
    },

    /**
     * Keep the words said so far but forget result positions, for when the
     * recognizer restarts mid-dictation and begins numbering again at zero.
     *
     * A recognizer that ends without finalizing its last hypothesis still said
     * those words on screen, so they are committed here rather than dropped —
     * otherwise the next recognizer's first result would erase them.
     */
    carryOver() {
      settled = mergeTranscript(settled, pending);
      pending = '';
      committedThrough = -1;
    },

    reset() {
      settled = '';
      pending = '';
      committedThrough = -1;
    },
  };
}
