import test from 'node:test';
import assert from 'node:assert/strict';

import {
  CALL_TO_ACTION,
  QUICK_TAKE_SECONDS,
  draftSubject,
  draftTitle,
  invitation,
} from './teach-it.mjs';

test('a known topic is named in the invitation', () => {
  assert.equal(
    invitation('Organic Chemistry'),
    'You just finished Organic Chemistry. Teach it in 60 seconds?',
  );
});

test('an unknown topic is not invented', () => {
  // A prompt that confidently names the wrong course is worse than one that
  // names none, so the generic line stands in.
  const generic = 'Teach what you just learned in 60 seconds?';
  assert.equal(invitation(null), generic);
  assert.equal(invitation(''), generic);
  assert.equal(invitation('   '), generic);
  assert.equal(invitation(undefined), generic);
});

test('the draft title is left empty when the topic is unknown', () => {
  // A title the learner did not write is published under their name.
  assert.equal(draftTitle('Spanish B1'), 'What I learned about Spanish B1');
  assert.equal(draftTitle(null), null);
  assert.equal(draftTitle('  '), null);
});

test('the draft subject is the trimmed topic, or nothing', () => {
  assert.equal(draftSubject('  Statistics  '), 'Statistics');
  assert.equal(draftSubject(''), null);
});

test('the promised length is the one the recorder enforces', () => {
  // The invitation must not offer a length the camera will refuse, so both
  // read the same constant.
  assert.equal(QUICK_TAKE_SECONDS, 60);
  assert.ok(invitation('Algebra').includes('60 seconds'));
  assert.equal(CALL_TO_ACTION, 'Teach it');
});
