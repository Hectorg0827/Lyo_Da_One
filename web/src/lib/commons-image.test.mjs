import test from 'node:test';
import assert from 'node:assert/strict';

import { commonsSearchUrl, parseCommonsResponse, resolveCommonsImage } from './commons-image.mjs';
import { imageAsk } from './teaching-visuals.mjs';

const response = (pages) => ({ query: { pages } });
const page = (over = {}) => ({
  1: {
    title: 'File:Chloroplast.jpg',
    canonicalurl: 'https://commons.wikimedia.org/wiki/File:Chloroplast.jpg',
    imageinfo: [{ thumburl: 'https://upload.wikimedia.org/a/b/chloroplast.jpg' }],
    ...over,
  },
});

// ─── Asking to see something ─────────────────────────────────────────────────

test('an explicit ask names what to look up', () => {
  assert.equal(imageAsk('show me a picture of a chloroplast'), 'a chloroplast');
  assert.equal(imageAsk('what does a chloroplast look like?'), 'a chloroplast');
  assert.equal(imageAsk('photo of Mount Fuji'), 'Mount Fuji');
  assert.equal(imageAsk('find me an image of the Colosseum'), 'the Colosseum');
});

test('anything short of an explicit ask looks up nothing', () => {
  // A picture nobody asked for is worse than no picture.
  assert.equal(imageAsk('explain photosynthesis'), null);
  assert.equal(imageAsk('make me flashcards on the cell'), null);
  assert.equal(imageAsk('why is the sky blue?'), null);
  assert.equal(imageAsk(''), null);
  // A diagram is drawn from the reply, never searched for.
  assert.equal(imageAsk('show me a diagram of the cell'), null);
});

// ─── The request ─────────────────────────────────────────────────────────────

test('the search asks Commons for one bitmap in the file namespace', () => {
  const url = commonsSearchUrl('chloroplast');
  assert.match(url, /^https:\/\/commons\.wikimedia\.org\/w\/api\.php\?/);
  assert.match(url, /gsrsearch=filetype%3Abitmap\+chloroplast/);
  assert.match(url, /gsrlimit=1/);
  assert.match(url, /gsrnamespace=6/);
  // CORS: the browser calls this directly, with no key and no backend.
  assert.match(url, /origin=\*/);
});

// ─── The response ────────────────────────────────────────────────────────────

test('a usable response yields the file, a credit and its source page', () => {
  const found = parseCommonsResponse(response(page()));
  assert.equal(found.url, 'https://upload.wikimedia.org/a/b/chloroplast.jpg');
  assert.equal(found.attribution, 'Chloroplast.jpg');
  assert.equal(found.sourceUrl, 'https://commons.wikimedia.org/wiki/File:Chloroplast.jpg');
});

test('a URL that is not Commons own file host is refused', () => {
  // A search result is third-party input, so the host is checked exactly —
  // a lookalike domain must not reach an <img> tag.
  const evil = ['https://upload.wikimedia.org.evil.test/x.jpg', 'http://upload.wikimedia.org/x.jpg',
    'https://user:pw@upload.wikimedia.org/x.jpg', 'https://upload.wikimedia.org/', 'not a url'];
  for (const thumburl of evil) {
    assert.equal(parseCommonsResponse(response(page({ imageinfo: [{ thumburl }] }))), null, thumburl);
  }
});

test('a credit page on the wrong host is dropped, the image is still used', () => {
  const found = parseCommonsResponse(response(page({ canonicalurl: 'https://evil.test/page' })));
  assert.equal(found.url, 'https://upload.wikimedia.org/a/b/chloroplast.jpg');
  assert.equal(found.sourceUrl, undefined);
});

test('an unfamiliar or empty response yields nothing', () => {
  assert.equal(parseCommonsResponse(null), null);
  assert.equal(parseCommonsResponse({}), null);
  assert.equal(parseCommonsResponse(response({})), null);
  assert.equal(parseCommonsResponse(response({ 1: { title: 'File:x', imageinfo: [] } })), null);
});

// ─── The lookup as a whole ───────────────────────────────────────────────────

test('a found image comes back', async () => {
  const found = await resolveCommonsImage('chloroplast', async () => ({
    ok: true, json: async () => response(page()),
  }));
  assert.equal(found.url, 'https://upload.wikimedia.org/a/b/chloroplast.jpg');
});

test('a failed lookup is silence, never a thrown error', async () => {
  // An illustration is a nicety; a miss must not break the learner's turn.
  assert.equal(await resolveCommonsImage('x', async () => { throw new Error('offline'); }), null);
  assert.equal(await resolveCommonsImage('x', async () => ({ ok: false })), null);
  assert.equal(await resolveCommonsImage('x', async () => ({
    ok: true, json: async () => { throw new Error('bad json'); },
  })), null);
  assert.equal(await resolveCommonsImage('', async () => { throw new Error('never called'); }), null);
});
