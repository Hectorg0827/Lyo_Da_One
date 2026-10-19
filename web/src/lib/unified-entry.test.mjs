import test from 'node:test';
import assert from 'node:assert/strict';
import { routeLearningRequest, directLearningHref } from './unified-entry.mjs';

const params = (href) => new URL(href, 'https://lyo.test').searchParams;

test('direct answer in any subject keeps exact question in Chat', () => {
  for (const question of ['What is cellular respiration?', 'How do neural networks work?', 'Explain general relativity', '¿Cómo funciona la música?']) {
    const r = routeLearningRequest(question);
    assert.equal(r.surface, 'chat');
    assert.equal(params(r.href).get('prompt'), question);
  }
});

test('a subject or explicit teaching request opens the canonical Classroom', () => {
  for (const request of ['Spanish', 'Quantum physics', 'Teach me fractions', 'Quiero aprender guitarra']) {
    const r = routeLearningRequest(request);
    assert.equal(r.surface, 'classroom');
    assert.equal(params(r.href).get('topic'), request);
  }
});

test('explicit test phrasing preserves full intake text without silently creating a test', () => {
  const request = 'I have a chemistry exam Friday and these are my weak topics';
  const r = routeLearningRequest(request);
  assert.equal(r.surface, 'test_prep_intake');
  assert.equal(params(r.href).get('prompt'), request);
});

test('choosing exam goal supersedes bare topic and supplies the intake phrase', () => {
  const r = routeLearningRequest('AP Chemistry', { goal: 'exam' });
  assert.equal(r.surface, 'test_prep_intake');
  assert.equal(params(r.href).get('prompt'), 'I have a test. Help me prepare for AP Chemistry');
});

test('coach request remains a contextual Chat request', () => {
  const question = 'What should I study today?';
  const r = routeLearningRequest(question);
  assert.equal(r.surface, 'coach_chat');
  assert.equal(params(r.href).get('prompt'), question);
});

test('classroom settings are applied only to actual Classroom entry', () => {
  const opts = { level: 'advanced', minutes: 30, language: 'es' };
  assert.equal(params(routeLearningRequest('Teach me Rust', opts).href).get('duration'), '30');
  assert.equal(params(routeLearningRequest('What is Rust?', opts).href).get('duration'), null);
});

test('every direct shortcut remains accessible even with no text', () => {
  assert.equal(directLearningHref('chat'), '/chat');
  assert.equal(directLearningHref('classroom'), '/classroom');
  assert.equal(directLearningHref('test_prep'), '/test-prep');
  assert.equal(params(directLearningHref('chat', 'hello')).get('prompt'), 'hello');
});

test('never route empty/unknown requests into a fake session', () => {
  assert.equal(routeLearningRequest('   '), null);
  assert.equal(routeLearningRequest(null), null);
  assert.equal(directLearningHref('unknown'), null);
});

test('URL-significant characters survive each handoff intact', () => {
  const text = 'What does pH 7 & pH 8 mean?';
  assert.equal(params(routeLearningRequest(text).href).get('prompt'), text);
});
