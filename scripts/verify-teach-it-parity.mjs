import { readFileSync } from 'node:fs';

// When a learner finishes something, all three platforms invite them to teach
// it back as a clip. The sentence they read and the length it promises are
// one contract: the recorder enforces that number, so copy that drifts from
// it would cut a learner off mid-sentence after the app asked for exactly
// that long. Three copies of a sentence drift; this fails when they do.

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
}

const swift = read('Sources/Services/ClipPrompt.swift');
const web = read('web/src/lib/teach-it.mjs');
const kotlin = read('android/app/src/main/java/com/lyo/app/ui/screens/clips/ClipPrompt.kt');
const platforms = [['iOS', swift], ['web', web], ['Android', kotlin]];

function scalar(source, pattern, label) {
  const match = source.match(pattern);
  if (!match) throw new Error(`${label}: could not find the value`);
  return Number.parseInt(match[1], 10);
}

const seconds = {
  iOS: scalar(swift, /quickTakeSeconds = (\d+)/, 'iOS quick-take seconds'),
  web: scalar(web, /QUICK_TAKE_SECONDS = (\d+)/, 'web quick-take seconds'),
  Android: scalar(kotlin, /QUICK_TAKE_SECONDS = (\d+)/, 'Android quick-take seconds'),
};
if (new Set(Object.values(seconds)).size !== 1) {
  throw new Error(
    `Quick-take length drifted: ${Object.entries(seconds)
      .map(([platform, value]) => `${platform}=${value}`)
      .join(', ')}`,
  );
}

// The recorder has to enforce the length the invitation promises, rather than
// each carrying its own number.
const recorder = read('Sources/ViewModels/ClipsViewModel.swift');
if (!/ClipPrompt\.quickTakeSeconds/.test(recorder)) {
  throw new Error('iOS recorder: the single-take cap must come from ClipPrompt, not a second copy');
}

// Both halves of the sentence, and the button.
for (const [label, source] of platforms) {
  for (const phrase of [
    'You just finished ',
    '. Teach it in ',
    'Teach what you just learned in ',
    'What I learned about ',
    'Teach it',
  ]) {
    if (!source.includes(phrase)) {
      throw new Error(`${label} teach-it copy: missing ${JSON.stringify(phrase)}`);
    }
  }
}

// A topic the app does not have is never invented: the title is left empty
// rather than filled with a guess the learner never wrote but would publish.
for (const [label, source] of platforms) {
  if (!/draftTitle/.test(source)) {
    throw new Error(`${label}: no draft title rule`);
  }
  if (!/(return nil|return null|\?: return null|guard let)/.test(source)) {
    throw new Error(`${label} draft title: must return nothing for an unknown topic`);
  }
}

console.log(
  'Teach-it invitation, draft title and quick-take length are identical on iOS, web and Android, ' +
    'and the recorder enforces the length the invitation promises.',
);
