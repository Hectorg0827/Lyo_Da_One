import test from 'node:test';
import assert from 'node:assert/strict';

import { expandVisualBlocks, isDrawableChart, segmentVisuals } from './teaching-visuals.mjs';

const textBlock = (text, id = 'b1') => ({ id, type: 'text', content: { text } });
const kinds = (segments) => (segments ?? []).map((s) => s.kind);

// ─── Diagrams ────────────────────────────────────────────────────────────────

test('a mermaid fence becomes a diagram with its prose kept either side', () => {
  const reply = [
    'Here is how photosynthesis flows:',
    '',
    '```mermaid',
    'graph TD',
    '  A[Sunlight] --> B[Chlorophyll]',
    '```',
    '',
    'The light reactions come first.',
  ].join('\n');

  assert.deepEqual(kinds(segmentVisuals(reply)), ['text', 'mermaid', 'text']);

  const blocks = expandVisualBlocks([textBlock(reply)]);
  assert.deepEqual(blocks.map((b) => b.type), ['text', 'dataViz', 'text']);
  assert.equal(blocks[1].content.format, 'mermaid');
  assert.match(blocks[1].content.source, /graph TD/);
  // The sentence after the diagram survives, in its original position.
  assert.equal(blocks[2].content.text, 'The light reactions come first.');
});

test('an enormous diagram stays a code listing', () => {
  const huge = '```mermaid\ngraph TD\n' + 'A-->B\n'.repeat(1200) + '```';
  assert.equal(segmentVisuals(huge), null);
});

test('an empty fence is not a diagram', () => {
  assert.equal(segmentVisuals('```mermaid\n\n```'), null);
});

// ─── Charts ──────────────────────────────────────────────────────────────────

test('a valid chart payload becomes a chart', () => {
  const reply = '```chart\n{"chartType":"bar","labels":["A","B"],"values":[1,2]}\n```';
  const blocks = expandVisualBlocks([textBlock(reply)]);
  assert.deepEqual(blocks.map((b) => b.type), ['dataViz']);
  assert.equal(blocks[0].content.format, 'chart');
});

test('a chart the renderer would reject stays code', () => {
  // Mirrors ChartView's own guard, so we never make a block that renders as
  // raw source anyway.
  assert.ok(!isDrawableChart('not json'));
  assert.ok(!isDrawableChart('{"chartType":"pie","labels":["A"],"values":[1]}'));
  assert.ok(!isDrawableChart('{"chartType":"bar","labels":["A"],"values":[1,2]}'));
  assert.ok(!isDrawableChart('{"chartType":"bar","labels":["A"],"values":[-1]}'));
  assert.ok(!isDrawableChart(JSON.stringify({
    chartType: 'bar',
    labels: Array.from({ length: 13 }, (_, i) => `L${i}`),
    values: Array.from({ length: 13 }, () => 1),
  })));
  assert.ok(isDrawableChart('{"chartType":"line","labels":["A","B"],"values":[0,2.5]}'));
  assert.equal(segmentVisuals('```chart\nnot json\n```'), null);
});

// ─── Images ──────────────────────────────────────────────────────────────────

test('an image on its own line becomes a framed figure', () => {
  const reply = 'Here is a chloroplast:\n\n![Chloroplast](https://example.org/c.png)';
  const blocks = expandVisualBlocks([textBlock(reply)]);
  assert.deepEqual(blocks.map((b) => b.type), ['text', 'media']);
  assert.equal(blocks[1].subtype, 'image');
  assert.equal(blocks[1].content.url, 'https://example.org/c.png');
  assert.equal(blocks[1].content.alt, 'Chloroplast');
});

test('an image inside a sentence stays in the sentence', () => {
  // Pulling it out would break the line it belongs to.
  assert.equal(segmentVisuals('See ![this](https://example.org/c.png) for detail.'), null);
});

test('a non-https image is left alone', () => {
  assert.equal(segmentVisuals('![x](http://example.org/c.png)'), null);
  assert.equal(segmentVisuals('![x](javascript:alert(1))'), null);
});

// ─── Leaving things alone ────────────────────────────────────────────────────

test('ordinary prose is untouched', () => {
  assert.equal(segmentVisuals('Photosynthesis happens in the chloroplast.'), null);
  assert.equal(expandVisualBlocks([textBlock('Just words.')]), null);
});

test('a code fence in another language stays code', () => {
  assert.equal(segmentVisuals('```python\nprint("hi")\n```'), null);
});

test('blocks that are not text are passed through untouched', () => {
  const quiz = { id: 'q', type: 'quiz', content: { question: 'x', options: [] } };
  const reply = 'Flow:\n\n```mermaid\ngraph TD\nA-->B\n```';
  const blocks = expandVisualBlocks([quiz, textBlock(reply, 'b2')]);
  assert.equal(blocks[0], quiz);
  assert.deepEqual(blocks.slice(1).map((b) => b.type), ['text', 'dataViz']);
});

test('several visuals in one reply keep their order', () => {
  const reply = [
    'First:',
    '```mermaid',
    'graph TD',
    'A-->B',
    '```',
    'Then a picture:',
    '![Pic](https://example.org/p.png)',
    'Done.',
  ].join('\n');
  assert.deepEqual(kinds(segmentVisuals(reply)), ['text', 'mermaid', 'text', 'image', 'text']);
});
