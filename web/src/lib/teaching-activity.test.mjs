import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseTeachingVisual } from './teaching-activity.mjs';

const fixture = JSON.parse(readFileSync(new URL('../../../Sources/Tests/Fixtures/GuidedTeaching.json', import.meta.url)));

test('all four teaching activities from the production runner validate and preserve saved values', () => {
  assert.deepEqual(fixture.visuals.map(v => v.kind), ['fraction_bar', 'comparison', 'sequence', 'graph']);
  for (const visual of fixture.visuals) assert.deepEqual(parseTeachingVisual(visual), visual);
  for (const scene of Object.values(fixture.scenes)) {
    for (const component of scene.components.filter(c => c.block_type === 'teaching_visual')) {
      assert.ok(parseTeachingVisual(component.block));
      assert.equal(scene.components.filter(c => c.component_id === component.component_id).length, 1);
    }
  }
});

test('malformed arrays, ranges and parameters fail without crashing the lesson', () => {
  const [fraction, comparison, , graph] = fixture.visuals;
  for (const raw of [null, {}, { ...fraction, parts: 0 }, { ...fraction, value: 5 },
    { ...fraction, whole: Infinity }, { ...comparison, entries: [null, null] },
    { ...comparison, value: 9 }, { ...graph, params: [null] },
    { ...graph, params: [graph.params[0], graph.params[0]] },
    { ...graph, params: [{ ...graph.params[0], initial: NaN }] },
    { ...graph, params: [{ ...graph.params[0], step: -1 }] },
    { ...graph, y_min: 10, y_max: -10 }]) {
    assert.equal(parseTeachingVisual(raw), null);
  }
});

test('paced teaching has an explicit canonical CTA and the first task is supported choice', () => {
  for (const name of ['orientation', 'model_1', 'model_2']) {
    const components = fixture.scenes[name].components;
    assert.ok(components.some(c => c.type === 'ExampleBlock'));
    assert.equal(components.some(c => c.type === 'QuizCard' || c.type === 'InputField'), false);
    const cta = components.find(c => c.type === 'CTAButton');
    assert.equal(cta.action_intent, 'continue');
    assert.ok(cta.component_id);
  }
  assert.ok(fixture.scenes.guided.components.some(c => c.type === 'QuizCard'));
  const faded = fixture.scenes.faded.components.find(c => c.type === 'InputField');
  assert.equal(faded.min_words, 1);
  assert.match(faded.question, /1\/__/);
});
