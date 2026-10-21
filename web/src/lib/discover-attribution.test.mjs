import assert from 'node:assert/strict';
import test from 'node:test';

import { attributionFor } from './discover-attribution.mjs';

test('a library video shows its credit, licence and source link', () => {
  assert.deepEqual(
    attributionFor({
      attribution: {
        credit: 'NASA/JPL-Caltech · Public domain',
        sourceName: 'NASA Image and Video Library',
        sourceURL: 'https://images.nasa.gov/details/PIA24546',
        license: 'Public domain',
        licenseURL: 'https://www.nasa.gov/nasa-brand-center/images-and-media/',
      },
    }),
    {
      text: 'NASA/JPL-Caltech · Public domain',
      sourceName: 'NASA Image and Video Library',
      sourceHref: 'https://images.nasa.gov/details/PIA24546',
      licenseHref: 'https://www.nasa.gov/nasa-brand-center/images-and-media/',
    },
  );
});

test('the licence is added when the credit does not already name it', () => {
  const result = attributionFor({ attribution: { credit: 'Jane Doe', license: 'CC BY 4.0' } });
  assert.equal(result.text, 'Jane Doe · CC BY 4.0');
});

test('without a credit the source and licence still show', () => {
  const result = attributionFor({ attribution: { sourceName: 'Wikimedia Commons', license: 'CC BY-SA 4.0' } });
  assert.equal(result.text, 'Wikimedia Commons · CC BY-SA 4.0');
});

test('a learner clip has no credit line', () => {
  assert.equal(attributionFor({ attribution: null }), null);
  assert.equal(attributionFor({}), null);
  assert.equal(attributionFor(null), null);
  assert.equal(attributionFor({ attribution: { credit: '  ' } }), null);
});

test('only https links are ever offered', () => {
  const result = attributionFor({
    attribution: { credit: 'X', license: 'CC0', sourceURL: 'javascript:alert(1)', licenseURL: 'http://example.com' },
  });
  assert.equal(result.sourceHref, null);
  assert.equal(result.licenseHref, null);
});
