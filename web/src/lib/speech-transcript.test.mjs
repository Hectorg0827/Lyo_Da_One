import test from 'node:test';
import assert from 'node:assert/strict';
import {
  bestAlternative,
  createTranscriptAccumulator,
  mergeTranscript,
  normalizeSpeechLang,
  tidyTranscript,
} from './speech-transcript.mjs';

/** Build a result list in the shape the Web Speech API delivers. */
function results(entries) {
  return entries.map(([transcript, isFinal = false, confidence = 0.9]) => {
    const result = [{ transcript, confidence }];
    result.isFinal = isFinal;
    return result;
  });
}

test('a restated hypothesis extends the sentence instead of repeating it', () => {
  assert.equal(mergeTranscript('can', 'can I'), 'can I');
  assert.equal(mergeTranscript('can I activate', 'can I activate voice'), 'can I activate voice');
  assert.equal(mergeTranscript('I want to try', 'to try to see'), 'I want to try to see');
});

test('merging keeps genuinely new speech and genuine repetition', () => {
  assert.equal(mergeTranscript('hello there', 'how are you'), 'hello there how are you');
  assert.equal(mergeTranscript('', 'first words'), 'first words');
  assert.equal(mergeTranscript('already said', ''), 'already said');
  assert.equal(mergeTranscript('that is a no', 'no'), 'that is a no no');
});

test('merging ignores casing and punctuation when spotting a restatement', () => {
  assert.equal(mergeTranscript('Can I activate', 'can I, activate voice mode'), 'Can I activate voice mode');
});

test('Android-style interim results no longer duplicate every spoken word', () => {
  // Chrome on Android appends each interim hypothesis as a new entry rather
  // than replacing it — the exact shape that produced "cancan Ican I activate".
  const accumulator = createTranscriptAccumulator();
  const event = {
    resultIndex: 0,
    results: results([
      ['can'],
      ['can I'],
      ['can I activate'],
      ['can I activate voice'],
      ['can I activate voice mode'],
    ]),
  };
  assert.equal(accumulator.push(event).combined, 'can I activate voice mode');
});

test('desktop-style in-place interim results still read correctly', () => {
  const accumulator = createTranscriptAccumulator();
  assert.equal(accumulator.push({ resultIndex: 0, results: results([['hello']]) }).combined, 'hello');
  assert.equal(
    accumulator.push({ resultIndex: 0, results: results([['hello there']]) }).combined,
    'hello there',
  );
  assert.equal(
    accumulator.push({ resultIndex: 0, results: results([['hello there friend', true]]) }).combined,
    'hello there friend',
  );
});

test('a final result is folded in once even if the event is redelivered', () => {
  const accumulator = createTranscriptAccumulator();
  const event = { resultIndex: 0, results: results([['good morning', true]]) };
  accumulator.push(event);
  accumulator.push(event);
  assert.equal(accumulator.push(event).combined, 'good morning');
});

test('settled speech survives a new interim phrase', () => {
  const accumulator = createTranscriptAccumulator();
  accumulator.push({ resultIndex: 0, results: results([['first sentence', true]]) });
  const state = accumulator.push({
    resultIndex: 1,
    results: results([['first sentence', true], ['and then some']]),
  });
  assert.equal(state.final, 'first sentence');
  assert.equal(state.combined, 'first sentence and then some');
});

test('a recognizer restart continues the dictation rather than dropping it', () => {
  const accumulator = createTranscriptAccumulator();
  accumulator.push({ resultIndex: 0, results: results([['before the restart', true]]) });
  accumulator.carryOver();
  const state = accumulator.push({ resultIndex: 0, results: results([['after the restart', true]]) });
  assert.equal(state.combined, 'before the restart after the restart');
});

test('words still unconfirmed when a recognizer ends are not lost', () => {
  // A recognizer that stops during a pause may never finalize its last
  // hypothesis. Those words are already on screen, so the next recognizer
  // must build on them rather than erase them.
  const accumulator = createTranscriptAccumulator();
  accumulator.push({ resultIndex: 0, results: results([['the mitochondria is', true]]) });
  accumulator.push({ resultIndex: 1, results: results([['the mitochondria is', true], ['the powerhouse']]) });
  accumulator.carryOver();
  const state = accumulator.push({ resultIndex: 0, results: results([['of the cell']]) });
  assert.equal(state.combined, 'the mitochondria is the powerhouse of the cell');
});

test('a restart after a finalized phrase does not double it', () => {
  const accumulator = createTranscriptAccumulator();
  accumulator.push({ resultIndex: 0, results: results([['all done']]) });
  accumulator.push({ resultIndex: 0, results: results([['all done', true]]) });
  accumulator.carryOver();
  assert.equal(accumulator.final, 'all done');
  const state = accumulator.push({ resultIndex: 0, results: results([['and more', true]]) });
  assert.equal(state.combined, 'all done and more');
});

test('reset clears the dictation for the next session', () => {
  const accumulator = createTranscriptAccumulator();
  accumulator.push({ resultIndex: 0, results: results([['old words', true]]) });
  accumulator.reset();
  assert.equal(accumulator.push({ resultIndex: 0, results: results([['new words']]) }).combined, 'new words');
});

test('malformed events are survivable', () => {
  const accumulator = createTranscriptAccumulator();
  assert.equal(accumulator.push({}).combined, '');
  assert.equal(accumulator.push({ results: [] }).combined, '');
  assert.equal(accumulator.push({ results: [[]] }).combined, '');
});

test('the most confident wording wins when alternatives are unsorted', () => {
  const result = [
    { transcript: 'wreck a nice beach', confidence: 0.31 },
    { transcript: 'recognize speech', confidence: 0.92 },
  ];
  assert.equal(bestAlternative(result), 'recognize speech');
  assert.equal(bestAlternative([{ transcript: '  ' }, { transcript: 'fallback' }]), 'fallback');
  assert.equal(bestAlternative(null), '');
});

test('bare language tags are widened to a region the recognizer knows', () => {
  assert.equal(normalizeSpeechLang('en'), 'en-US');
  assert.equal(normalizeSpeechLang('es'), 'es-US');
  assert.equal(normalizeSpeechLang('en-gb'), 'en-GB');
  assert.equal(normalizeSpeechLang('pt_br'), 'pt-BR');
  assert.equal(normalizeSpeechLang(''), 'en-US');
  assert.equal(normalizeSpeechLang(undefined), 'en-US');
});

test('dictated text reads as a sentence', () => {
  assert.equal(tidyTranscript('  hello   there , friend '), 'Hello there, friend');
  assert.equal(tidyTranscript(''), '');
  // Dictation continuing text the user typed is joined on, not re-started.
  assert.equal(tidyTranscript('and then this', { capitalize: false }), 'and then this');
});
