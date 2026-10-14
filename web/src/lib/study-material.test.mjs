import test from 'node:test';
import assert from 'node:assert/strict';

import {
  DECK_BATCH_SIZE,
  DECK_MAX_CARDS,
  MIN_INLINE_CARDS,
  balancedObject,
  classifyStudyAsk,
  extractStudyBlocks,
  hasStudyBlock,
  isStudyBlock,
  mergeCards,
  moreCardsPrompt,
  nextDeckStep,
  parseMoreCards,
} from './study-material.mjs';

const deckOf = (result) => result?.blocks.find((block) => block.type === 'flashcard');
const planOf = (result) => result?.blocks.find((block) => block.subtype === 'studyPlan');
const notesOf = (result) => result?.blocks.find((block) => block.subtype === 'studyNotes');

// ─── The shape the model actually produces ───────────────────────────────────

test('a single "Flashcard Front/Back" pair is a deck', () => {
  // Verbatim from a real answer: one labelled card, with the key points the
  // model hung underneath the back.
  const reply = [
    "Here's a flashcard to help you study for your algebra exam:",
    '',
    '**Flashcard Front:** What is the quadratic formula?',
    '',
    '**Flashcard Back:** The quadratic formula is used to find the solutions of a quadratic equation $ax^2 + bx + c = 0$. It is given by:',
    '',
    '- **Key Points:**',
    '  - $a, b, c$ are coefficients of the equation.',
    '  - The discriminant $b^2 - 4ac$ determines the nature of the roots.',
    '',
    'Would you like to create more flashcards or focus on a different topic?',
  ].join('\n');

  const deck = deckOf(extractStudyBlocks(reply, 'make me a flashcard for my algebra exam'));

  assert.equal(deck.content.cards.length, 1);
  assert.equal(deck.content.cards[0].front, 'What is the quadratic formula?');
  // The back keeps its trailing colon and absorbs the bulleted continuation.
  assert.match(deck.content.cards[0].back, /It is given by:/);
  assert.match(deck.content.cards[0].back, /Key Points/);
  assert.match(deck.content.cards[0].back, /discriminant/);
});

test('the prose around a deck survives as a lead block', () => {
  const reply = [
    "Here's a flashcard to help you study for your algebra exam:",
    '**Front:** What is 2 + 2?',
    '**Back:** 4',
    'Would you like more?',
  ].join('\n');

  const result = extractStudyBlocks(reply, 'flashcard please');
  assert.equal(result.blocks[0].type, 'text');
  assert.match(result.blocks[0].content.text, /algebra exam/);
  assert.match(result.blocks[0].content.text, /Would you like more\?/);
});

// ─── Other shapes models reach for ───────────────────────────────────────────

test('bold term and em dash becomes a deck', () => {
  const reply = [
    'Here are 3 flashcards on photosynthesis:',
    '',
    '**Chlorophyll** — the green pigment that absorbs light energy',
    '**Stroma** — the fluid-filled space inside the chloroplast',
    '**Thylakoid** — stacked membrane where the light reactions happen',
  ].join('\n');

  const deck = deckOf(extractStudyBlocks(reply, 'make flashcards on photosynthesis'));
  assert.equal(deck.content.cards.length, 3);
  assert.equal(deck.content.cards[0].front, 'Chlorophyll');
  assert.equal(deck.content.cards[0].back, 'the green pigment that absorbs light energy');
});

test('a colon tucked inside the emphasis still splits', () => {
  const reply = [
    '**Mitosis:** cell division producing two identical cells',
    '**Meiosis:** division producing four gametes',
    '**Cytokinesis:** the physical split of the cytoplasm',
  ].join('\n');

  const deck = deckOf(extractStudyBlocks(reply, 'flashcards for cell division'));
  assert.equal(deck.content.cards.length, 3);
  assert.equal(deck.content.cards[1].front, 'Meiosis');
});

test('bulleted and numbered pairs become cards', () => {
  const reply = [
    "Sure! Here's your deck:",
    '- Mitochondria: the powerhouse of the cell',
    '- Ribosome: builds proteins from amino acids',
    "1. Nucleus — stores the cell's DNA",
  ].join('\n');

  const deck = deckOf(extractStudyBlocks(reply, 'key terms for cell biology'));
  assert.equal(deck.content.cards.length, 3);
  assert.equal(deck.content.cards[2].front, 'Nucleus');
});

test('Q and A pairs become cards', () => {
  const reply = [
    'Q: What is the capital of France?',
    'A: Paris',
    'Q: What is the capital of Japan?',
    'A: Tokyo',
  ].join('\n');

  const deck = deckOf(extractStudyBlocks(reply, 'flashcards on capital cities'));
  assert.equal(deck.content.cards.length, 2);
  assert.equal(deck.content.cards[0].back, 'Paris');
});

test('a markdown table becomes cards without its header row', () => {
  const reply = [
    '| Term | Definition |',
    '|------|------------|',
    '| Osmosis | Water moving across a semipermeable membrane |',
    '| Diffusion | Particles spreading from high to low concentration |',
    '| Active transport | Movement requiring energy input |',
  ].join('\n');

  const deck = deckOf(extractStudyBlocks(reply, 'make me a study deck on transport'));
  assert.equal(deck.content.cards.length, 3);
  assert.ok(!deck.content.cards.some((card) => card.front === 'Term'));
});

test('a fenced JSON payload with a nested cards array is read whole', () => {
  const reply = [
    'Here you go!',
    '',
    '```json',
    '{"title": "Spanish verbs", "cards": [',
    '  {"front": "hablar", "back": "to speak"},',
    '  {"front": "comer", "back": "to eat"}',
    ']}',
    '```',
  ].join('\n');

  const result = extractStudyBlocks(reply, 'make flashcards for spanish');
  const deck = deckOf(result);
  assert.equal(deck.content.title, 'Spanish verbs');
  assert.equal(deck.content.cards.length, 2);
  assert.equal(result.blocks[0].content.text, 'Here you go!');
});

// ─── What it must refuse to touch ────────────────────────────────────────────

test('an ordinary explanation is left alone', () => {
  // Every line here has a colon. None of them is a card.
  const reply = [
    'Photosynthesis is how plants make food. It happens in the chloroplast.',
    'Note: the light reactions come first, then the Calvin cycle.',
    'Remember: chlorophyll absorbs mostly red and blue light.',
    'In short: plants turn light into sugar.',
  ].join('\n');

  assert.equal(extractStudyBlocks(reply, 'flashcards on photosynthesis'), null);
});

test('a long explanation containing a short list is left alone', () => {
  // Restructuring would replace the explanation with three cards, so it does not.
  const filler =
    'Plants capture light energy and store it as glucose, which powers food chains. '.repeat(8);
  const reply = [
    filler,
    '- Chlorophyll: the green pigment',
    '- Stroma: fluid in the chloroplast',
    '- Thylakoid: membrane stacks',
    filler,
  ].join('\n');

  assert.equal(extractStudyBlocks(reply, 'flashcards on photosynthesis'), null);
});

test('two inferred pairs are too few to be a deck', () => {
  const reply = [
    '- Mitochondria: the powerhouse of the cell',
    '- Ribosome: builds proteins from amino acids',
  ].join('\n');

  assert.ok(MIN_INLINE_CARDS > 2);
  assert.equal(extractStudyBlocks(reply, 'flashcards on the cell'), null);
});

test('no study ask means no restructuring', () => {
  const reply = [
    '- Mitochondria: the powerhouse of the cell',
    '- Ribosome: builds proteins from amino acids',
    "- Nucleus: stores the cell's DNA",
  ].join('\n');

  assert.equal(extractStudyBlocks(reply, 'what does a cell contain?'), null);
});

test('a reply that calls itself a deck is honoured without an explicit ask', () => {
  const reply = [
    'Flashcards for chapter 4:',
    '- Alpha: first letter',
    '- Beta: second letter',
    '- Gamma: third letter',
  ].join('\n');

  const deck = deckOf(extractStudyBlocks(reply, 'do that for chapter 4'));
  assert.equal(deck.content.cards.length, 3);
});

// ─── Plans and notes ─────────────────────────────────────────────────────────

test('day headings become a study plan', () => {
  const reply = [
    '# Three-day revision plan',
    '',
    '**Day 1 — Cell structure**',
    '- Read chapter 2 (30 min)',
    '- Practice 10 problems (20 min)',
    '',
    '**Day 2 — Cell division**',
    '- Watch the mitosis video (15 min)',
    '',
    '**Day 3 — Review**',
    '- Redo missed questions',
  ].join('\n');

  const plan = planOf(extractStudyBlocks(reply, 'build me a study plan'));
  assert.equal(plan.content.schedule.length, 3);
  assert.equal(plan.content.schedule[0].topic, 'Cell structure');
  assert.equal(plan.content.schedule[0].tasks[0].minutes, 30);
  assert.equal(plan.content.schedule[1].tasks[0].kind, 'watch');
});

test('headed sections become study notes', () => {
  const reply = [
    '# Photosynthesis study guide',
    '',
    'Use this before the test.',
    '',
    '## Light reactions',
    'Happen in the thylakoid membrane and produce ATP and NADPH.',
    '',
    '## Calvin cycle',
    'Happens in the stroma and fixes carbon into glucose.',
  ].join('\n');

  const notes = notesOf(extractStudyBlocks(reply, 'give me study material on photosynthesis'));
  assert.equal(notes.content.sections.length, 2);
  assert.equal(notes.content.sections[0].title, 'Light reactions');
  assert.equal(notes.content.title, 'Photosynthesis study guide');
});

// ─── Pieces ──────────────────────────────────────────────────────────────────

test('intent classification', () => {
  assert.equal(classifyStudyAsk('make flashcards on osmosis'), 'flashcards');
  assert.equal(classifyStudyAsk('build a study plan for finals'), 'studyPlan');
  assert.equal(classifyStudyAsk('give me a study guide'), 'notes');
  assert.equal(classifyStudyAsk('why is the sky blue?'), 'unrelated');
});

test('brace balancing survives a nested array', () => {
  assert.equal(balancedObject('{"a":[{"b":1}]} trailing'), '{"a":[{"b":1}]}');
  // A brace inside a string must not close the object.
  assert.equal(balancedObject('{"a":"}"}'), '{"a":"}"}');
  assert.equal(balancedObject('no object here'), null);
});

// ─── Growing the deck ────────────────────────────────────────────────────────

test('the next-batch prompt asks for a fixed count and names what to avoid', () => {
  const prompt = moreCardsPrompt('photosynthesis', ['Chlorophyll', 'Stroma']);
  assert.match(prompt, new RegExp(`exactly ${DECK_BATCH_SIZE} more flashcards`));
  assert.match(prompt, /photosynthesis/);
  assert.match(prompt, /- Chlorophyll/);
  assert.match(prompt, /- Stroma/);
});

test('the prompt names only the most recent cards, so it cannot grow unbounded', () => {
  const fronts = Array.from({ length: 50 }, (_, i) => `Card ${i}`);
  const prompt = moreCardsPrompt('history', fronts);
  assert.ok(!prompt.includes('- Card 0'));
  assert.ok(prompt.includes('- Card 49'));
});

test('a JSON batch is read', () => {
  const reply = '```json\n{"cards":[{"front":"ATP","back":"energy currency"}]}\n```';
  assert.deepEqual(parseMoreCards(reply), [{ front: 'ATP', back: 'energy currency' }]);
});

test('a batch that ignored "JSON only" is still read', () => {
  // The model answered in Markdown. The cards are still there.
  const reply = [
    'Here are three more:',
    '- Osmosis: water across a membrane',
    '- Diffusion: particles spreading out',
    '- Turgor: pressure inside a plant cell',
  ].join('\n');
  assert.equal(parseMoreCards(reply).length, 3);
});

test('a batch with nothing usable yields no cards', () => {
  assert.deepEqual(parseMoreCards('Sorry, I cannot help with that.'), []);
});

test('merging skips cards the deck already has, however they are punctuated', () => {
  const existing = [{ front: 'What is ATP?', back: 'Energy currency' }];
  const merged = mergeCards(existing, [
    { front: 'what is atp', back: 'Energy currency again' },
    { front: 'What is ADP?', back: 'What ATP becomes' },
  ]);
  assert.equal(merged.length, 2);
  assert.equal(merged[1].front, 'What is ADP?');
});

test('merging never grows a deck past the cap', () => {
  const existing = Array.from({ length: DECK_MAX_CARDS }, (_, i) => ({
    front: `Front ${i}`,
    back: `Back ${i}`,
  }));
  const merged = mergeCards(existing, [{ front: 'One more', back: 'Please' }]);
  assert.equal(merged.length, DECK_MAX_CARDS);
});

test('merging drops half-formed cards rather than showing a blank face', () => {
  const merged = mergeCards([], [
    { front: 'Has both', back: 'Yes' },
    { front: 'Missing back' },
    { back: 'Missing front' },
  ]);
  assert.equal(merged.length, 1);
});

// ─── When the next batch happens ─────────────────────────────────────────────

test('mid-batch, a deck sits still', () => {
  // Three cards shown, learner on the first two: nothing to do.
  assert.equal(nextDeckStep({ index: 0, revealed: 3, total: 3 }), 'idle');
  assert.equal(nextDeckStep({ index: 1, revealed: 3, total: 3 }), 'idle');
});

test('arriving at the third card asks for three more', () => {
  // This is the whole point: the fetch fires on arrival at the last card,
  // so the next swipe is already paid for.
  assert.equal(nextDeckStep({ index: 2, revealed: 3, total: 3 }), 'fetch');
});

test('cards already parsed from the reply are shown rather than re-fetched', () => {
  // The reply gave eight; only three are revealed. Reaching the third costs
  // nothing — the next three are already in hand.
  assert.equal(nextDeckStep({ index: 2, revealed: 3, total: 8 }), 'reveal');
});

test('a request in flight is never duplicated', () => {
  assert.equal(nextDeckStep({ index: 2, revealed: 3, total: 3, loading: true }), 'idle');
});

test('a deck that has run dry stops asking', () => {
  assert.equal(nextDeckStep({ index: 2, revealed: 3, total: 3, exhausted: true }), 'idle');
});

test('the cap ends the deck even while the learner keeps swiping', () => {
  assert.equal(
    nextDeckStep({ index: DECK_MAX_CARDS - 1, revealed: DECK_MAX_CARDS, total: DECK_MAX_CARDS }),
    'idle'
  );
});

test('an empty deck asks for nothing', () => {
  assert.equal(nextDeckStep({ index: 0, revealed: 3, total: 0 }), 'idle');
});

test('batches continue after the first: card six asks again', () => {
  assert.equal(nextDeckStep({ index: 5, revealed: 6, total: 6 }), 'fetch');
  assert.equal(nextDeckStep({ index: 4, revealed: 6, total: 6 }), 'idle');
});

// ─── Whether a turn still needs study material ───────────────────────────────

test('the backend\'s own study content suppresses the fallback', () => {
  assert.ok(isStudyBlock({ type: 'flashcard', content: {} }));
  assert.ok(isStudyBlock({ type: 'quiz', content: {} }));
  assert.ok(isStudyBlock({ type: 'interactive', subtype: 'studyPlan', content: {} }));
  assert.ok(isStudyBlock({ type: 'interactive', subtype: 'studyNotes', content: {} }));
});

test('an ordinary block does not', () => {
  // This is the bug that made a deck never appear: the backend sends a text
  // block on ordinary turns, and treating that as "already handled" left the
  // learner with the paragraph they were trying to get away from.
  assert.ok(!isStudyBlock({ type: 'text', content: { text: 'hello' } }));
  assert.ok(!isStudyBlock({ type: 'dataViz', content: {} }));
  assert.ok(!isStudyBlock({ type: 'interactive', subtype: 'explorable', content: {} }));
  assert.ok(!isStudyBlock(null));
});

test('a turn carrying only text still needs its deck', () => {
  assert.equal(hasStudyBlock([{ type: 'text', content: { text: 'Here are flashcards:' } }]), false);
  assert.equal(hasStudyBlock([]), false);
  assert.equal(hasStudyBlock(undefined), false);
});

test('a turn that already has a deck does not', () => {
  assert.equal(
    hasStudyBlock([
      { type: 'text', content: { text: 'intro' } },
      { type: 'flashcard', content: { cards: [] } },
    ]),
    true
  );
});
